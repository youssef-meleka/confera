# Confera

A small, Dockerized conference management API, built with Rails in `--api` mode.

An **organizer** creates a **conference**, which has **tracks** and **talks**, and sells **ticket types**. **Attendees** browse published conferences and **register** for one.

```
User ──< Conference ──< Track ──< Talk
              │
              └──< TicketType ──< Registration >── User
```

## Stack

- Ruby 3.3 / Rails 8, API-only
- PostgreSQL 16
- Jbuilder for views, Pundit for authorization, Pagy for pagination
- Hand-rolled bearer-token auth (no Devise)
- RabbitMQ and Kafka for two contrasting message-broker delivery patterns

## Getting started

No Ruby, Rails, or Postgres needs to be installed locally — everything runs through Docker.

```sh
docker compose up -d
```

This brings up the `web` (Rails) and `db` (Postgres) services, waiting for Postgres to be healthy before Rails boots.

See **[infrastructure/daily-use.md](infrastructure/daily-use.md)** for the full day-to-day command reference (running Rails commands, gems, database access, rebuilding, troubleshooting).

## API

The API is namespaced under `/api/v1` — see `config/routes.rb` for the current surface. Everything is testable with `curl` or a REST client; no frontend is required.
