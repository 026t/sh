#!/bin/bash

timedatectl set-timezone Europe/Moscow

apt install -y chrony

if [ "$(tail -c4 "chrony.conf"; echo x)" != $'end\nx' ]; then
sed -i 's/pool/#pool/' /etc/chrony/chrony.conf
echo "
server ntp0.NL.net iburst
server ntp2.vniiftri.ru iburst
server ntp.ix.ru iburst
server ntps1-1.cs.tu-berlin.de iburst
#allow 192.168.68.0/24
#end" >> /etc/chrony/chrony.conf
fi

systemctl restart chrony
systemctl enable chrony

sed -i 's/#   PasswordAuthentication/    PasswordAuthentication/' /etc/ssh/sshd_config
sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
service ssh restart

echo "#!/usr/sbin/nft -f

flush ruleset                                                                    
                                                                                 
table inet firewall {
                                                                                 
    chain inbound_ipv4 {
        # accepting ping (icmp-echo-request) for diagnostic purposes.
        icmp type echo-request limit rate 5/second accept      
    }

    chain inbound_ipv6 {                                                         
        # accept neighbour discovery otherwise connectivity breaks
        icmpv6 type { nd-neighbor-solicit, nd-router-advert, nd-neighbor-advert } accept
        # accepting ping (icmpv6-echo-request) for diagnostic purposes.
        icmpv6 type echo-request limit rate 5/second accept
    }

    chain inbound {                                                              
        # By default, drop all traffic unless it meets a filter
        # criteria specified by the rules that follow below.
        type filter hook input priority 0; policy drop;

        # Allow traffic from established and related packets, drop invalid
        ct state vmap { established : accept, related : accept, invalid : drop } 

        # Allow loopback traffic.
        iifname lo accept

        # Jump to chain according to layer 3 protocol using a verdict map
        meta protocol vmap { ip : jump inbound_ipv4, ip6 : jump inbound_ipv6 }

        # Allow SSH on port TCP/22 and allow HTTP(S) TCP/80 and TCP/443
        # for IPv4 and IPv6.
        tcp dport 22 ct state new limit rate over 10/minute drop
        tcp dport { 22, 80, 443} accept

        # Enable logging of denied inbound traffic
        log prefix ""[nftables] Inbound Denied: "" counter drop
    }                                                                            
                                                                                 
    chain forward {                                                              
        # Drop everything (assumes this device is not a router)                  
        type filter hook forward priority 0; policy drop;                        
    }                                                                            
                                                                                 
    # no need to define output chain, default policy is accept if undefined.
}" > "/etc/nftables.conf"

systemctl enable nftables
systemctl start nftables
sleep 1 # Waits 1 second
nft -s list ruleset 

wget  https://packagecloud.io/install/repositories/crowdsec/crowdsec/script.deb.sh
chmod ugo+x  script.deb.sh
./script.deb.sh
apt install crowdsec
apt install crowdsec-firewall-bouncer-nftables
cscli console enroll clfi5oe8t0000kv08zw3qy99d
systemctl restart crowdsec.service
cscli collections list

#apt install -y fail2ban
#sed -i 's/banaction = iptables-multiport/banaction = nftables-multiport/' /etc/fail2ban/jail.conf
#sed -i 's/banaction_allports = iptables-allports/banaction_allports = nftables-allports/' /etc/fail2ban/jail.conf
#service fail2ban restart

#Display result
chronyc -N sources
#fail2ban-client status sshd
