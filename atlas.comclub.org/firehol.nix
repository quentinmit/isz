{ config, pkgs, ... }:
{
  networking.firewall.enable = false;

  environment.systemPackages = [
    pkgs.firehol
  ];
  environment.etc."firehol/firehol.conf".text = ''
    version 6

    server_mosh_ports="udp/60000:61000"
    client_mosh_ports="any"

    server_mdns_ports="udp/5353"
    client_mdns_ports="5353"

    server_ssdp_ports="udp/1900"
    client_ssdp_ports="any"

    HOME_MYIP="192.168.0.254"
    HOME_MYIF="br0"
    HOME_BCAST="192.168.0.255 239.255.255.250 255.255.255.255"
    HOME_LAN="192.168.0.0/16"

    PUBLIC_MYIF="eth0"

    masquerade "''${PUBLIC_MYIF}"

    #connmark 5 OUTPUT proto tcp dport 80 dst 192.168.0.5 user www-data

    ipv4 dnat to 192.168.0.5:80 \
        inface "''${PUBLIC_MYIF}" \
        src not "''${UNROUTABLE_IPS}" \
        proto tcp dport 8081

    ipv4 dnat to 192.168.0.5:1234 \
        inface "''${PUBLIC_MYIF}" \
        src not "''${UNROUTABLE_IPS}" \
        proto tcp dport 1234

    ipv6 interface any v6interop proto icmpv6
        policy return

    interface4 "''${HOME_MYIF}" home src "''${HOME_LAN}" dst "''${HOME_MYIP} ''${HOME_BCAST}"
        policy reject
        server all accept
        client all accept

    interface "''${HOME_MYIF}" dhcpd
        ipv4 server dhcp accept
        server mdns accept
        client mdns accept
        client ssdp accept
        #client http accept user www-data dst 192.168.0.5

    interface "''${PUBLIC_MYIF}" dhcpc src "''${UNROUTABLE_IPS}"
        ipv4 client dhcp accept
        client snmp accept
        server icmp accept
        server http accept
        client http accept
        client ping accept

    interface "''${PUBLIC_MYIF}" internet \
        src not "''${UNROUTABLE_IPS}"

        protection strong
        policy drop

        server "smtp http ssh mosh imaps submission" accept

        client all accept

    interface4 "''${PUBLIC_MYIF}" cablemodem \
        src 192.168.100.1

        policy accept
        server all accept
        client all accept

    router4 pub2lan inface "''${PUBLIC_MYIF}" outface "''${HOME_MYIF}" \
        src not "''${UNROUTABLE_IPS}" dst "''${HOME_LAN}"

        client all accept

        server smtp accept
        server imaps accept
        ipv4 server http accept dst 192.168.0.5

    router lan2lan inface "''${HOME_MYIF}" outface "''${HOME_MYIF}"
        client all accept
        server all accept

    router4 cablemodem2lan inface "''${PUBLIC_MYIF}" outface "''${HOME_MYIF}"    \
        src "192.168.100.1" dst "''${HOME_LAN}"

        client all accept
  '';
}
