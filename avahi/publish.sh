#!/bin/sh

set -e

# Pega o IP da interface wlp1s0 (sem grep -P)
IP=$(ip -4 addr show wlp1s0 | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)

if [ -z "$IP" ]; then
  echo "ERRO: não consegui pegar o IP da wlp1s0"
  exit 1
fi

echo "Publicando aliases para $IP:"

HOSTNAMES="heimdall.local jellyfin.local homeassistant.local prometheus.local grafana.local n8n.local ttrss.local"

for host in $HOSTNAMES; do
  echo "  -> $host"
  avahi-publish-address -R "$host" "$IP" &
done

wait
