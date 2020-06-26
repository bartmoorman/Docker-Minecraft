### Docker Run
```
docker run \
--detach \
--name minecraft \
--restart unless-stopped \
--volume minecraft-data:/var/lib/minecraft \
bmoorman/minecraft:latest
```

### Docker Compose
```
version: "3.7"
services:
  minecraft:
    image: bmoorman/minecraft:latest
    container_name: minecraft
    restart: unless-stopped
    volumes:
      - minecraft-data:/var/lib/minecraft

volumes:
  minecraft-data:
```

### Environment Variables
|Variable|Description|Default|
|--------|-----------|-------|
|TZ|Sets the timezone|`America/Denver`|
|MC_MIN_MEM|Sets the minimum RAM allocated to java|`1G`|
|MC_MAX_MEM|Sets the maximum RAM allocated to java|`2G`|
|MC_JAVA_ARGS|Sets custom args passed to java|`<empty>`|

### server.properties
All options in `eula.txt` and `server.properties` can be updated using environment variables with:
```
MC_<Key>
```
Everything should be uppercase, `.` and `-` should be replaced by `_`. For example, if you want to update these settings:
```
eula=true
level-type=flat
view-distance=16
```
You would set the following environment variables:
```
MC_EULA=true
MC_LEVEL_TYPE=flat
MC_VIEW_DISTANCE=16
```
