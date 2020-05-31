#!/bin/bash
if [ ! -f /config/eula.txt ]; then
  $(which java) -jar /opt/minecraft/spigot-*.jar

  sed --in-place --regexp-extended \
  --expression 's/^(eula=).*/\1true/' \
  /config/eula.txt
fi

sed --in-place --regexp-extended \
--expresion "s/^(server-port=).*/\1${MC_PORT}/" \
/config/server.properties

exec $(which java) \
    -Xms${MC_MIN_MEM} \
    -Xmx${MC_MAX_MEM} \
    -XX:+UseConcMarkSweepGC \
    -XX:+CMSIncrementalPacing \
    -XX:+AggressiveOpts \
    -jar /opt/minecraft/spigot-*.jar \
    nogui
