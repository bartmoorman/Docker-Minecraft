#!/bin/bash
if [ ${MC_EULA:-false} == true ] && [ ! -f eula.txt -o ! -f server.properties ]; then
    echo -e '\e[44m##############################\e[49m'
    echo -e '\e[44mPerforming first-time setup.\e[49m'
    echo -e '\e[44mErrors and warnings regarding server.properties and/or eula.txt are expected.\e[49m'
    echo -e '\e[44m##############################\e[49m'
    FIRST_RUN=true

    $(which java) -jar /opt/minecraft/spigot-*.jar
else
    echo -e '\e[41m!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\e[49m'
    echo -e '\e[41mMC_EULA must be set to \e[96mtrue\e[39m.\e[49m'
    echo -e '\e[41mPlease indicate you agree to the EULA (https://account.mojang.com/documents/minecraft_eula).\e[49m'
    echo -e '\e[41m!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\e[49m'
fi

for FILE in eula.txt server.properties; do
    echo -e "Updating \e[94m${FILE}\e[39m:"
    FILE_CHANGED=false

    for KEY in $(grep ^[[:lower:]] ${FILE} | cut -d= -f1); do
        VAR="MC_$(tr [:punct:] _ <<< ${KEY} | tr [:lower:] [:upper:])"

        if [ -v ${VAR} ]; then
            echo -e "\t\e[95m${KEY}\e[39m=\e[96m${!VAR}\e[39m"

            sed --in-place --regexp-extended \
            --expression "s/^(${KEY}=).*/\1${!VAR}/" \
            ${FILE}

            FILE_CHANGED=true
        fi
    done

    if [ ${FILE_CHANGED} == false ]; then
        echo -e '\t\e[93mNothing changed!\e[39m'
    fi
done

LEVEL_NAME=$(grep ^level-name server.properties | cut -d= -f2)

for WORLD in ${LEVEL_NAME}{,_nether,_the_end}; do
    echo -e "Performing maintenance on \e[92m${WORLD}\e[39m:"
    WORLD_CHANGED=false

    if [ -d ${WORLD} -a ! -L ${WORLD} ]; then
        echo -en "\tMoving to \e[94mworldstore\e[39m..."
        rsync --archive --remove-source-files ${WORLD} worldstore
        find ${WORLD} -type d -empty -delete
        echo -e '\e[42mdone\e[49m'
        WORLD_CHANGED=true
    elif [ ! -d worldstore/${WORLD} ]; then
        if [ ${FIRST_RUN:-false} == true ]; then
            echo -e "\t\e[93mSkipping. Please restart the container after worlds are generated.\e[39m"
        else
            echo -e "\t\e[93mCannot find directory! Skipping.\e[39m"
        fi
        continue
    fi

    if [ ${MC_WORLDS_IN_RAM:-false} == true ]; then
        echo -en "\tSyncing to \e[94m/dev/shm/$(hostname)\e[39m..."
        SHM_SIZE=$(df --output=size /dev/shm | sed 1d)
        SHM_MIN=$((1024 * 1024))
        SHM_AVAIL=$(df --output=avail /dev/shm | sed 1d)
        WORLD_SIZE=$(du --summarize worldstore/${WORLD} | cut -f1)
        REQD_AVAIL=$((${WORLD_SIZE} * 120 / 100))

        if [ ${SHM_SIZE} -ge ${SHM_MIN} -a ${SHM_AVAIL} -ge ${REQD_AVAIL} ]; then
            rsync --archive worldstore/${WORLD} /dev/shm/$(hostname)
            ln --symbolic --force /dev/shm/$(hostname)/${WORLD}
            echo -e '\e[42mdone\e[49m'

            WORLD_CHANGED=true
        else
            echo -e '\e[41mfailed\e[49m'
            SHM_DIFF=$((${SHM_MIN} - ${SHM_SIZE}))
            REQD_DIFF=$((${REQD_AVAIL} - ${SHM_AVAIL}))

            if [ ${SHM_DIFF} -ge ${REQD_DIFF} ]; then
                echo -e "\t\t\e[94m/dev/shm\e[93m must be a minumum of ${SHM_MIN}K (\e[91m${SHM_DIFF}K needed\e[93m).\e[39m"
            else
                echo -e "\t\t\e[94m/dev/shm\e[93m does not have enough free space (\e[91m${REQD_DIFF}K needed\e[93m)).\e[39m"
            fi

            ln --symbolic --force worldstore/${WORLD}
        fi
    else
        ln --symbolic --force worldstore/${WORLD}
    fi

    if [ ${WORLD_CHANGED} == false ]; then
        echo -e '\t\e[93mNothing changed!\e[39m'
    fi
done

shutdown() {
    if kill -0 ${SYNC_PID}; then
        echo -en 'Stopping continuous sync...'
        kill ${SYNC_PID}
        wait ${SYNC_PID}
        echo -e '\e[42mdone\e[49m'
    fi

    echo -en 'Stopping SpigotMC...'
    kill ${JAVA_PID}
    wait ${JAVA_PID}
    echo -e '\e[42mdone\e[49m'

    echo -en 'Performing final sync...'
    $(which sync.sh)
    echo -e '\e[42mdone\e[49m'

    echo -e '\e[45mCLEAN SHUTDOWN ;)\e[49m'
}

trap 'shutdown' SIGTERM

$(which java) \
    -Dserver.name=${MC_SERVER_NAME:-minecraft} \
    -Xms${MC_MIN_MEM:-1G} \
    -Xmx${MC_MAX_MEM:-2G} \
    -XX:+UseConcMarkSweepGC \
    -XX:+CMSIncrementalPacing \
    -XX:+AggressiveOpts \
    ${MC_JAVA_ARGS} \
    -jar /opt/minecraft/spigot-*.jar \
    nogui &

JAVA_PID=$!

sleep 2m

$(which sync.sh) -c &

SYNC_PID=$!

wait
