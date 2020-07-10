#!/bin/bash
while getopts 'c' OPTION; do
    case ${OPTION} in
        c)
            CONTINUOUS=true
            ;;
    esac
done

doSync() {
    for WORLD in ${LEVEL_NAME}{,_nether,_the_end}; do
        if [ -d /dev/shm/$(hostname)/${WORLD} ]; then
            rsync --archive --delete /dev/shm/$(hostname)/${WORLD} worldstore
        fi
    done
}

if [ ${MC_WORLDS_IN_RAM:-false} == true ]; then
    LEVEL_NAME=$(grep ^level-name server.properties | cut -d= -f2)

    if [ ${CONTINUOUS:-false} == true ]; then
        while true; do
            doSync
            sleep ${MC_SYNC_INTERVAL:-5m}
        done
    else
        doSync
    fi
fi
