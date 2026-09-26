ARG RUBY_VERSION=3.3
FROM ruby:${RUBY_VERSION}-slim

ARG UID=1000
ARG GID=1000

RUN apt-get update -qq \
    && apt-get install -y --no-install-recommends \
       build-essential \
       git \
       curl \
       libpq-dev \
       postgresql-client \
       libvips \
       libyaml-dev \
       pkg-config \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd -g "${GID}" app \
    && useradd -m -u "${UID}" -g "${GID}" -s /bin/bash app

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN bundle install && chown -R app:app /usr/local/bundle

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

COPY --chown=app:app . .

USER app

EXPOSE 3000

ENTRYPOINT ["entrypoint.sh"]
CMD ["rails", "server", "-b", "0.0.0.0"]
