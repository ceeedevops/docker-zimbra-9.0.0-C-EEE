#!/bin/bash

set -e

ZIMBRA_ENVIRONMENT_PATH="/data"

function prepare_chroot
{
    mount -o bind /dev $ZIMBRA_ENVIRONMENT_PATH/dev
    mount -o bind /dev/pts $ZIMBRA_ENVIRONMENT_PATH/dev/pts
    mount -t sysfs /sys $ZIMBRA_ENVIRONMENT_PATH/sys
    mount -t proc /proc $ZIMBRA_ENVIRONMENT_PATH/proc
    cp /proc/mounts $ZIMBRA_ENVIRONMENT_PATH/etc/mtab
    cp /etc/hosts $ZIMBRA_ENVIRONMENT_PATH/etc
    mount -o bind /etc/hosts $ZIMBRA_ENVIRONMENT_PATH/etc/hosts
    mount -o bind /etc/hostname $ZIMBRA_ENVIRONMENT_PATH/etc/hostname
    mount -o bind /etc/resolv.conf $ZIMBRA_ENVIRONMENT_PATH/etc/resolv.conf
    cp /app/control-zimbra.sh $ZIMBRA_ENVIRONMENT_PATH/app/
    chmod 750 $ZIMBRA_ENVIRONMENT_PATH/app/control-zimbra.sh
}

function shutdown_chroot
{
    umount $ZIMBRA_ENVIRONMENT_PATH/etc/resolv.conf
    umount $ZIMBRA_ENVIRONMENT_PATH/etc/hostname
    umount $ZIMBRA_ENVIRONMENT_PATH/etc/hosts
    umount $ZIMBRA_ENVIRONMENT_PATH/proc
    umount $ZIMBRA_ENVIRONMENT_PATH/sys
    umount $ZIMBRA_ENVIRONMENT_PATH/dev/pts
    umount $ZIMBRA_ENVIRONMENT_PATH/dev
}

function setup_environment
{
    if [ -z "$(ls -A $ZIMBRA_ENVIRONMENT_PATH)" ]; then

        echo "Installing minimalistic Ubuntu 16.04 LTS (Xenial)..."
        debootstrap --variant=minbase --arch=amd64 xenial /data http://archive.ubuntu.com/ubuntu/

        echo "Installing Zimbra..."
        mkdir -p $ZIMBRA_ENVIRONMENT_PATH/app
        cp /app/install-zimbra.sh $ZIMBRA_ENVIRONMENT_PATH/app/
        cp /app/update-letsencrypt.sh $ZIMBRA_ENVIRONMENT_PATH/app/
        chmod 750 $ZIMBRA_ENVIRONMENT_PATH/app/install-zimbra.sh
        chmod 750 $ZIMBRA_ENVIRONMENT_PATH/app/update-letsencrypt.sh
        prepare_chroot
        chroot $ZIMBRA_ENVIRONMENT_PATH /app/install-zimbra.sh # starts services at the end...
        chroot $ZIMBRA_ENVIRONMENT_PATH /app/update-letsencrypt.sh
        chroot $ZIMBRA_ENVIRONMENT_PATH /app/control-zimbra.sh stop
        shutdown_chroot

    fi
}


# Allowed ports (FIREWALL_ALLOW_PORTS_IN)
# -----------------------------------------------------------------------------
# 25/tcp   - SMTP (for incoming mail)
# 80/tcp   - HTTP (for web mail clients)
# 110/tcp  - POP3 (for mail clients)
# 143/tcp  - IMAP (for mail clients)
# 443/tcp  - HTTP over TLS (for web mail clients)
# 465/tcp  - SMTP over SSL (for mail clients)
# 587/tcp  - SMTP (submission, for mail clients)
# 993/tcp  - IMAP over TLS (for mail clients)
# 995/tcp  - POP3 over TLS (for mail clients)
# 5222/tcp - XMPP
# 5223/tcp - XMPP (default legacy port)
# 7071/tcp - HTTPS (admin panel, https://<host>/zimbraAdmin)
# -----------------------------------------------------------------------------
FIREWALL_ALLOW_UDP_PORTS_IN=${FIREWALL_ALLOW_UDP_PORTS_IN:-}
FIREWALL_ALLOW_TCP_PORTS_IN=${FIREWALL_ALLOW_TCP_PORTS_IN:-25,80,110,143,443,465,587,993,995,5222,5223,7071}

