# Kafka event and analytics flow

This document describes how Confera publishes registration events to Kafka,
how the analytics consumer turns them into daily registration rollups, and how
that event relates to the attendee's confirmation email.

## What Kafka does (and does not do)

Kafka carries `registration.created` events to the analytics consumer. That
consumer updates database rollups; it does not send an email, push message, or
other attendee notification.

The confirmation email is sent by a separate RabbitMQ consumer. A successful
registration is published to both brokers, using the same event ID:

```text
Registration API
  ├─ RabbitMQ ── registration email consumer ── confirmation email
  └─ Kafka    ── analytics consumer ─────────── registration rollup
```

The two consumers run independently. A successful email delivery does not
mean the analytics event was processed, and vice versa.

## Components

| Component | Responsibility |
| --- | --- |
| [`Registrations::Create`](../app/services/registrations/create.rb) | Creates and commits a registration, then publishes `registration.created` to both brokers. |
| [`Messaging::Event`](../app/services/messaging/event.rb) | Builds the shared event envelope. |
| [`Messaging::KafkaPublisher`](../app/services/messaging/kafka_publisher.rb) | Serializes and enqueues the event on the Kafka producer. |
| [`Messaging::KafkaClient`](../app/services/messaging/kafka_client.rb) | Configures and lazily creates the process-wide Kafka producer, and logs asynchronous delivery failures. |
| [`Messaging::Consumers::RegistrationAnalytics`](../app/services/messaging/consumers/registration_analytics.rb) | Reads Kafka events, deduplicates them, and increments daily rollups. |
| [`ProcessedEvent`](../app/models/processed_event.rb) | Stores event IDs already applied by analytics. |
| [`RegistrationRollup`](../app/models/registration_rollup.rb) | Active Record model for aggregate counts. |
| [`messaging:consume_registration_analytics`](../lib/tasks/messaging.rake) | Starts the analytics consumer process. |
| [`compose.yml`](../compose.yml) | Defines the Kafka broker, UI, and analytics consumer containers. |
| [`kafka`](../compose.yml) | The single-node Kafka broker configured for local development. |
| [`kafka-ui`](../compose.yml) | Optional browser UI for inspecting the broker. |

The email side uses [`Messaging::Publisher`](../app/services/messaging/publisher.rb),
[`Messaging::Topology`](../app/services/messaging/topology.rb), and
[`Messaging::Consumers::RegistrationEmail`](../app/services/messaging/consumers/registration_email.rb)
with RabbitMQ; it is included here to make the full notification journey clear.

## Event contract

The event is JSON with this shape:

```json
{
  "event_id": "a-unique-uuid",
  "type": "registration.created",
  "occurred_at": "2026-11-08T11:56:27.543Z",
  "request_id": "request-correlation-id",
  "data": {
    "registration_id": 123,
    "user_id": 45,
    "ticket_type_id": 6,
    "conference_id": 7
  }
}
```

The IDs are the event data; consumers load or aggregate from their own
perspective rather than receiving a serialized registration, user, or
conference object. `request_id` may be `null` when the event is not associated
with an API request.

Kafka-specific metadata:

- Topic: `confera.registrations` (`KafkaClient::REGISTRATIONS_TOPIC`).
- Key: the ticket type ID, converted to a string. Kafka maps a key to a
  partition, preserving order for events with the same key within that
  partition.
- Headers: `event_type` and, when present, `request_id`.
- Consumer group: `confera-analytics`.

The event ID is generated once after the registration commits and passed to
both broker publishers. It allows each consumer path to correlate the same
logical event; Kafka analytics deduplication is specifically keyed by that ID.

## A single registration and its notification, step by step

1. **The API accepts the request.** An authenticated caller posts a
   `ticket_type_id` to `POST /api/v1/registrations`.
   [`RegistrationsController#create`](../app/controllers/api/V1/registrations_controller.rb)
   calls `Registrations::Create`.
2. **The registration is committed first.** `Registrations::Create` locks the
   selected ticket type, validates that the conference is published and has
   capacity, and saves a confirmed registration inside a database transaction.
   No event is published if the transaction fails. Publishing after commit
   avoids announcing a registration that later rolls back.
3. **One event ID and payload are prepared.** The service creates a UUID and a
   payload containing the registration, user, ticket type, and conference IDs.
   Both publisher calls use this event ID.
4. **The email event goes to RabbitMQ.** The service first publishes
   `registration.created` through `Messaging::Publisher`. It declares the
   durable `confera.events` topic exchange and
   `registration.confirmation_email` queue, then waits up to three seconds for a
   broker confirmation. The queue is bound to the `registration.created`
   routing key.
5. **The analytics event is enqueued to Kafka.** The service then calls
   `Messaging::KafkaPublisher`. It serializes the shared envelope and produces
   it to `confera.registrations`, using the ticket type ID as the key. `produce`
   enqueues locally and does not wait for the broker's delivery acknowledgement.
6. **The API response is returned.** The API returns the created registration.
   The Kafka publish path is best-effort: an exception is logged as
   `analytics_publish_failed` and does not undo the committed registration or
   change the response to an error.
7. **The RabbitMQ consumer sends the confirmation.** The email consumer reads
   the queue, loads the registration and checks that it is confirmed and has
   not already been emailed. It calls
   `RegistrationMailer.confirmation(...).deliver_now`, records
   `confirmation_sent_at`, then acknowledges the message. This is the attendee
   notification.
