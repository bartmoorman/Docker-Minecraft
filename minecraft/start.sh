#!/bin/bash
if [ ! -f eula.txt -o ! -f server.properties ]; then
  $(which java) -jar /opt/minecraft/spigot-*.jar
fi

for FILE in eula.txt server.properties; do
  echo "Updating ${FILE}:"
  CHANGED=false

  for KEY in $(grep ^[[:lower:]] ${FILE} | cut -d= -f1); do
    VAR="MC_$(tr [:punct:] _ <<< ${KEY} | tr [:lower:] [:upper:])"

    if [ -v ${VAR} ]; then
      echo -e "\t${KEY}=${!VAR}"

      sed --in-place --regexp-extended \
      --expression 's/^(${KEY}=).*/\1${!VAR}/' \
      ${FILE}

      CHANGED=true
    fi
  done

  if [ ${CHANGED} = false ]; then
    echo -e '\tNothing changed!'
  fi
done

exec $(which java) \
    -Xms${MC_MIN_MEM} \
    -Xmx${MC_MAX_MEM} \
    -XX:+UseConcMarkSweepGC \
    -XX:+CMSIncrementalPacing \
    -XX:+AggressiveOpts \
    ${MC_JAVA_OPTS} \
    -jar /opt/minecraft/spigot-*.jar \
    nogui
