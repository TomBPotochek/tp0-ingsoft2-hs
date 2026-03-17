FROM haskell:9.10.3-bookworm AS builder

WORKDIR /app/user

# Needed at build time for postgresql-libpq-configure (pg_config)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*


# Copy only dependency manifests first so Docker can cache dependency builds.
COPY stack.yaml package.yaml ./
RUN --mount=type=cache,target=/root/.stack \
    stack build --dependencies-only

# Copy the rest of the source after dependencies are cached.
COPY . .
RUN --mount=type=cache,target=/root/.stack \
    stack build --copy-bins --local-bin-path /out

FROM builder AS tester
CMD ["stack", "test"]

FROM debian:bookworm-slim AS runtime-base

# Runtime shared libraries needed by GHC-compiled executables.
RUN apt-get update && apt-get install -y --no-install-recommends \
	ca-certificates \
	libgmp10 \
	libffi8 \
	libpq5 \
	&& rm -rf /var/lib/apt/lists/*

FROM runtime-base AS runtime-app

WORKDIR /app
COPY --from=builder /out/tp0 /usr/local/bin/tp0

EXPOSE 1234
ENTRYPOINT ["/usr/local/bin/tp0"]

FROM runtime-base AS runtime-e2e

WORKDIR /app
COPY --from=builder /out/tp0-e2e /usr/local/bin/tp0-e2e

ENTRYPOINT ["/usr/local/bin/tp0-e2e"]
