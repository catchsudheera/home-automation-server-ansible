# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Hard rules

- **NEVER change anything on the server (`ha-server.home` or any other host).** SSH access (user `ubuntu`, has sudo) is for **read-only inspection only** — checking state, diffing deployed files against this repo, viewing logs. All fixes, no matter how small or how explicitly a "fix" is requested, must be made in the Ansible code in this repo. The user applies changes to the server themselves by running the playbook.
- If a requested fix seems to require a server-side change, make the corresponding change in the Ansible code instead and tell the user what to run.

## Project overview

Ansible playbook that provisions the home automation server (`ha-server.home`) with Docker Compose stacks:

- `environment-setup` — user/group (`ha-user`, uid/gid 1005), Docker install, `ha-server-network`, data root (`/mnt/server_data`, NFS from `nas-server.home` via autofs)
- `container-stack-management` — Dockhand Hawser agent (replaced Portainer)
- `container-stack-home-automation` — Home Assistant, Music Assistant, bgutil-provider, ESPHome, InfluxDB, Grafana, Mosquitto
- `container-stack-matter` — python-matter-server (not currently in `site.yml`)
- `docker-compose-systemd` — per-stack systemd units + hourly image-refresh timers

Conventions: compose files are deployed to hidden dirs in `/home/ha-user/` (`~/.container-stack-*`); persistent container data lives under `/mnt/server_data/container_data/<app>/`.

Entry points: `install.sh` (full run), `start-all.sh` / `stop-all.sh` (tagged runs with `start-stacks` / `stop-stacks`).
