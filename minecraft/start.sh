#!/bin/bash
if [ ! -f eula.txt ]; then
  $(which java) -jar /opt/minecraft/spigot-*.jar

  sed --in-place --regexp-extended \
  --expression 's/^(eula=).*/\1true/' \
  eula.txt
fi

sed --in-place --regexp-extended \
--expresion "s/^(server-port=).*/\1${MC_PORT}/" \
server.properties

exec $(which java) \
    -Xms${MC_MIN_MEM} \
    -Xmx${MC_MAX_MEM} \
    -XX:+UseConcMarkSweepGC \
    -XX:+CMSIncrementalPacing \
    -XX:+AggressiveOpts \
    -jar /opt/minecraft/spigot-*.jar \
    nogui
