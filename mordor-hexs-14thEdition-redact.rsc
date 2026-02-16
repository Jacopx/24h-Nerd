/interface bridge
add admin-mac= auto-mac=no name=bridge vlan-filtering=yes

/interface ethernet
set [ find default-name=ether1 ] comment=WAN2
set [ find default-name=ether2 ] comment=MGMT
set [ find default-name=ether3 ] comment=TRUST
set [ find default-name=ether4 ] comment=TRUNK disabled=yes
set [ find default-name=ether5 ] poe-out=forced-on
set [ find default-name=sfp1 ] comment="to MiddleEarth"

/interface vlan
add interface=bridge name=COMPUTER vlan-id=11
add interface=bridge name=CONSOLE vlan-id=12
add interface=bridge name=OTHER vlan-id=13
add interface=bridge name=TRUST vlan-id=10
add interface=ether5 name=vPPP vlan-id=100

/interface pppoe-client
add add-default-route=yes comment="WAN - Eolo" disabled=no interface=vPPP name=pppoe-eolo

/interface list
add comment=defconf name=WAN
add comment=defconf name=LAN
add name=MGMT
add name=noTrust

/ip pool
add comment=MGMT name=pool-mgmt ranges=172.16.99.2
add comment=COMPUTER name=computer-pool ranges=172.16.101.2-172.16.101.30
add comment=CONSOLE name=console-pool ranges=172.16.102.2-172.16.102.30
add comment=OTHER name=other-pool ranges=172.16.103.2-172.16.103.30
add comment=TRUST name=trust-pool ranges=172.16.100.2-172.16.100.6

/ip dhcp-server
add address-pool=pool-mgmt interface=ether2 lease-time=2d name=dhcp-mgmt
add address-pool=computer-pool comment=COMPUTER interface=COMPUTER lease-time=2d name=dhcp-computer
add address-pool=console-pool comment=CONSOLE interface=CONSOLE lease-time=2d name=dhcp-console
add address-pool=other-pool comment=OTHER interface=OTHER lease-time=2d name=dhcp-other
add address-pool=trust-pool comment=TRUST interface=TRUST lease-time=2d name=dhcp-trust

/queue tree
add name=download parent=global
add name=upload parent=global

/queue type
add kind=pcq name=PCQ-down pcq-classifier=dst-address pcq-rate=100M
add kind=pcq name=PCQ-up pcq-classifier=src-address pcq-rate=20M

/queue tree
add max-limit=95M name=all_d packet-mark=download_packet parent=download queue=PCQ-down
add max-limit=18M name=all_u packet-mark=upload_packet parent=upload queue=PCQ-up
add max-limit=20M name=oth_d packet-mark=download_packet_oth parent=download queue=PCQ-down
add max-limit=5M name=oth_u packet-mark=upload_packet_oth parent=upload queue=PCQ-up

/disk settings
set auto-media-interface=bridge auto-media-sharing=yes auto-smb-sharing=yes

/interface bridge port
add bridge=bridge comment=trust interface=ether3 pvid=10
add bridge=bridge comment=trunk interface=ether4
add bridge=bridge comment="to MiddleEarth" interface=sfp1

/ip neighbor discovery-settings
set discover-interface-list=LAN

/interface bridge vlan
add bridge=bridge comment=TRUST tagged=bridge,sfp1,ether4 untagged=ether3 vlan-ids=10
add bridge=bridge comment=COMPUTER tagged=bridge,sfp1,ether4 vlan-ids=11
add bridge=bridge comment=CONSOLE tagged=bridge,sfp1,ether4 vlan-ids=12
add bridge=bridge comment=OTHER tagged=bridge,sfp1,ether4 vlan-ids=13

/interface list member
add interface=ether1 list=WAN
add interface=ether2 list=MGMT
add interface=TRUST list=LAN
add interface=TRUST list=MGMT
add interface=OTHER list=LAN
add interface=CONSOLE list=LAN
add interface=COMPUTER list=LAN
add interface=COMPUTER list=noTrust
add interface=CONSOLE list=noTrust
add interface=OTHER list=noTrust
add interface=pppoe-eolo list=WAN

