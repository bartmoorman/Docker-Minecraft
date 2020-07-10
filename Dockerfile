FROM bmoorman/ubuntu:bionic AS builder

ARG DEBIAN_FRONTEND=noninteractive
ARG MC_VERSION=latest

WORKDIR /opt/minecraft

RUN apt-get update \
 && apt-get install --yes --no-install-recommends \
    git \
    openjdk-8-jdk-headless \
    wget \
 && wget --quiet "https://hub.spigotmc.org/jenkins/job/BuildTools/lastSuccessfulBuild/artifact/target/BuildTools.jar" \
 && java -jar BuildTools.jar --rev ${MC_VERSION}

FROM bmoorman/ubuntu:bionic

ARG DEBIAN_FRONTEND=noninteractive
ARG MC_SERVER_PORT=25565
ARG MC_RCON_PORT=25575

WORKDIR /var/lib/minecraft

RUN apt-get update \
 && apt-get install --yes --no-install-recommends \
    curl \
    jq \
    openjdk-8-jre-headless \
    rsync \
    vim \
 && fileUrl=$(curl --silent --location "https://api.github.com/repos/itzg/rcon-cli/releases/latest" | jq --raw-output '.assets[] | select(.name | contains("linux_amd64.tar.gz")) | .browser_download_url') \
 && curl --silent --location "${fileUrl}" | tar xz -C /usr/local/bin \
 && apt-get autoremove --yes --purge \
 && apt-get clean \
 && rm --recursive --force /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY --from=builder /opt/minecraft/spigot-*.jar /opt/minecraft/
COPY minecraft/ /etc/minecraft/
COPY bin/ /usr/local/bin/

VOLUME /var/lib/minecraft

EXPOSE ${MC_SERVER_PORT} ${MC_RCON_PORT}

CMD ["/etc/minecraft/start.sh"]
