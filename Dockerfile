FROM bmoorman/ubuntu:focal AS builder

ARG DEBIAN_FRONTEND=noninteractive \
    MC_VERSION=latest

WORKDIR /opt/minecraft

RUN apt-get update \
 && apt-get install --yes --no-install-recommends \
    openjdk-16-jdk-headless \
    git \
    wget \
 && wget --quiet "https://hub.spigotmc.org/jenkins/job/BuildTools/lastSuccessfulBuild/artifact/target/BuildTools.jar" \
 && java -jar -Xms512M -Xmx1024M BuildTools.jar --rev ${MC_VERSION}

FROM bmoorman/ubuntu:focal

ARG DEBIAN_FRONTEND=noninteractive \
    MC_SERVER_PORT=25565 \
    MC_RCON_PORT=25575 \
    TARGETOS \
    TARGETARCH \
    TARGETVARIANT

WORKDIR /var/lib/minecraft

RUN apt-get update \
 && apt-get install --yes --no-install-recommends \
    openjdk-16-jre-headless \
    jq \
    vim \
 && arch=${TARGETOS}_${TARGETARCH}${TARGETVARIANT} \
 && fileUrl=$(curl --silent --location "https://api.github.com/repos/itzg/rcon-cli/releases/latest" | jq --arg target ${target} --raw-output '.assets[] | select(.name | endswith($target + ".tar.gz")) | .browser_download_url') \
 && curl --silent --location "${fileUrl}" | tar xz -C /usr/local/bin \
 && apt-get autoremove --yes --purge \
 && apt-get clean \
 && rm --recursive --force /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY --from=builder /opt/minecraft/spigot-*.jar /opt/minecraft/
COPY minecraft/ /etc/minecraft/

VOLUME /var/lib/minecraft

EXPOSE ${MC_SERVER_PORT} ${MC_RCON_PORT}

CMD ["/etc/minecraft/start.sh"]