8. **The Kafka consumer updates analytics.** Independently, the analytics
   consumer polls the Kafka topic, parses the envelope, and reads
   `conference_id`, `ticket_type_id`, and the UTC date of `occurred_at`.
   Within a database transaction it inserts the event ID into
   `processed_events`. If that ID is new, it increments (or creates) the
   `registration_rollups` row for that ticket type and day. A previously
   processed ID is skipped. It stores the Kafka offset after this handling.

As a result, a registration and its confirmation email can succeed even if
Kafka is unavailable. Analytics might then be missing that registration; Kafka
publishing is not part of the registration database transaction.

### Confirmation email failure behavior

The RabbitMQ publisher waits for a broker confirmation. If that publish fails,
`Registrations::Create` logs and reports the failure but still returns the
already-committed registration; it then continues to the Kafka publish. The
email consumer acknowledges a message after sending (or after determining it
should be skipped). On a processing error, it requeues the message once; a
second failure is rejected to the configured dead-letter exchange and queue.
Malformed JSON is rejected without retry.

The `events:replay_registrations` task can republish recent confirmed
registrations whose `confirmation_sent_at` is still empty. This is a
RabbitMQ/email repair path only, not a Kafka analytics replay.

## Analytics processing and delivery behavior

### Producer

`KafkaClient` uses `KAFKA_BROKERS` for the bootstrap servers and creates one
producer lazily per process. Producer settings enable idempotence, use a
10-second message timeout, and allow a 5-millisecond batching window. Idempotent
producer retries help avoid duplicate or reordered writes from producer retries,
but do not make the registration database write and Kafka publish one atomic
operation.

The publisher's return value means the event was enqueued by the client, not
that Kafka acknowledged it. The producer's background delivery callback logs
`kafka_delivery_failed` if delivery ultimately fails. On process shutdown, the
client flushes buffered messages for up to five seconds before closing.

### Consumer and rollup

The analytics consumer subscribes to `confera.registrations` as group
`confera-analytics`. It disables automatic offset storage and stores an offset
only after handling the current message. For a new consumer group,
`auto.offset.reset=earliest` starts at the beginning of the available topic
log; an existing group's committed offsets take precedence.

For each valid event:

1. Parse the JSON and require its event ID, event data IDs, and occurrence time.
2. Insert the ID in `processed_events` using a unique index on `event_id`.
3. If the ID was already present, skip the update. Otherwise, atomically upsert
   `registration_rollups` and add one to its total.
4. Store the Kafka message offset.

The rollup key is `(ticket_type_id, day)`; the row also stores `conference_id`.
The day is derived from `occurred_at` converted to UTC. The deduplication insert
and rollup update share one database transaction, so a failed update also rolls
back the deduplication marker and can be retried.

### Retries and limits

- The consumer retries unexpected processing errors up to three total attempts,
  with a short increasing sleep between attempts.
- Invalid JSON or required fields are logged as `message_unparseable` and are
  not retried.
- After retries are exhausted, the consumer logs `analytics_event_dropped`.
  It then returns to the polling loop and stores the offset. The message is
  therefore deliberately skipped; Kafka dead-letter routing is not configured
  for analytics.
- This is not end-to-end exactly-once delivery. Database deduplication protects
  rollups when a successfully applied message is delivered again, but a
  permanently failed/dropped message is not recovered automatically.
- The RabbitMQ replay task does **not** republish events to Kafka, so it is
  not an analytics repair mechanism.

Consumer logs are written through Rails logging and stdout, with event names
such as `analytics_recorded`, `analytics_duplicate_skipped`,
`analytics_retry`, and `analytics_event_dropped`. In Docker, inspect them with:

```sh
docker compose logs -f kafka_consumer
```

## Local setup and operations

Start the application stack, including Kafka and its consumer:

```sh
docker compose up -d
```

Kafka's `KAFKA_AUTO_CREATE_TOPICS_ENABLE` is disabled to make topic-name errors
visible. Create the topic once after the broker is healthy:

```sh
docker compose exec kafka /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server kafka:9092 \
  --create --if-not-exists \
  --topic confera.registrations \
  --partitions 1 \
  --replication-factor 1
```

The single partition and replication factor match the one-broker local Compose
setup; they are not production availability settings. If starting only selected
services, also start `kafka` and `kafka_consumer` and create the topic before
publishing registrations. The `web` service receives `KAFKA_BROKERS`, but its
Compose dependency list does not itself require Kafka to be healthy.

Check the topic:

```sh
docker compose exec kafka /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server kafka:9092 --describe \
  --topic confera.registrations
```

The Kafka UI is available at [http://localhost:8080](http://localhost:8080).
The Compose broker has no persistent Kafka volume: running `docker compose down`
removes the topic log and consumer offsets, so the topic must be recreated.

## Related source

- Registration request and fan-out: [`Registrations::Create`](../app/services/registrations/create.rb)
- Kafka client and producer: [`KafkaClient`](../app/services/messaging/kafka_client.rb),
  [`KafkaPublisher`](../app/services/messaging/kafka_publisher.rb)
- Event shape: [`Messaging::Event`](../app/services/messaging/event.rb)
- Analytics consumer: [`RegistrationAnalytics`](../app/services/messaging/consumers/registration_analytics.rb)
- Rollup and deduplication schema: [`db/schema.rb`](../db/schema.rb)
- Consumer tasks: [`lib/tasks/messaging.rake`](../lib/tasks/messaging.rake)
- Broker and containers: [`compose.yml`](../compose.yml)
