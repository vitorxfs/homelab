# 🖥️ Homelab

## ☁️ Services

- Heimdall: Dashboard
- Jellyfin: Media service
- Filebrowser: File manager
- Prometheus: Collecting metrics
- Grafana: Displaying metrics

## 🌐 Ports
- heimdall: `80`
- jellyfin: `8000`
- filebrowser: `8001`
- prometheus: `9090`
- grafana: `3000`

## 🛠️ Setup
`git clone https://github.com/vitorxfs/homelab.git`

`cd homelab`

Create a folder ./secrets and add separate files for each of the following secrets:
```
- gf_admin_password.txt -> admin password for grafana
```

Finally, run
`docker-compose up`


### 🐋 Setting up Prometheus and Docker metrics

Create the file `daemon.json` at `/etc/docker` and paste the following JSON:
`
{
  "metrics-addr": "127.0.0.1:9323"
}
`

Access Prometheus' targets at [localhost:9090/targets](http://localhost:9090/targets). Check if Daemon is `UP`.

## 🏁 That's it for now!
You are good to go! 🥳🎉