/ip address
add address=172.16.99.1/30 comment=MGMT interface=ether2 network=172.16.99.0
add address=172.16.101.1/27 comment=COMPUTER interface=COMPUTER network=172.16.101.0
add address=172.16.102.1/27 comment=CONSOLE interface=CONSOLE network=172.16.102.0
add address=172.16.103.1/27 comment=OTHER interface=OTHER network=172.16.103.0
add address=172.16.100.1/29 comment=TRUST interface=TRUST network=172.16.100.0

/ip dhcp-client
add comment=WAN2 default-route-distance=2 interface=ether1

/ip dhcp-server network
add address=172.16.99.0/30 dns-server=172.16.99.1 gateway=172.16.99.1
add address=172.16.100.0/29 comment=TRUST dns-server=172.16.100.2 domain=trust gateway=172.16.100.1 netmask=29
add address=172.16.101.0/27 comment=COMPUTER dns-server=172.16.101.2 domain=computer gateway=172.16.101.1 netmask=27
add address=172.16.102.0/27 comment=CONSOLE dns-server=172.16.102.2 domain=console gateway=172.16.102.1 netmask=27
add address=172.16.103.0/27 comment=OTHER dns-server=172.16.103.2 domain=other gateway=172.16.103.1 netmask=27

/ip dns
set allow-remote-requests=yes cache-size=35000KiB servers=1.1.1.1,1.0.0.1,8.8.8.8,8.8.4.4

/ip dns adlistadd url="https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/pro.plus.txt"

/ip dns static
add address=172.16.100.3 name=jacopxmbp.king type=A
add address=172.16.101.30 name=jacopxmbp.king type=A
add address=172.16.102.30 name=jacopxmbp.king type=A
add address=172.16.103.30 name=jacopxmbp.king type=A
add address=172.16.100.2 name=helmsdeep.king type=A
add address=172.16.101.2 name=helmsdeep.king type=A
add address=172.16.102.2 name=helmsdeep.king type=A
add address=172.16.103.2 name=helmsdeep.king type=A
add address=172.16.103.3 name=minasmorgul.king type=A

/ip firewall filter
add action=accept chain=input comment="accept established,related,untracked" \
    connection-state=established,related,untracked
add action=drop chain=input comment="drop invalid" connection-state=invalid
add action=accept chain=input comment="accept ICMP" protocol=icmp
add action=accept chain=input comment="Allow admin access" dst-port=8291 \
    in-interface-list=MGMT protocol=tcp
add action=accept chain=input comment="Allow DNS" dst-port=53 \
    in-interface-list=LAN protocol=tcp
add action=accept chain=input dst-port=53 in-interface-list=LAN protocol=udp
add action=drop chain=input comment="DROP ALL ELSE"
add action=fasttrack-connection chain=forward comment=fasttrack \
    connection-state=established,related disabled=yes
add action=accept chain=forward comment=\
    "accept established,related, untracked" connection-state=\
    established,related,untracked
add action=drop chain=forward comment="Drop DNS" dst-port=53 protocol=tcp \
    src-address-list=""
add action=drop chain=forward dst-port=53 protocol=udp src-address-list=""
add action=drop chain=forward comment="Block TRUST <-> noTrust" \
    in-interface-list=MGMT out-interface-list=noTrust
add action=drop chain=forward in-interface-list=noTrust out-interface-list=\
    MGMT
add action=accept chain=forward comment="Allow internet traffic" \
    in-interface-list=LAN out-interface-list=WAN
add action=drop chain=forward comment="drop invalid" connection-state=invalid
add action=drop chain=forward comment="drop all from WAN not DSTNATed" \
    connection-nat-state=!dstnat in-interface-list=WAN

/ip firewall mangle
add action=mark-packet chain=postrouting comment="DOWNLOAD (other)" \
    new-packet-mark=download_packet_oth out-interface=OTHER
add action=mark-packet chain=prerouting comment="UPLOAD (other)" \
    in-interface=OTHER new-packet-mark=upload_packet_oth
add action=mark-packet chain=prerouting comment=DOWNLOAD in-interface-list=\
    WAN new-packet-mark=download_packet
add action=mark-packet chain=postrouting comment=UPLOAD new-packet-mark=\
    upload_packet out-interface-list=WAN

