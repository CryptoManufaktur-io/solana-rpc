FROM ubuntu/prometheus

RUN apt-get update && apt-get install  -y bash tzdata
COPY ./global-prom.yml /etc/prometheus/
COPY ./choose-config.sh /usr/local/bin/choose-config.sh

ENTRYPOINT choose-config.sh

CMD ["/bin/prometheus", "--storage.tsdb.path=/prometheus", "--web.console.libraries=/usr/share/prometheus/console_libraries", "--web.console.templates=/usr/share/prometheus/consoles"]
