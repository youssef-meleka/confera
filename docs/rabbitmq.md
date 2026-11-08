# RabbitMQ registration confirmation flow

This document explains how Confera publishes registration events to RabbitMQ,
how the email consumer handles them, what happens on failures, and how to run
and inspect the feature locally.

## What RabbitMQ does

RabbitMQ delivers `registration.created` events to the registration email
consumer. That consumer loads the registration and sends the attendee a
confirmation email. Kafka handles a separate concern: registration analytics
and daily rollups. A registration is published to both brokers after it is
committed, but the two paths operate independently.

```text
POST /api/v1/registrations
  └─ registration transaction commits
      ├─ RabbitMQ ── registration email consumer ── SMTP ── attendee email
      └─ Kafka    ── analytics consumer ─────────── database rollup
```

See [kafka.md](./kafka.md) for the Kafka analytics path.

## Components

| Component | Responsibility |
| --- | --- |
| [`Registrations::Create`](../app/services/registrations/create.rb) | Commits a confirmed registration, then publishes the same logical event to RabbitMQ and Kafka. |
| [`Messaging::Event`](../app/services/messaging/event.rb) | Builds the JSON event envelope. |
| [`Messaging::Publisher`](../app/services/messaging/publisher.rb) | Publishes persistent messages with publisher confirms. |
| [`Messaging::Broker`](../app/services/messaging/broker.rb) | Manages the web process's shared publishing connection and consumer connections. |
| [`Messaging::Topology`](../app/services/messaging/topology.rb) | Declares the durable exchange, confirmation queue, and dead-letter topology. |
| [`Messaging::Consumers::RegistrationEmail`](../app/services/messaging/consumers/registration_email.rb) | Consumes events, sends eligible confirmation emails, and acknowledges or rejects messages. |
| [`RegistrationMailer`](../app/mailers/registration_mailer.rb) | Builds the confirmation email addressed to the attendee. |
| [`confirmation.text.erb`](../app/views/registration_mailer/confirmation.text.erb) | Supplies the plain-text email content. |
| [`messaging:consume_registration_emails`](../lib/tasks/messaging.rake) | Starts the RabbitMQ email consumer. |
| [`events:replay_registrations`](../lib/tasks/events.rake) | Republishes recent confirmed registrations that have no recorded email timestamp. |
| [`rabbitmq`](../compose.yml) | Runs RabbitMQ with its management plugin and persistent data volume. |
| [`rabbit_consumer`](../compose.yml) | Runs the email consumer as a restartable Compose service. |
| [`mailpit`](../compose.yml) | Captures development email for inspection in a browser. |

RabbitMQ uses the Bunny client (`bunny` gem). In the web process, a shared
connection is protected by a mutex, and each publish borrows its own channel
because Bunny channels are not thread-safe. The consumer opens a separate
connection with automatic recovery enabled.

## Queue and exchange topology

`Messaging::Topology.declare!` creates or confirms this topology:

```text
confera.events (durable topic exchange)
  └─ routing key: registration.created
      └─ registration.confirmation_email (durable queue)
          └─ dead-letter exchange: confera.events.dead
              └─ registration.confirmation_email.dead (durable queue)

confera.events.dead (durable fanout exchange)
  └─ registration.confirmation_email.dead
```

The publisher and consumer both declare the topology. This lets a message wait
in the durable queue before the consumer starts. The declarations are
idempotent when the existing definitions match. RabbitMQ does not allow queue
arguments to be changed in place; changing the confirmation queue's
dead-letter argument requires deleting and recreating that queue.

Messages are marked persistent, but persistence depends on the durable queue
and broker storage as well. In Compose, RabbitMQ stores data in the
`rabbitmq_data` volume, which survives ordinary container recreation.

## Event contract

The publisher sends JSON using the shared event envelope:

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

The email consumer uses `data.registration_id` to load current database state;
it does not trust a serialized user or registration object. It extracts the
correlation ID from the AMQP `request_id` header, falling back to the AMQP
message ID. The publisher sets AMQP properties including:

- `message_id`: the event UUID.
- `type`: `registration.created`.
- `content_type`: `application/json`.
- `headers.request_id`: included when the API provided a request ID.
- `routing_key`: the event type (`registration.created`).

When a registration is fanned out, the same event UUID is passed to the
RabbitMQ and Kafka publishers. Replay creates a new UUID by default.

## A single registration and its confirmation email

1. **The API accepts the request.** An authenticated caller posts a
   `ticket_type_id` to `POST /api/v1/registrations`.
   [`RegistrationsController#create`](../app/controllers/api/V1/registrations_controller.rb)
   calls `Registrations::Create`.
2. **The registration is committed first.** The service locks the ticket type,
   verifies that its conference is published and capacity remains, and saves a
   confirmed registration in a database transaction. A failed transaction
   publishes no event.
3. **The shared event is created.** After commit, the service makes an event
   UUID and prepares IDs for the registration, user, ticket type, and
   conference. It publishes to RabbitMQ before trying Kafka.
4. **The web process publishes to RabbitMQ.** The publisher opens a channel,
   enables publisher confirms, declares the topology, and publishes the
   persistent JSON message to `confera.events` with routing key
   `registration.created`. It waits up to three seconds for confirmation.
