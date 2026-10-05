# BattleRift dedicated server: Godot headless + ENet (UDP)
ARG DEBIAN_VERSION=bookworm-slim

FROM debian:${DEBIAN_VERSION} AS fetch
ARG GODOT_VERSION=4.3
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl unzip \
 && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL -o /tmp/godot.zip "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip" \
 && unzip -q /tmp/godot.zip -d /tmp \
 && mv "/tmp/Godot_v${GODOT_VERSION}-stable_linux.x86_64" /godot \
 && chmod +x /godot

FROM debian:${DEBIAN_VERSION}
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates libfontconfig1 libx11-6 libxcursor1 libxinerama1 libxi6 libxrandr2 libxext6 libxrender1 libgl1 libasound2 \
 && rm -rf /var/lib/apt/lists/*
COPY --from=fetch /godot /usr/local/bin/godot
RUN useradd --create-home --uid 10001 rift
WORKDIR /srv/battlerift
COPY --chown=rift:rift . .
USER rift
RUN godot --headless --path /srv/battlerift --import || true
ENV BATTLERIFT_PORT=7777
EXPOSE 7777/udp
ENTRYPOINT ["godot", "--headless", "--path", "/srv/battlerift", "res://scenes/server/server.tscn", "--"]
CMD ["--port=7777"]