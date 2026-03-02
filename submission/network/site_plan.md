# Site Network Plan

Review `data/site_spec.json` for the customer site specification.

## VLAN Design
| VLAN ID | Name | Subnet | Purpose |
|---------|------|--------|---------|
| 1       | management  | 10.50.1.0/24     | IT management and SSH access |
| 10      | corporate   | 10.50.10.0/24    | Existing corporate LAN |
| 20      | cameras     | 10.50.20.0/24    | Isolated camera network (ONVIF/RTSP cameras) |

## IP Addressing Scheme
Edge device:
NICs:
- 'eno1': management + WAN uplink (VLAN 1)
- 'eno2': camera VLAN (VLAN 20)

Static addressing:
- 'eno1' (mgmt): '10.50.1.50', 
-  default gateway: '10.50.1.1'
- 'eno2' (cameras): '10.50.20.1'

DNS servers: '10.50.1.10', '10.50.1.11'
NTP: '10.50.1.10'

##DHCP Range for cameras
- VLAN 20 DHCP scope (recommended): '10.50.20.100' – '10.50.20.200'

## Camera Network Isolation
- Cameras are in VLAN 20 only.
- Edge firewall enforces:
  - default DROP on INPUT/FORWARD
  - allow RTSP (554 TCP/UDP) from camera VLAN to edge only
  - block camera VLAN routing to management/corporate VLANs
  - allow SSH to edge from management VLAN only

## Edge Device Network Configuration
- NIC mapping:
  - `eno1`: management/uplink (VPN/Internet egress)
  - `eno2`: camera VLAN 20
- Routing:
  - default route via `eno1`
  - no forwarding path from VLAN 20 → VLAN 1/10

## Traffic Flow
1. Cameras (VLAN 20) stream RTSP to edge over `eno2`.
2. Edge performs chunking/processing locally.
3. Edge uploads chunks to S3 via VPN.
4. Remote management occurs from management VLAN (VLAN 1) per requirement.