function configure_firewall
{
    # allow packets from loopback interface
    iptables  -A INPUT -i lo -j ACCEPT
    ip6tables -A INPUT -i lo -j ACCEPT

    # filter all packets that have RH0 headers (deprecated, can be used for DoS attacks)
    ip6tables -t raw    -A PREROUTING  -m rt --rt-type 0 -j DROP
    ip6tables -t mangle -A POSTROUTING -m rt --rt-type 0 -j DROP

    # prevent attacker from using the loopback address as source address
    iptables  -t raw -A PREROUTING ! -i lo -s 127.0.0.0/8 -j DROP
    ip6tables -t raw -A PREROUTING ! -i lo -s ::1/128     -j DROP

    # block TCP packets with bogus flags
    iptables  -t raw -A PREROUTING -p tcp --tcp-flags ACK,FIN FIN                 -j DROP
    iptables  -t raw -A PREROUTING -p tcp --tcp-flags ACK,PSH PSH                 -j DROP
    iptables  -t raw -A PREROUTING -p tcp --tcp-flags ACK,URG URG                 -j DROP
    iptables  -t raw -A PREROUTING -p tcp --tcp-flags FIN,RST FIN,RST             -j DROP
    iptables  -t raw -A PREROUTING -p tcp --tcp-flags SYN,FIN SYN,FIN             -j DROP
    iptables  -t raw -A PREROUTING -p tcp --tcp-flags SYN,RST SYN,RST             -j DROP
    iptables  -t raw -A PREROUTING -p tcp --tcp-flags ALL     ALL                 -j DROP
    iptables  -t raw -A PREROUTING -p tcp --tcp-flags ALL     NONE                -j DROP
    iptables  -t raw -A PREROUTING -p tcp --tcp-flags ALL     FIN,PSH,URG         -j DROP
    iptables  -t raw -A PREROUTING -p tcp --tcp-flags ALL     SYN,FIN,PSH,URG     -j DROP
    iptables  -t raw -A PREROUTING -p tcp --tcp-flags ALL     SYN,RST,ACK,FIN,URG -j DROP
    ip6tables -t raw -A PREROUTING -p tcp --tcp-flags ACK,FIN FIN                 -j DROP
    ip6tables -t raw -A PREROUTING -p tcp --tcp-flags ACK,PSH PSH                 -j DROP
    ip6tables -t raw -A PREROUTING -p tcp --tcp-flags ACK,URG URG                 -j DROP
    ip6tables -t raw -A PREROUTING -p tcp --tcp-flags FIN,RST FIN,RST             -j DROP
    ip6tables -t raw -A PREROUTING -p tcp --tcp-flags SYN,FIN SYN,FIN             -j DROP
    ip6tables -t raw -A PREROUTING -p tcp --tcp-flags SYN,RST SYN,RST             -j DROP
    ip6tables -t raw -A PREROUTING -p tcp --tcp-flags ALL     ALL                 -j DROP
    ip6tables -t raw -A PREROUTING -p tcp --tcp-flags ALL     NONE                -j DROP
    ip6tables -t raw -A PREROUTING -p tcp --tcp-flags ALL     FIN,PSH,URG         -j DROP
    ip6tables -t raw -A PREROUTING -p tcp --tcp-flags ALL     SYN,FIN,PSH,URG     -j DROP
    ip6tables -t raw -A PREROUTING -p tcp --tcp-flags ALL     SYN,RST,ACK,FIN,URG -j DROP

    # block all packets that have an invalid connection state
    # (mitigates all TCP flood attacks, except SYN floods)
    iptables  -t mangle -A PREROUTING -m conntrack --ctstate INVALID -j DROP
    ip6tables -t mangle -A PREROUTING -m conntrack --ctstate INVALID -j DROP

    # block all packets that are new, but not SYN packets
    iptables  -t mangle -A PREROUTING -p tcp ! --syn -m conntrack --ctstate NEW -j DROP
    ip6tables -t mangle -A PREROUTING -p tcp ! --syn -m conntrack --ctstate NEW -j DROP

    # allow packets that belong to established connections
    iptables  -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    ip6tables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

    # allow access to public services (tcp)
    while IFS=',' read -ra PORTS; do
        for port in "${PORTS[@]}"; do
#             echo "Allowing tcp port $port"
             iptables -A INPUT -p tcp --dport $port -j ACCEPT
             ip6tables -A INPUT -p tcp --dport $port -j ACCEPT
        done
    done <<< "$FIREWALL_ALLOW_TCP_PORTS_IN"

    # allow access to public services (udp)
    while IFS=',' read -ra PORTS; do
        for port in "${PORTS[@]}"; do
#             echo "Allowing udp port $port"
             iptables -A INPUT -p udp --dport $port -j ACCEPT
             ip6tables -A INPUT -p udp --dport $port -j ACCEPT
        done
    done <<< "$FIREWALL_ALLOW_UDP_PORTS_IN"

    # allow necessary ICMPv4 packets

    # ICMP Type | INPUT | Description
    # -----------------------------------------------------------------------------------------
    #       0   |  yes  |   echo reply
    #       3   |  yes  |   destination unreachable
    #       8   |  yes  |   echo request (protect against ping-of-death)
    #      11   |  yes  |   time exceeded
    #      12   |  yes  |   parameter problem
    # -----------------------------------------------------------------------------------------
    iptables -N AllowICMP
    iptables -A AllowICMP -p icmp --icmp-type 0  -j ACCEPT
    iptables -A AllowICMP -p icmp --icmp-type 3  -j ACCEPT
    iptables -A AllowICMP -p icmp --icmp-type 8  -j ACCEPT -m limit --limit 5/sec --limit-burst 10
    iptables -A AllowICMP -p icmp --icmp-type 11 -j ACCEPT
    iptables -A AllowICMP -p icmp --icmp-type 12 -j ACCEPT
    iptables -A AllowICMP -j DROP
    iptables -A INPUT -p icmp -j AllowICMP

    # allow necessary ICMPv6 packets

    #  ICMPv6 Type | INPUT | Description
    # -----------------------------------------------------------------------------------------
    #         1    |  yes  |   destination unreachable
    #         2    |  yes  |   packet too big
    #         3    |  yes  |   time exceeded
    #         4    |  yes  |   parameter problem
    #       128    |  yes  |   echo request (protect against ping-of-death)
    #       129    |  yes  |   echo reply
    #       130    |  yes  |   multicast listener query
    #       131    |  yes  |   version 1 multicast listener report
    #       132    |  yes  |   multicast listener done
    #       133    |  yes  |   router solicitation
    #       134    |  yes  |   router advertisement
    #       135    |  yes  |   neighbor solicitation
    #       136    |  yes  |   neighbor advertisement
    #       151    |  yes  |   multicast router advertisement
    #       152    |  yes  |   multicast router solicitation
    #       153    |  yes  |   multicast router termination
    # -----------------------------------------------------------------------------------------
    ip6tables -N AllowICMP
    ip6tables -A AllowICMP -p icmpv6 --icmpv6-type 1   -j ACCEPT
    ip6tables -A AllowICMP -p icmpv6 --icmpv6-type 2   -j ACCEPT
    ip6tables -A AllowICMP -p icmpv6 --icmpv6-type 3   -j ACCEPT
    ip6tables -A AllowICMP -p icmpv6 --icmpv6-type 4   -j ACCEPT
    ip6tables -A AllowICMP -p icmpv6 --icmpv6-type 128 -j ACCEPT -m limit --limit 5/sec --limit-burst 10
    ip6tables -A AllowICMP -p icmpv6 --icmpv6-type 129 -j ACCEPT
    ip6tables -A AllowICMP -p icmpv6 --icmpv6-type 130 -j ACCEPT
    ip6tables -A AllowICMP -p icmpv6 --icmpv6-type 131 -j ACCEPT
    ip6tables -A AllowICMP -p icmpv6 --icmpv6-type 132 -j ACCEPT
    ip6tables -A AllowICMP -p icmpv6 --icmpv6-type 133 -j ACCEPT
    ip6tables -A AllowICMP -p icmpv6 --icmpv6-type 134 -j ACCEPT
    ip6tables -A AllowICMP -p icmpv6 --icmpv6-type 135 -j ACCEPT
    ip6tables -A AllowICMP -p icmpv6 --icmpv6-type 136 -j ACCEPT
    ip6tables -A AllowICMP -p icmpv6 --icmpv6-type 151 -j ACCEPT
    ip6tables -A AllowICMP -p icmpv6 --icmpv6-type 152 -j ACCEPT
    ip6tables -A AllowICMP -p icmpv6 --icmpv6-type 153 -j ACCEPT
    ip6tables -A AllowICMP -j DROP
    ip6tables -A INPUT -p icmpv6 -j AllowICMP

    # drop everything else
    iptables -A INPUT -j DROP
    ip6tables -A INPUT -j DROP
}


