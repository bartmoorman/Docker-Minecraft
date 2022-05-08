#!/usr/bin/env bash
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
    echo "done (${MC_VERSION})"
fi

flavor="Vanilla Minecraft ${MC_VERSION}"
jar=${base}/sever-${MC_VERSION}.jar

if [ ! -f ${jar} ]; then
    echo -n "Downloading Minecraft ${MC_VERSION} ... "
    versionUrl=$(jq --raw-output --arg id ${MC_VERSION} '.versions[] | select(.id == $id) | .url' <<< ${manifest})
    fileUrl=$(curl --silent --location "${versionUrl}" | jq --raw-output '.downloads.server.url')
    wget --quiet --directory-prefix ${base} "${fileUrl}"
    mv ${base}/server.jar ${jar}
    echo 'done'
fi

if [ ! -f eula.txt -o ! -f server.properties ]; then
    echo -e '\e[44m##############################\e[49m'
    echo -e '\e[44mPerforming first-time setup.\e[49m'
    echo -e '\e[44mERRORs and WARNings regarding server.properties and/or eula.txt are expected.\e[49m'
    echo -e '\e[44m##############################\e[49m'
    $(which java) -jar ${jar} --initSettings
fi

if [ ${MC_PAPER:-false} == true ]; then
    if [ ${MC_PAPER_BUILD:-latest} == latest ]; then
        echo -n "Identifying latest Paper build for Minecraft ${MC_VERSION} ... "
        buildsUrl="https://papermc.io/api/v2/projects/paper/versions/${MC_VERSION}"
        MC_PAPER_BUILD=$(curl --silent --location "${buildsUrl}" | jq --raw-output '.builds[-1]')
        echo "done (${MC_PAPER_BUILD})"
    fi

    flavor="Paper ${MC_VERSION}-${MC_PAPER_BUILD}"
    jar=${base}/paper-${MC_VERSION}-${MC_PAPER_BUILD}.jar

    if [ ! -f ${jar} ]; then
        echo -n "Downloading Paper ${MC_VERSION}-${MC_PAPER_BUILD} ... "
        fileUrl="https://papermc.io/api/v2/projects/paper/versions/${MC_VERSION}/builds/${MC_PAPER_BUILD}/downloads/paper-${MC_VERSION}-${MC_PAPER_BUILD}.jar"
        wget --quiet --directory-prefix ${base} "${fileUrl}"
        echo 'done'
    fi
elif [ ${MC_FABRIC:-false} == true ]; then
    if [ ${MC_FABRIC_INSTALLER_VERSION:-latest} == latest ]; then
        echo -n 'Identifying latest Fabric installer version ... '
        metadata=$(curl --silent --location "https://maven.fabricmc.net/net/fabricmc/fabric-installer/maven-metadata.xml")
        MC_FABRIC_INSTALLER_VERSION=$(xgrep -t -x '//metadata/versioning/release/text()' <<< ${metadata})
        echo "done (${MC_FABRIC_INSTALLER_VERSION})"
    fi

    flavor="${flavor} via Fabric"
    installer=${base}/fabric-installer-${MC_FABRIC_INSTALLER_VERSION}-${MC_VERSION}.jar
    launcher=${base}/fabric-server-launch-${MC_VERSION}.jar

    if [ ! -f ${installer} -o ! -f ${launcher} ]; then
        echo -n "Downloading Fabric installer ${MC_FABRIC_INSTALLER_VERSION} ... "
        fileUrl="https://maven.fabricmc.net/net/fabricmc/fabric-installer/${MC_FABRIC_INSTALLER_VERSION}/fabric-installer-${MC_FABRIC_INSTALLER_VERSION}.jar"
        wget --quiet --directory-prefix ${base} "${fileUrl}"
        mv ${base}/fabric-installer-${MC_FABRIC_INSTALLER_VERSION}.jar ${installer}
        echo 'done'

        echo "Installing Fabric for Minecraft ${MC_VERSION} ... "
        $(which java) -jar ${installer} server -dir ${base} -mcversion ${MC_VERSION}
        mv ${base}/fabric-server-launch.jar ${launcher}
    fi

    if [ ! -f fabric-server-launcher.properties ]; then
        cat << EOF > fabric-server-launcher.properties
#$(date +'%a %b %d %H:%M:%S %Z %Y')
serverJar=${jar}
EOF
    else
        sed --in-place --regexp-extended \
        --expression "s|^(serverJar=).*|\1${jar}|" \
        fabric-server-launcher.properties
    fi

    jar=${launcher}
fi

if [ -n ${MC_WORLD_ZIP} -a ! -f level.dat ]; then
    echo -n 'Downloading and extracting world zip'
    curl --silet --location --output ${base}/world.zip "${MC_WORLD_ZIP}"
    unzip ${base}/world.zip
    echo 'done'
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

echo "Starting ${flavor} ..."

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
