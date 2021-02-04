#!/bin/bash
if [ ${MC_EULA:-false} != true ]; then
    echo -e '\e[41m!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\e[49m'
    echo -e '\e[41mMC_EULA must always be set to true.\e[49m'
    echo -e '\e[41mPlease indicate you agree to the EULA (https://account.mojang.com/documents/minecraft_eula).\e[49m'
    echo -e '\e[41m!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\e[49m'
    exit
fi

if [ ! -f eula.txt -o ! -f server.properties ]; then
    echo -e '\e[44m##############################\e[49m'
    echo -e '\e[44mPerforming first-time setup.\e[49m'
    echo -e '\e[44mErrors and warnings regarding server.properties and/or eula.txt are expected.\e[49m'
    echo -e '\e[44m##############################\e[49m'

    $(which java) -jar /opt/minecraft/spigot-*.jar
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
    -jar /opt/minecraft/spigot-*.jar \
    nogui
