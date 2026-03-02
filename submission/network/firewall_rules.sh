#!/usr/bin/env bash
#
# firewall_rules.sh — Edge device firewall configuration
#
# Requirements:
#   - Default DROP policy on INPUT and FORWARD chains
#   - Allow RTSP (554/tcp, 554/udp) from camera VLAN only
#   - Allow HTTPS (443/tcp) outbound for S3 uploads and API calls
#   - Allow SSH (22/tcp) from management VLAN only
#   - Camera VLAN must not be able to reach management or corporate VLANs
#   - Allow established/related connections
#   - Allow loopback traffic
#   - Allow ICMP for diagnostics
#
# Hints:
#   - Camera VLAN: (define based on your site_plan.md)
#   - Management VLAN: 10.50.1.0/24
#   - Edge device interfaces: eno1 (mgmt/WAN), eno2 (camera VLAN)

set -euo pipefail

# --- Site-specific CIDRs ---
MGMT_VLAN_CIDR="10.50.1.0/24"
CORP_VLAN_CIDR="10.50.10.0/24"
CAMERA_VLAN_CIDR="10.50.20.0/24"

# --- Interfaces ---
IF_MGMT_WAN="eno1"
IF_CAMERA="eno2"

# --- Flush existing rules ---
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X

# --- Default policies ---
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# --- Loopback ---
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# --- Established/Related ---
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# --- SSH from management VLAN only ---
iptables -A INPUT -i "$IF_MGMT_WAN" -p tcp --dport 22 -s "$MGMT_VLAN_CIDR" -m conntrack --ctstate NEW -j ACCEPT

# --- RTSP from camera VLAN only ---
iptables -A INPUT -i "$IF_CAMERA" -p tcp --dport 554 -s "$CAMERA_VLAN_CIDR" -m conntrack --ctstate NEW -j ACCEPT
iptables -A INPUT -i "$IF_CAMERA" -p udp --dport 554 -s "$CAMERA_VLAN_CIDR" -j ACCEPT
iptables -A INPUT -i "$IF_CAMERA" -p udp --dport 3702 -s "$CAMERA_VLAN_CIDR" -j ACCEPT

# --- HTTPS outbound ---
iptables -A OUTPUT -p tcp --dport 443 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT

# --- Camera VLAN isolation (block camera-to-management/corporate) ---
iptables -A FORWARD -i "$IF_CAMERA" -s "$CAMERA_VLAN_CIDR" -d "$MGMT_VLAN_CIDR" -j DROP
iptables -A FORWARD -i "$IF_CAMERA" -s "$CAMERA_VLAN_CIDR" -d "$CORP_VLAN_CIDR" -j DROP
iptables -A FORWARD -i "$IF_CAMERA" -s "$CAMERA_VLAN_CIDR" -j DROP

# --- ICMP ---
iptables -A INPUT -p icmp -j ACCEPT

# --- Logging for dropped packets (optional but recommended) ---
iptables -A INPUT -m limit --limit 10/min --limit-burst 20 -j LOG --log-prefix "iptables INPUT drop: " --log-level 4
iptables -A FORWARD -m limit --limit 10/min --limit-burst 20 -j LOG --log-prefix "iptables FORWARD drop: " --log-level 4

echo "Firewall rules applied successfully"
