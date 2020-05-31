### Docker Run
```
docker run \
--detach \
--name minecraft \
--volume minecraft-config:/config \
bmoorman/minecraft:latest
```

### Docker Compose
```
version: "3.7"
services:
  minecraft:
    image: bmoorman/minecraft:latest
    container_name: minecraft
    volumes:
      - minecraft-config:/config

volumes:
  minecraft-config:
```