5. **The API continues.** A RabbitMQ publish error is logged and reported, but
   it does not roll back the registration or prevent the later Kafka publish.
   The API response still reflects the committed registration. The replay task
   can repair eligible missing email events.
6. **The consumer receives the message.** `rabbit_consumer` reads from
   `registration.confirmation_email` with manual acknowledgements and prefetch
   set to 10 unacknowledged messages.
7. **The consumer checks database state.** It loads the registration and
   associated user, ticket type, and conference. If the registration is
   missing, not confirmed, or already has `confirmation_sent_at`, it logs why
   and acknowledges the event without sending another email.
8. **The email is sent.** For an eligible registration, the consumer calls
   `RegistrationMailer.confirmation(registration).deliver_now`. The mailer
   sends to the attendee's email with the subject
   `You're registered for <conference name>`. It then records
   `confirmation_sent_at` and acknowledges the RabbitMQ delivery.

The email is sent by the RabbitMQ consumer, not by the API request and not by
Kafka. With the local Compose setup, SMTP delivery goes to Mailpit.

## Acknowledgements and failure handling

The consumer uses manual acknowledgements. A message is acknowledged only
after it has been processed or deliberately skipped, so RabbitMQ can redeliver
an unacknowledged message after a consumer disconnect or restart.

- **Malformed JSON:** logged as `message_unparseable`, then rejected without
  requeue. The configured dead-letter exchange routes it to
  `registration.confirmation_email.dead`.
- **Other processing error, first delivery:** logged as `consumer_failed` and
  rejected with requeue. This gives the delivery one retry.
- **Other processing error, redelivery:** logged as `consumer_failed` and
  rejected without requeue, routing it to the dead-letter queue.
- **Normal send or skip:** acknowledged after completion.
- **Graceful shutdown:** the consumer cancels its subscription and closes the
  connection. Any in-flight delivery not acknowledged is eligible for
  redelivery.

In development, Action Mailer is configured to raise SMTP delivery errors so a
failed SMTP send does not get acknowledged or marked sent. The email delivery
and `confirmation_sent_at` database update are not one atomic operation. If
SMTP accepts an email but the subsequent database update fails, the message
may be retried and the email may be sent more than once. The timestamp check
prevents many ordinary duplicate deliveries, but it cannot close this
cross-system failure window.

Publisher confirms establish that RabbitMQ confirmed the publish; they do not
make the database commit and message publish atomic. If the registration has
committed but RabbitMQ publish failed, the service logs `event_publish_failed`
and reports the exception without returning an error for the already-created
registration. Use the replay task to attempt recovery.

## Replay missed confirmation emails

The `events:replay_registrations` task finds recent confirmed registrations
whose `confirmation_sent_at` is empty, then publishes a new
`registration.created` event through RabbitMQ. Its default lookback is 60
minutes; `SINCE_MINUTES` overrides it:

```sh
docker compose run --rm web bin/rails events:replay_registrations
docker compose run --rm -e SINCE_MINUTES=240 web bin/rails events:replay_registrations
```

The consumer rechecks the registration and timestamp before sending, which
means replaying an already-handled registration is normally a harmless skip.
The task repairs the RabbitMQ/email path only; it does not republish an
analytics event to Kafka.

## Local setup and operations

Copy the example environment file and set the RabbitMQ credentials and URL
before starting Compose:

```sh
cp .env.example .env
docker compose up -d
```

Compose starts RabbitMQ, waits for it to be healthy before starting the web and
email-consumer services, and starts Mailpit for local SMTP. The example
environment file documents the expected RabbitMQ variables. In Compose the
broker host is the `rabbitmq` service name.

Inspect received emails in Mailpit at
[http://localhost:8025](http://localhost:8025). The RabbitMQ management UI is
available at [http://localhost:15672](http://localhost:15672); sign in with
the configured RabbitMQ credentials. Inspect the consumer logs with:

```sh
docker compose logs -f rabbit_consumer
```

Useful log event names include `consumer_started`, `confirmation_sent`,
`confirmation_skipped`, `confirmation_already_sent`, `consumer_failed`,
`message_unparseable`, and `consumer_stopped`.

The email consumer can also be started as a Rails task in an environment where
`RABBITMQ_URL` and database settings are configured:

```sh
bin/rails messaging:consume_registration_emails
```

The task runs until it receives `TERM` or `INT`.

## Related source

- Registration request and broker fan-out: [`Registrations::Create`](../app/services/registrations/create.rb)
- Event shape: [`Messaging::Event`](../app/services/messaging/event.rb)
- RabbitMQ publisher and connection: [`Messaging::Publisher`](../app/services/messaging/publisher.rb),
  [`Messaging::Broker`](../app/services/messaging/broker.rb)
- Exchange, queues, and bindings: [`Messaging::Topology`](../app/services/messaging/topology.rb)
- Email consumer: [`RegistrationEmail`](../app/services/messaging/consumers/registration_email.rb)
- Mailer and body template: [`RegistrationMailer`](../app/mailers/registration_mailer.rb),
  [`confirmation.text.erb`](../app/views/registration_mailer/confirmation.text.erb)
- Consumer/replay tasks: [`lib/tasks/messaging.rake`](../lib/tasks/messaging.rake),
  [`lib/tasks/events.rake`](../lib/tasks/events.rake)
- Broker, consumer, and Mailpit services: [`compose.yml`](../compose.yml)
- Local environment variable names: [`.env.example`](../.env.example)
