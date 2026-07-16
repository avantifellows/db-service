# syntax=docker/dockerfile:1.6

################################################################################
# Build stage — full Elixir/Erlang/Node toolchain to produce an OTP release
################################################################################
FROM hexpm/elixir:1.18.4-erlang-27.3.4.11-debian-bookworm-20260421 AS build

RUN apt-get update \
    && apt-get install -y --no-install-recommends git nodejs npm ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

ENV MIX_ENV=prod \
    LANG=C.UTF-8

# Phoenix runtime config (config/runtime.exs) is loaded both at compile time
# and at boot. config_env() == :prod runs the env!() lookups during the build,
# which would crash without these set. They are placeholders only — every one
# is overridden by the ECS task definition at runtime, so leaking them into
# image layers is not a secret concern.
ENV PHX_HOST=build.local \
    SECRET_KEY_BASE=build-only-placeholder-not-used-at-runtime-build-only-placeholder \
    DATABASE_URL=ecto://build:build@localhost/build \
    BEARER_TOKEN=build \
    POOL_SIZE=10 \
    WHITELISTED_DOMAINS=build.local \
    DASHBOARD_USER=build \
    DASHBOARD_PASS=build

# Dependency layer — invalidated only when mix.exs / mix.lock change.
COPY mix.exs mix.lock ./
RUN mix local.hex --force \
    && mix local.rebar --force \
    && mix deps.get --only prod

# Compile-time config has to be in place before deps compile (some deps read it).
COPY config/ config/
RUN mix deps.compile

# Application source.
COPY lib/ lib/
COPY priv/ priv/
COPY assets/ assets/

# Assets, swagger doc, and the OTP release itself.
RUN mix assets.deploy \
    && mix phx.swagger.generate \
    && mix release

################################################################################
# Runtime stage — minimal image; only what the BEAM needs at runtime
################################################################################
FROM debian:bookworm-slim AS runtime

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libstdc++6 \
        openssl \
        libncurses5 \
        locales \
        ca-certificates \
        curl \
    && sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen \
    && locale-gen \
    && rm -rf /var/lib/apt/lists/*

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

WORKDIR /app

# Run as a non-root user. The release directory is owned by app:app so the
# OTP release can write its temporary files (e.g. /app/tmp).
RUN groupadd --system --gid 1000 app \
    && useradd --system --uid 1000 --gid app --home /app --shell /usr/sbin/nologin app

COPY --from=build --chown=app:app /app/_build/prod/rel/dbservice ./

USER app

# Matches the ECS task/container port (PORT=8080 is injected at runtime). Keep
# in sync with terraform var.app_port so the image metadata isn't misleading.
EXPOSE 8080

# bin/dbservice start invokes rel/env.sh.eex first, which exports
# PHX_SERVER=true so config/runtime.exs flips Endpoint server: true.
CMD ["bin/dbservice", "start"]