/ip firewall nat
add action=masquerade chain=srcnat comment="defconf: masquerade" \
    ipsec-policy=out,none out-interface-list=WAN
add action=redirect chain=dstnat comment="DNS redirect" dst-port=53 protocol=\
    tcp
add action=redirect chain=dstnat dst-port=53 protocol=udp

/ipv6 firewall address-list
add address=::/128 comment="defconf: unspecified address" list=bad_ipv6
add address=::1/128 comment="defconf: lo" list=bad_ipv6
add address=fec0::/10 comment="defconf: site-local" list=bad_ipv6
add address=::ffff:0.0.0.0/96 comment="defconf: ipv4-mapped" list=bad_ipv6
add address=::/96 comment="defconf: ipv4 compat" list=bad_ipv6
add address=100::/64 comment="defconf: discard only " list=bad_ipv6
add address=2001:db8::/32 comment="defconf: documentation" list=bad_ipv6
add address=2001:10::/28 comment="defconf: ORCHID" list=bad_ipv6
add address=3ffe::/16 comment="defconf: 6bone" list=bad_ipv6

/ipv6 firewall filter
add action=accept chain=input comment=\
    "defconf: accept established,related,untracked" connection-state=\
    established,related,untracked
add action=drop chain=input comment="defconf: drop invalid" connection-state=\
    invalid
add action=accept chain=input comment="defconf: accept ICMPv6" protocol=\
    icmpv6
add action=accept chain=input comment="defconf: accept UDP traceroute" \
    dst-port=33434-33534 protocol=udp
add action=accept chain=input comment=\
    "defconf: accept DHCPv6-Client prefix delegation." dst-port=546 protocol=\
    udp src-address=fe80::/10
add action=accept chain=input comment="defconf: accept IKE" dst-port=500,4500 \
    protocol=udp
add action=accept chain=input comment="defconf: accept ipsec AH" protocol=\
    ipsec-ah
add action=accept chain=input comment="defconf: accept ipsec ESP" protocol=\
    ipsec-esp
add action=accept chain=input comment=\
    "defconf: accept all that matches ipsec policy" ipsec-policy=in,ipsec
add action=drop chain=input comment=\
    "defconf: drop everything else not coming from LAN" in-interface-list=\
    !LAN
add action=fasttrack-connection chain=forward comment="defconf: fasttrack6" \
    connection-state=established,related
add action=accept chain=forward comment=\
    "defconf: accept established,related,untracked" connection-state=\
    established,related,untracked
add action=drop chain=forward comment="defconf: drop invalid" \
    connection-state=invalid
add action=drop chain=forward comment=\
    "defconf: drop packets with bad src ipv6" src-address-list=bad_ipv6
add action=drop chain=forward comment=\
    "defconf: drop packets with bad dst ipv6" dst-address-list=bad_ipv6
add action=drop chain=forward comment="defconf: rfc4890 drop hop-limit=1" \
    hop-limit=equal:1 protocol=icmpv6
add action=accept chain=forward comment="defconf: accept ICMPv6" protocol=\
    icmpv6
add action=accept chain=forward comment="defconf: accept HIP" protocol=139
add action=accept chain=forward comment="defconf: accept IKE" dst-port=\
    500,4500 protocol=udp
add action=accept chain=forward comment="defconf: accept ipsec AH" protocol=\
    ipsec-ah
add action=accept chain=forward comment="defconf: accept ipsec ESP" protocol=\
    ipsec-esp
add action=accept chain=forward comment=\
    "defconf: accept all that matches ipsec policy" ipsec-policy=in,ipsec
add action=drop chain=forward comment=\
    "defconf: drop everything else not coming from LAN" in-interface-list=\
    !LAN

/system identity
set name=Mordor

/system ntp client
set enabled=yes

/system ntp server
set broadcast=yes use-local-clock=yes

/system ntp client servers
add address=0.it.pool.ntp.org
add address=1.it.pool.ntp.org
add address=2.it.pool.ntp.org
add address=3.it.pool.ntp.org
add address=0.europe.pool.ntp.org
add address=1.europe.pool.ntp.org

/tool mac-server
set allowed-interface-list=MGMT

/tool mac-server mac-winbox
set allowed-interface-list=MGMT
