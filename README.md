### Docker Run
```
docker run \
--detach \
--name minecraft \
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
    volumes:
      - minecraft-datag:/var/lib/minecraft

volumes:
  minecraft-data:
```
