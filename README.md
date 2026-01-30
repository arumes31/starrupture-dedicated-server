# Docker for a StarRupture dedicated server

![Static Badge](https://img.shields.io/badge/GitHub-starrupture--dedicated--server-blue?logo=github)

## Table of contents
- [Docker Run command](#docker-run)
- [Docker Compose command](#docker-compose)
- [Environment variables server settings](#environment-variables-server-settings)
  
This is a Docker container to help you get started with hosting your own [StarRupture](https://starrupture-game.com/) dedicated server.

## Info

- Start the image with the wished port (7777 by default) and then connect ingame to start a game and set passwords.
- The gameplay will use UDP protocol, the manage server functionality will use TCP.
- Assuming you want to auto-load the savegame then enable the USE_DSSETTINGS environment variable.
- This image uses the pterodactyl/wine yolk [Ptero-Eggs](https://github.com/ptero-eggs/) as it was the only thing working. Thank you guys for your work!

| Volume   | Path                                                     | Description                                                                                                    |
|----------|----------------------------------------------------------|----------------------------------------------------------------------------------------------------------------|
| savegame | /home/container/server_files/StarRupture/Saved/SaveGames | The path where the savegame will be                                                                            |
| server   | /home/container/server_files                             | The path where steam will install the starrupture dedicated server (optional to store to avoid re-downloading) |

## Getting started

- Configure and start the container
- Connect to the server via "Manage Server" in-game (you will need the IP address of the server, no DNS :(" )
- Set the password for the server and create a new session (new savegame) with optional a session password
- If you set the USE_DSSETTINGS environment variable the scripts will add a DSSettings.txt which will auto-load the savegame on next restart of the server

## Docker Run

```bash
docker run -d \
    --name starrupture \
    -p 7777:7777/udp \
    -p 7777:7777/tcp \
    -p 27015:27015/udp \
    -v ./savegame:"/home/container/server_files/StarRupture/Saved/SaveGames" \
    -v ./server:"/home/container/server_files" \
    -e SERVER_PORT=7777 \
    -e USE_DSSETTINGS=true \
    ghcr.io/arumes31/starrupture-dedicated-server:latest
```

## Docker Compose

```yml
services:
  starrupture:
    container_name: starrupture
    image: ghcr.io/arumes31/starrupture-dedicated-server:latest
    network_mode: bridge
    environment:
      - SERVER_PORT=7777
      - USE_DSSETTINGS=true
      - AUTO_UPDATE=true
      - VALIDATE_FILES=true
    volumes:
      - './savegame:/home/container/server_files/StarRupture/Saved/SaveGames:rw'
      - './server:/home/container/server_files:rw'
    ports:
      - '7777:7777/udp'
      - '7777:7777/tcp'
      - '27015:27015/udp'
    restart: unless-stopped
```

## Environment variables server settings

You can use these environment variables for your server settings:

| Variable       | Default | Description                                                         |
|----------------|---------|---------------------------------------------------------------------|
| SERVER_PORT    | 7777    | The port that clients will connect to for gameplay                  |
| USE_DSSETTINGS | false   | Set to true if you want a DSSettings.txt (auto-start) to be created |
| AUTO_UPDATE    | true    | Set to false to skip SteamCMD update on startup (faster restart)    |
| VALIDATE_FILES | true    | Set to false to skip file validation during update                  |

## Links
Github [https://github.com/arumes31/starrupture-dedicated-server](https://github.com/arumes31/starrupture-dedicated-server)