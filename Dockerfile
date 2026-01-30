FROM ghcr.io/ptero-eggs/yolks:wine_latest

LABEL author="arumes31" maintainer="https://github.com/arumes31"

# ports
EXPOSE 7777/udp 27015/udp

# customization
VOLUME ["/home/container/server_files"]

RUN mkdir -p "/home/container/server_files/StarRupture/Saved/SaveGames"
VOLUME ["/home/container/server_files/StarRupture/Saved/SaveGames"]

ADD scripts /home/container/scripts
RUN chmod +x /home/container/scripts/*.sh

CMD ["/home/container/scripts/start.sh"]
