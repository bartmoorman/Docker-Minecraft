FROM bmoorman/ubuntu:bionic AS builder

ARG DEBIAN_FRONTEND="noninteractive"

WORKDIR /opt/minecraft

RUN apt-get update \
 && apt-get install --yes --no-install-recommends \
    git \
    openjdk-8-jdk-headless \
    wget \
 && wget --quiet "https://hub.spigotmc.org/jenkins/job/BuildTools/lastSuccessfulBuild/artifact/target/BuildTools.jar" \
 && java -jar BuildTools.jar --rev ${DOCKER_TAG:-latest}

FROM bmoorman/ubuntu:bionic

ENV MC_SERVER_PORT="25565" \
    MC_RCON_PORT="25575" \
    MC_MIN_MEM="1G" \
    MC_MAX_MEM="2G"

ARG DEBIAN_FRONTEND="noninteractive"

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
