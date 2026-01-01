# Use latest stable channel SDK.
FROM dart:stable AS build

# Resolve app dependencies.
WORKDIR /app
COPY pubspec.* ./
RUN dart pub get

# Copy app source code (except anything in .dockerignore) and AOT compile app.
COPY . .
RUN dart build cli -t bin/server.dart -o build

# Build minimal serving image from AOT-compiled `/server`
FROM debian:stable-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libsodium-dev \
    libsqlite3-dev \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=build /app/build/bin/server /app/bin/
RUN chmod +x /app/bin/server
COPY --from=build /app/portal /app/portal

# Start server.
EXPOSE 8080
EXPOSE 4001
EXPOSE 4001/udp
CMD ["/app/bin/server"]
