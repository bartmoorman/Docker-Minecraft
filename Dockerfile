FROM bmoorman/ubuntu:bionic AS builder

ARG DEBIAN_FRONTEND=noninteractive
ARG DOCKER_TAG=latest

WORKDIR /opt/minecraft

RUN apt-get update \
 && apt-get install --yes --no-install-recommends \
    git \
    openjdk-8-jdk-headless \
    wget \
 && wget --quiet "https://hub.spigotmc.org/jenkins/job/BuildTools/lastSuccessfulBuild/artifact/target/BuildTools.jar" \
 && java -jar BuildTools.jar --rev ${DOCKER_TAG}

FROM bmoorman/ubuntu:bionic

ARG DEBIAN_FRONTEND=noninteractive
ARG MC_SERVER_PORT=25565
ARG MC_RCON_PORT=25575

WORKDIR /var/lib/minecraft

RUN apt-get update \
 && apt-get install --yes --no-install-recommends \
    openjdk-8-jdk-headless \
    vim \
 && apt-get autoremove --yes --purge \
 && apt-get clean \
 && rm --recursive --force /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY --from=builder /opt/minecraft/spigot-*.jar /opt/minecraft/
COPY minecraft/ /etc/minecraft/

VOLUME /var/lib/minecraft

EXPOSE ${MC_SERVER_PORT} ${MC_RCON_PORT}

CMD ["/etc/minecraft/start.sh"]