function setup_signals
{
  cid="$1"; shift
  handler="$1"; shift
  for sig; do
    trap "$handler '$cid' '$sig'" "$sig"
  done
}

# initially the zimbra is not running...
running=0

function handle_signal
{
  # echo "Received signal: $2"
  case "$2" in
    SIGINT|SIGTERM)
      # echo "Shutting down Zimbra..."
      chroot $ZIMBRA_ENVIRONMENT_PATH /app/control-zimbra.sh stop
      running=0
      ;;
    SIGHUP)
      # echo "Reloading Zimbra configuration..."
      chroot $ZIMBRA_ENVIRONMENT_PATH /app/control-zimbra.sh reload
      ;;
  esac
}

setup_signals "$1" "handle_signal" SIGINT SIGTERM SIGHUP


# install Ubuntu + Zimbra into /data (if /data is empty)
setup_environment "$@"
if [ $? -ne 0 ]; then exit $?; fi


# prepare the chroot environment and configure the firewall
if [ "$$" = "1" ]; then
    prepare_chroot
    configure_firewall
fi


if [ "$1" = 'run' ]; then

    # start Zimbra processes
    running=1
    chroot $ZIMBRA_ENVIRONMENT_PATH /app/control-zimbra.sh start

    # wait for signals
    # echo "Waiting for signals..."
    while [ $running -ne 0 ]; do
        tail -f /dev/null & wait ${!}
    done
    # echo "Stopped waiting for signals..."

