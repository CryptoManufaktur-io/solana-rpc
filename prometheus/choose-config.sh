#!/bin/bash
# Appends custom-prom.yml if it exists to /etc/prometheus/prometheus.yml
# Expects a full prometheus command with parameters as argument(s)

cp /etc/prometheus/global-prom.yml /etc/prometheus/prometheus.yml

if [ -f "/etc/prometheus/custom-prom.yml" ]; then
    cat /etc/prometheus/custom-prom.yml >> /etc/prometheus/prometheus.yml
fi

exec "$@" --config.file=/etc/prometheus/prometheus.yml
