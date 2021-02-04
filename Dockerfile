FROM bmoorman/ubuntu:focal

ARG DEBIAN_FRONTEND=noninteractive \
    MC_SERVER_PORT=25565 \
    MC_RCON_PORT=25575

WORKDIR /var/lib/minecraft

RUN apt-get update \
 && apt-get install --yes --no-install-recommends \
    curl \
    jq \
    openjdk-8-jre-headless \
    vim \
    wget \
    xgrep \
 && fileUrl=$(curl --silent --location "https://api.github.com/repos/itzg/rcon-cli/releases/latest" | jq --raw-output '.assets[] | select(.name | contains("linux_amd64.tar.gz")) | .browser_download_url') \
 && curl --silent --location "${fileUrl}" | tar xz -C /usr/local/bin \
 && apt-get autoremove --yes --purge \
 && apt-get clean \
 && rm --recursive --force /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY minecraft/ /etc/minecraft/

VOLUME /var/lib/minecraft

EXPOSE ${MC_SERVER_PORT} ${MC_RCON_PORT}

CMD ["/etc/minecraft/start.sh"]
