#!/bin/bash
if [ ${MC_EULA:-false} != true ]; then
    echo -e '\e[41m!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\e[49m'
    echo -e '\e[41mMC_EULA must always be set to true.\e[49m'
    echo -e '\e[41mPlease indicate you agree to the EULA (https://account.mojang.com/documents/minecraft_eula).\e[49m'
    echo -e '\e[41m!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\e[49m'
    exit
fi

base=/opt/minecraft

echo -n 'Fetching Minecraft version manifest ... '
manifest=$(curl --silent --location "https://launchermeta.mojang.com/mc/game/version_manifest.json")
echo 'done'

if [ ${MC_VERSION:-latest} == latest ]; then
    echo -n 'Identifying latest Minecraft version ... '
    MC_VERSION=$(jq --raw-output '.latest.release' <<< ${manifest})
    echo "${MC_VERSION}"
fi

if [ ${MC_FABRIC:-false} == true ]; then
    echo -n 'Fetching Fabric installer metadata ... '
    metadata=$(curl --silent --location "https://maven.fabricmc.net/net/fabricmc/fabric-installer/maven-metadata.xml")
    echo 'done'

    if [ ${MC_FABRIC_VERSION:-latest} == latest ]; then
      echo -n 'Identifying latest Fabric installer version ... '
      MC_FABRIC_VERSION=$(xgrep -t -x '//metadata/versioning/release/text()' <<< ${metadata})
      echo "${MC_FABRIC_VERSION}"
    fi

    if [ ! -f ${base}/fabric-installer-${MC_FABRIC_VERSION}.jar ]; then
        echo -n "Downloading Fabric ${MC_FABRIC_VERSION} installer ... "
        fileUrl="https://maven.fabricmc.net/net/fabricmc/fabric-installer/${MC_FABRIC_VERSION}/fabric-installer-${MC_FABRIC_VERSION}.jar"
        wget --quiet --directory-prefix ${base} "${fileUrl}"
        echo 'done'
    fi

    if [ ! -f ${base}/fabric-server-launch.jar -o ! -f ${base}/server.jar ]; then
        echo "Installing Fabric ... "
        java -jar ${base}/fabric-installer-${MC_FABRIC_VERSION}.jar server -dir ${base} -mcversion ${MC_VERSION} -downloadMinecraft
    fi

    if [ ! -f fabric-server-launcher.properties ]; then
        echo "#$(date +'%a %b %d %H:%M:%S %Z %Y')" > fabric-server-launcher.properties
        echo "serverJar=${base}/server.jar" >> fabric-server-launcher.properties
    else
        sed --in-place --regexp-extended \
        --expression "s|^(serverJar=).*|\1${base}/server.jar|" \
        fabric-server-launcher.properties
    fi

    jar=${base}/fabric-server-launch.jar
else
    if [ ! -f ${base}/server.jar ]; then
        echo -n "Downloading Minecraft ${MC_VERSION} ... "
        versionUrl=$(jq --raw-output --arg id ${MC_VERSION} '.versions[] | select(.id == $id) | .url' <<< ${manifest})
        fileUrl=$(curl --silent --location "${versionUrl}" | jq --raw-output '.downloads.server.url')
        wget --quiet --directory-prefix ${base} "${fileUrl}"
        echo 'done'
    fi

    jar=${base}/server.jar
fi

if [ ! -f eula.txt -o ! -f server.properties ]; then
    echo -e '\e[44m##############################\e[49m'
    echo -e '\e[44mPerforming first-time setup.\e[49m'
    echo -e '\e[44mErrors and warnings regarding server.properties and/or eula.txt are expected.\e[49m'
    echo -e '\e[44m##############################\e[49m'
    $(which java) -jar ${jar} --initSettings
fi

for file in eula.txt server.properties; do
    echo -e "Updating \e[94m${file}\e[39m:"
    fileChanged=false

    for key in $(grep ^[[:lower:]] ${file} | cut -d= -f1); do
        var="MC_$(tr [:punct:] _ <<< ${key} | tr [:lower:] [:upper:])"

        if [ -v ${var} ]; then
            echo -e "\t\e[95m${key}\e[39m=\e[96m${!var}\e[39m"

            sed --in-place --regexp-extended \
            --expression "s|^(${key}=).*|\1${!var}|" \
            ${file}

            fileChanged=true
        fi
    done

    if [ ${fileChanged} == false ]; then
        echo -e '\t\e[93mNothing changed!\e[39m'
    fi
done

if [ ${MC_ENABLE_RCON:-false} == true ]; then
    cat << EOF > ~/.rcon-cli.yaml
host: 127.0.0.1
port: ${MC_RCON_PORT:-25575}
password: ${MC_RCON_PASSWORD}
EOF
fi

exec $(which java) \
    -Dserver.name=${MC_SERVER_NAME:-minecraft} \
    -Xms${MC_MIN_MEM:-1G} \
    -Xmx${MC_MAX_MEM:-2G} \
    -XX:+UseG1GC \
    -XX:+ParallelRefProcEnabled \
    -XX:MaxGCPauseMillis=200 \
    -XX:+UnlockExperimentalVMOptions \
    -XX:+DisableExplicitGC \
    -XX:+AlwaysPreTouch \
    -XX:G1NewSizePercent=30 \
    -XX:G1MaxNewSizePercent=40 \
    -XX:G1HeapRegionSize=8M \
    -XX:G1ReservePercent=20 \
    -XX:G1HeapWastePercent=5 \
    -XX:G1MixedGCCountTarget=4 \
    -XX:InitiatingHeapOccupancyPercent=15 \
    -XX:G1MixedGCLiveThresholdPercent=90 \
    -XX:G1RSetUpdatingPauseTimePercent=5 \
    -XX:SurvivorRatio=32 \
    -XX:+PerfDisableSharedMem \
    -XX:MaxTenuringThreshold=1 \
    ${MC_JAVA_ARGS} \
    -jar ${jar} \
    --nogui