elif [ "$1" = 'run-and-enter' ]; then

    # start Zimbra processes and a shell
    running=1
    chroot $ZIMBRA_ENVIRONMENT_PATH /app/control-zimbra.sh start
    /bin/bash -c "/bin/bash && kill $$" 0<&0 1>&1 2>&2 &

    # wait for signals
    # echo "Waiting for signals..."
    while [ $running -ne 0 ]; do
        tail -f /dev/null & wait ${!}
    done
    # echo "Stopped waiting for signals..."

elif [ "$1" = 'run-and-enter-zimbra' ]; then

    # start Zimbra processes and a shell
    running=1
    chroot $ZIMBRA_ENVIRONMENT_PATH /app/control-zimbra.sh start
    chroot $ZIMBRA_ENVIRONMENT_PATH /bin/bash -c "/bin/bash && kill $$" 0<&0 1>&1 2>&2 &

    # wait for signals
    # echo "Waiting for signals..."
    while [ $running -ne 0 ]; do
        tail -f /dev/null & wait ${!}
    done
    # echo "Stopped waiting for signals..."

elif [ $# -gt 0 ]; then

    # parameters were specified
    # => interpret parameters as regular command
    chroot $ZIMBRA_ENVIRONMENT_PATH "$@"

fi


# shut chroot down
if [ "$$" = "1" ]; then
    shutdown_chroot
fi
