# syntax = docker/dockerfile:1
#
# Development image for the Switchboard code test. Runs Rails in development
# mode; application code is bind-mounted from the host via docker-compose so
# edits are picked up without a rebuild. Rebuild only when the Gemfile changes.
ARG RUBY_VERSION=3.3.11
FROM ruby:${RUBY_VERSION}-slim

ENV LANG=C.UTF-8 \
    BUNDLE_PATH=/usr/local/bundle

# build-essential + libpq-dev: compile the pg gem.
# postgresql-client: pg_isready in the entrypoint. git/curl: convenience.
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential libpq-dev libyaml-dev pkg-config postgresql-client git curl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

EXPOSE 3000
ENTRYPOINT ["bin/docker-entrypoint"]
CMD ["bin/rails", "server", "-b", "0.0.0.0", "-p", "3000"]
