# Use latest stable channel SDK.
# Build context: repo root (so seedsphere_core/ and router/ are both available).
FROM dart:stable AS build

# Copy the seedsphere_core path dependency first.
# pubspec.yaml references it as: path: ../seedsphere_core
WORKDIR /workspace
COPY seedsphere_core/ ./seedsphere_core/

# Copy router source and resolve dependencies.
WORKDIR /workspace/router
COPY router/pubspec.* ./

# Install build dependencies for sodium native assets.
RUN apt-get update && apt-get install -y \
    build-essential \
    libsodium-dev \
    && rm -rf /var/lib/apt/lists/*

RUN dart pub get

# Copy remaining router source and AOT compile.
COPY router/ .
RUN dart build cli -t bin/server.dart -o build

# Build minimal serving image from AOT-compiled binary.
FROM debian:stable-slim

# Install runtime dependencies.
RUN apt-get update && apt-get install -y \
    libsodium-dev \
    libsqlite3-dev \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=build /workspace/router/build/bundle /app/bundle
COPY --from=build /workspace/router/portal /app/portal
RUN chmod +x /app/bundle/bin/server

# Expose HTTP and P2P ports.
EXPOSE 8080
EXPOSE 4001
EXPOSE 4001/udp
CMD ["/app/bundle/bin/server"]
