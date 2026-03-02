# Golden Image Strategy

## Overview

Build a single, repeatable golden image for all edge devices so deployment is fast, consistent, and auditable across all customer sites. It consists of all standard dependencies and drivers.
Apply  the site-specific configuration at provisioning time(VLANs, DNS/NTP, VPN endpoint, upload cap).

This design supports the required constraints:
- Consistent — every site runs the same basic image.
- Fast provisioning — Production-ready in short span -> as most dependencies are already set-up in base image

## What goes into the Golden Image (immutable)
Base OS + runtime:
- Ubuntu 22.04 LTS (fully patched at image build time)
- Docker Engine + compose plugin
- iptables + iproute2 (`tc`) + logrotate
- chrony (NTP client)
- NVIDIA driver + `nvidia-container-toolkit` (GPU workloads)

Operations:
- systemd unit template for `video-ingest` container
- healthcheck tooling (`/usr/local/bin/healthcheck.sh`)
- firewall tooling (`/usr/local/bin/firewall_rules.sh`)

Security baseline:
- disable root SSH login
- disable password authentication over SSH
- UFW default deny inbound (firewall script can be the final authority)

## What is NOT in the Golden Image (site overlay)

- Site details - Site ID
- VPN secrets
- Network configs
- cloud credentials
- Camera IPs

## Image Creation Process
High-level steps:
1. Start from official Ubuntu 22.04 base image.
2. `apt-get update && apt-get upgrade` and install base packages.
3. Install Docker and configure `/etc/docker/daemon.json` log rotation.
4. Install NVIDIA drivers + container toolkit;
5. Install systemd unit templates + scripts into `/usr/local/bin`.
6. Install logrotate configs.
7. Cleanup apt caches and temporary files.
8. Publish image artifact.

## Configuration Management

1. Copy `site_spec.json`
2. Configure NTP
3. Configure DNS servers
4. Apply firewall rules to enforce camera VLAN isolation (RTSP/ONVIF allowed only from camera VLAN).
5. Generate `/etc/edge/video-ingest.env` and start `video-ingest.service`.

## Patching and Updates
- OS: unattended security upgrades + monthly maintenance window.
- App: update container image tag in `/etc/edge/video-ingest.env` and restart service.
- NVIDIA driver: update only after validation with inference container images.

## Rollback
Re-image to last known-good golden image and restore overlay.
