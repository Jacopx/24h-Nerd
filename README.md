![24h Nerd - 14th Edition - 2026](/24h-nerd-14thEdition.png "24h logo")

# Network documentation: 24h Nerd
![Static Badge](https://img.shields.io/badge/24h_Nerd-14th_Edition-brightgreen)
![Static Badge](https://img.shields.io/badge/Location-Pavignano,Biella-8A2BE2)
![Static Badge](https://img.shields.io/badge/WAN-Eolo_100/20M-blue)

## Introduction
This document is a consolidated reference for all information and configurations related to the network infrastructure used during the 24h NERD event. It has been maintained starting from the 2026 edition, which marks the 14th edition of the event.

## Idea
The network is designed to improve efficiency and reliability, providing a balanced and effective experience for all participants (approximately 25 players).
```
Keep it simple
```
This principle guides every design and implementation decision.

## Hardware
This 14th edition introduces a significant change of location, moving from Boero (Strona) to Pavignano (Biella). In Boero, previous editions benefited from a high-quality FTTH (OpenFiber) gigabit connection. Despite improvements to the venue, the connectivity will be downgraded to an EOLO FWA link rated at _300/50 Mbps_.

From the WAN radio, the LAN infrastructure begins. A MikroTik router is connected to a MikroTik switch via a 50-meter fiber link, which acts as the main aggregation point for all downstream connections.

The main room is divided into two areas:
* CONSOLE
* COMPUTER

Each area is served by a large managed switch acting as the primary collector. Smaller unmanaged switches may be used to reduce cable lengths where necessary.

Devices used in this setup and its themed name:
* **MikroTik hEXs 2025**: [*`Mordor`*] Gateway, router, firewall, QoS, DHCP
* **MikroTik CSS326-24G-2S+RM**: [*`MiddleEarth`*] Managed core switch between router and main room, SFP+ 10G, VLAN support
* **D-Link DGS-1210-24**: [*`Isengard`*] Managed 24-port switch for the COMPUTER area (VLAN 11)
* **D-Link DGS-1100-16**: [*`Rohan`*] Managed 16-port switch for the CONSOLE area (VLAN 12)
* **Zyxel XGS1210-12**: [*`Gondor`*] Managed 12-port Multi-Gig (2.5G) switch with 10G uplinks as backup.
* **Zyxel GS1100-24E**: [*`Bree`*] Unmanaged 24-port switch probably for the COMPUTER area (VLAN 11)
* **Raspberry Pi 3 Model B Rev 1.2**: [*`HelmsDeep`*] Pi-hole
* **MikroTik wAP AX**: [*`MinasTirith`*] Access point for wireless clients in case of necessity, will replace the next one after the configuration updates 
* **GL.iNet GL-MT3000 (Beryl AX)**: [*`MinasMorgul`*] Small travel router used for some wireless client like tablet or Nintendo Switch on OTHER (VLAN 13)
* Additional unmanaged switches

## Software
All devices are managed via WinBox, web configuration interfaces, and SSH.

The network is segmented into four VLANs:
* **TRUST** (VLAN ID 10): *Infrastructure management devices, unrestricted bandwidth for debugging and administration*
* **COMPUTER** (VLAN ID 11): *All computers; primarily connected to `Isengard`, with additional ports available on `MiddleEarth`; Probably `Bree` will be used here to extend and simplify the physical connection in the computers area*
* **CONSOLE** (VLAN ID 12): *All consoles; primarily connected to `Rohan`, with additional ports available on `MiddleEarth`*
* **OTHER** (VLAN ID 13): *All remaining devices that do not fit the previous categories; ports are available on all switches regardless of area*

### Mordor
`Mordor`, a MikroTik hEX S (2025), handles routing and firewall duties. The device is powerful enough to manage a 2.5G FTTH link, making it future-proof. For the 2026 edition, the ISP connection will be an EOLO FWA link with the following theoretical bandwidth:

| Type     | Speed     |
|----------|:---------:|
| Download | 100 Mbps  |
| Upload   | 20 Mbps   |

The output of the [network_monitor.sh](/network_monitor.sh) script is the following:

```
╔══════════════════════════════════════════════════════╗
║              FINAL SUMMARY (15 min run)              ║
╚══════════════════════════════════════════════════════╝
  Cycles completed : 16
  Ended at         : Sat Feb 21 12:10:19 CET 2026

── Ping (averages across all cycles) ───────────────────
  TARGET             LOSS%    AVG ms    MIN ms    MAX ms    JITTER
  ─────────────────────────────────────────────────────────
  8.8.8.8             0.0%     12.90      8.12     22.32      3.02
  1.1.1.1             0.0%     18.47     13.08     26.23      2.73
  google.it           0.0%     12.78      7.93     19.93      2.89

── Speedtest (per cycle + average) ─────────────────────
   CYCLE   DOWN Mbps     UP Mbps     PING ms   JITTER ms
  ─────────────────────────────────────────────────────────
       1       92.08       17.24       14.74        5.48
       2       91.54       17.34       11.07        4.56
       3       91.29       17.48       11.82        5.23
       4       92.36       17.18       15.02        4.65
       5       89.97       17.22       14.52        4.76
       6       89.79       17.25       14.31        3.64
       7       90.58       17.17       12.33        2.96
       8       89.64       17.24       17.02        5.03
       9       90.57       17.16       14.48         6.2
      10       90.79       17.16       13.91        4.04
      11       91.12       17.31       11.18        2.68
      12       91.89       17.25       14.21        6.48
      13       90.27       17.23       11.57        4.08
      14       90.38       17.25       12.06        4.76
      15       90.43       17.17       14.73        6.56
      16        85.6       17.32       12.47        2.62
  ─────────────────────────────────────────────────────────
  AVG          90.51       17.24       13.46        4.60
```
Due to the nature of the network, it is essential to cap client bandwidth. Saturating either the uplink or downlink would severely degrade overall network quality. For this reason, QoS policies are enforced using the following queue tree structure:

| Queue Group                | Download (Mbps) | Upload (Mbps) |
|----------------------------|-----------------|---------------|
| TRUST / COMPUTER / CONSOLE | 95              | 18            |
| OTHER                      | 25              | 5             |

The queue type used is **PCQ**, ensuring fair bandwidth distribution among clients. This approach leaves sufficient headroom and minimizes disruptions.

The ports on the router itself are assigned as follows:

| Port   | Name              | VLAN TAG |
|--------|-------------------|----------|
| SFP    | toMiddleEarth     | TRUNK    |
| Port1  | WAN2              | -        |
| Port2  | mgmt              | -        |
| Port3  | TRUST             | 10       |
| Port4  | trunk             | TRUNK    |
| Port5  | WAN1 (PoE)        | -        |

Except for the SFP and WAN connections, no other devices should be directly linked to this router. We will evaluate on site whether to use Port5’s PoE capability to power the FWA Eolo antenna. 

If a second WAN becomes available, a failover configuration using Port5 (deafult route with distance 1) and Port1 (deafult route with distance 2) will be implemented.

To enable a plug-and-play experience, each VLAN is served by its own DHCP server with a 2-day lease time, following this addressing plan:

| VLAN     | Network         | DNS            |
|----------|:---------------:|:--------------:|
| MGMT     | 172.16.99.0/30  | —              |
| TRUST    | 172.16.100.0/29 | 172.16.100.2   |
| COMPUTER | 172.16.101.0/27 | 172.16.101.2   |
| CONSOLE  | 172.16.102.0/27 | 172.16.102.2   |
| OTHER    | 172.16.103.0/27 | 172.16.103.2   |

All inter-VLAN communication is blocked.

DNS resolution is handled by `HelmsDeep`, a Pi-hole instance reachable from all active VLANs. It caches and forwards requests to `Mordor`. All TCP/UDP traffic destined for port 53 is transparently redirected to `Mordor`; the use of public DNS servers is blocked for security reasons.

The adlist in use is:
```
https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/pro.plus.txt
```

### Diagram
```
                                INTERNET
                                   |
                             EOLO FWA 300/50
                                   |
                           +---------------+
                           |   [ Mordor ]  |
                           |     hEX s     |
                           +-------+-------+
                                   |
                              1G SFP 40m
                                   |
      +---------------------------------------------------------------+
      |                        [ MiddleEarth ]                        |
      |                           CSS326-24G                          |
      |---------------------------------------------------------------|
      |  TRUNK → HelmsDeep (Pi-hole DNS)                              |
      |  VLAN 13 → MinasMorgul (GL-iNet AP)                           |
      +---------------------------+-----------------------------------+
                                  |
                 _________________|_____________________
                /                                       \
               /                                         \
      +----------------------+                 +----------------------+
      |      [ Isengard ]    |                 |       [ Rohan ]      |
      |      DGS-1210-24     |                 |      DGS-1100-16     |
      |----------------------|                 |----------------------|
      | COMPUTER  VLAN 11    |                 | CONSOLE   VLAN 12    |
      | OTHER     VLAN 13    |                 | OTHER     VLAN 13    |
      +----------+-----------+                 +-----------+----------+
                 |                                         |
             [ Bree ]                                   Consoles
          (VLAN 11 ext.)
```

### MiddleEarth
`MiddleEarth` is the core switch, a MikroTik CSS326-24G-2S+RM, connecting `Mordor` to the rest of the network via a 1G SFP fiber module. It runs SwOS 2.18. Aside from VLAN configuration and port renaming for usability, no special settings are applied.

| Port   | Name              | VLAN TAG |
|--------|-------------------|----------|
| Port1  | TRUNK1 ETH        | TRUNK    |
| Port2  | TRUNK1 ETH        | TRUNK    |
| Port3  | mgmt              | -        |
| Port4  | TRUST             | 10       |
| Port5  | to`HelmsDeep`     | TRUNK    |
| Port6  | to`MinasMorgul`   | 13       |
| Port7  | OTHER             | 13       |
| Port8  | OTHER             | 13       |
| Port9  | to`Rohan`         | TRUNK    |
| Port10 | COMPUTER          | 11       |
| Port11 | COMPUTER          | 11       |
| Port12 | COMPUTER          | 11       |
| Port13 | COMPUTER          | 11       |
| Port14 | COMPUTER          | 11       |
| Port15 | COMPUTER          | 11       |
| Port16 | COMPUTER          | 11       |
| Port17 | to`Isengard`      | TRUNK    |
| Port18 | CONSOLE           | 12       |
| Port19 | CONSOLE           | 12       |
| Port20 | CONSOLE           | 12       |
| Port21 | CONSOLE           | 12       |
| Port22 | CONSOLE           | 12       |
| Port23 | TRUNK1+           | TRUNK    |
| Port24 | TRUNK2+           | TRUNK    |

The web interface is available on the TRUST VLAN at [http://172.16.100.6](http://172.16.100.6).

### Isengard
`Isengard` serves the COMPUTER area and is a D-Link DGS-1210-24. Ports are available for COMPUTER and OTHER VLANs only.

| Port   | Name             | VLAN TAG |
| ------ | ---------------- | -------- |
| Port1  | to `MiddleEarth` | TRUNK    |
| Port2  | TRUNK ETH        | TRUNK    |
| Port3  | MGMT             | —        |
| Port4  | TRUST            | 10       |
| Port5  | COMPUTER         | 11       |
| Port6  | COMPUTER         | 11       |
| Port7  | COMPUTER         | 11       |
| Port8  | COMPUTER         | 11       |
| Port9  | COMPUTER         | 11       |
| Port10 | COMPUTER         | 11       |
| Port11 | COMPUTER         | 11       |
| Port12 | COMPUTER         | 11       |
| Port13 | COMPUTER         | 11       |
| Port14 | COMPUTER         | 11       |
| Port15 | COMPUTER         | 11       |
| Port16 | COMPUTER         | 11       |
| Port17 | COMPUTER         | 11       |
| Port18 | COMPUTER         | 11       |
| Port19 | COMPUTER         | 11       |
| Port20 | to `Bree`        | 11       |
| Port21 | OTHER            | 13       |
| Port22 | OTHER            | 13       |
| Port23 | OTHER            | 13       |
| Port24 | OTHER            | 13       |
| Port25 | TRUNK SFP        | TRUNK    |
| Port26 | TRUNK SFP        | TRUNK    |
| Port27 | TRUNK SFP        | TRUNK    |
| Port28 | TRUNK SFP        | TRUNK    |

The web interface is available on the TRUST VLAN at [http://172.16.100.5](http://172.16.100.5).
Remember that the DHCP configuration is working only during the startup of the switch.

### Rohan
`Rohan` serves the CONSOLE area and is a D-Link DGS-1110-16. Ports are available for CONSOLE and OTHER VLANs only.

| Port   | Name             | VLAN TAG |
| ------ | ---------------- | -------- |
| Port1  | to `MiddleEarth` | TRUNK    |
| Port2  | TRUNK ETH        | TRUNK    |
| Port3  | MGMT             | —        |
| Port4  | TRUST            | 10       |
| Port5  | CONSOLE          | 12       |
| Port6  | CONSOLE          | 12       |
| Port7  | CONSOLE          | 12       |
| Port8  | CONSOLE          | 12       |
| Port9  | CONSOLE          | 12       |
| Port10 | CONSOLE          | 12       |
| Port11 | CONSOLE          | 12       |
| Port12 | CONSOLE          | 12       |
| Port13 | CONSOLE          | 12       |
| Port14 | CONSOLE          | 12       |
| Port15 | OTHER            | 13       |
| Port16 | OTHER            | 13       |

The web interface is available on the TRUST VLAN at [http://172.16.100.4](http://172.16.100.4).
Remember that the DHCP configuration is working only during the startup of the switch.

## Gondor
`Gondor` is a powerful managed switch with 2.5G and 10G links will not be configured until the day of the games, will be used ad a backup in case of failure of some of the others. 

## Bree
`Bree` is an unmanaged switch, will be probably used within a COMPUTER port of `Isengard` to physically improve the cables connection.

## Inventory
All the material used in order to check:
- [X] MikroTik hEXs
- [X] MikroTik CSS
- [X] D-Link DGS-1210
- [X] D-Link DGS-1100
- [X] Zyxel GS1100
- [X] Zyxel XGS1210-12
- [X] 2x SFP LC module
- [X] 40m LC Cable
- [X] Raspberry Pi3
- [X] GL-iNet

- [ ] Power socket
- [X] 1x 30m Red RJ45 CAT.6 ethernet cable
- [X] 1x 20m Red RJ45 CAT.6 ethernet cable
- [X] 2x 15m Red RJ45 CAT.6 ethernet cable
- [X] 2x 10m Orange RJ45 CAT.5e ethernet cable
- [X] 1x 5m Blue RJ45 CAT.6 ethernet cable
- [X] 2x 0.3m black RJ45 CAT.6 ethernet cable
- [X] Various short-medium-long ethernet cables

## Backup
```
/system backup save name=mordor-hexs-14thEdition
/export file=mordor-hexs-14thEdition
```