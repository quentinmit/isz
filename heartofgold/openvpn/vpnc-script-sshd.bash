# © 2009 David Woodhouse <dwmw2@infradead.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#
################
#
# This is a replacement for the standard vpnc-script used with vpnc and
# openconnect. It sets up VPN routing which doesn't screw over the
# _normal_ routing of the box.
#
# It sets up a new network namespace for the VPN to use, and it runs
# a Secure Shell dæmon inside that namespace, with full access to all
# routes on the VPN.
#
# It links the 'real' network namespace of the computer to this new one
# by an IPv6 site-local connection -- you can ssh into the 'VPN namespace'
# by connecting to the host 'fec0::1'.
#
# You don't need any IPv6 configuration or connectivity for this; you
# only need to have IPv6 support in your kernel. The use of IPv6 is purely
# local to your machine.
#
# This gives you effectively the same service as if your company used a
# SSH "bastion host" for access, instead of a VPN. It's just that the
# bastion host is a special network namespace in your _own_ machine.
#
# Since your connection to it is _private_, though, you can run a few
# services that a secure bastion host could not -- like a web proxy,
# for example.  You can also just forward certain points so that, for
# example, connections to port 25 on your bastion host are automatically
# forwarded inside the VPN to your internal mail server.
#
# It probably helps if you think of the VPN namespace as if it was a
# separate machine. From the network point of view, that's what it is.
# It just happens to share the file system (and a lot of other stuff)
# with your _real_ computer.
#
# You can configure various other services to use this for connections into
# your VPN, as follows...
#
#    SOCKS
#
# SSH has a built-in SOCKS server. If you run 'ssh -D 1080 fec0::1', SSH
# will listen on port 1080 and will forward connections through the SSH
# connection and give you full SOCKS access to the VPN.
#
# It might make sense to make this script automatically start a SSH
# connection with SOCKS enabled, if you want that to be available.
#
#    SSH
#
# The OpenSSH client is capable of connecting to a SSH server by running
# and arbitrary command and using its stdin/stdout, instead of having to
# make a direct TCP connection to the server.
#
# So you can configure it to SSH into the VPN 'namespace' and use the
# 'netcat' command for certain connections. You can add something like
# this to your ~/.ssh/config:
#
#     Host *.example.internal
#          ProxyCommand ssh fec0::1 exec nc %h %p
#
# (This also works if your company has made the mistake of overloading the
#  public 'company.com' domain for internal purposes, instead of doing the
#  sensible thing and using a _separate_ domain.)
#
#    MAIL
#
# Like SSH, most decent mail clients are able to run a command to connect
# to their IMAP server instead of being limited to a direct TCP connection.
#
# Commands you might want to use could look like...
#    ssh $MAILSRV exec /usr/sbin/dovecot --exec-mail imap
#    ssh $MAILSRV exec /usr/sbin/wu-imapd
#    ssh fec0::1 openssl s_client -quiet -connect $MAILSRV:993 -crlf 2>/dev/null
#
# Where '$MAILSRV' is the name of your mail server, of course.
#
# Note that the first two assume that you've set up SSH as described above,
# so that SSH connections to the mail server work transparently. For the
# latter, you probably need to redirect stderr to /dev/null to avoid
# spurious output from openssl configuring your mail client (openssl doesn't
# seem to take the -quiet option very seriously).
#
# For mail clients which _cannot_ simply run an external command for their
# connection, first file a bug and then see the 'PORT FORWARDING' section
# below.
#
#    WEB
#
# Firefox and most other browsers should understand a 'proxy autoconfig'
# file and that can tell it to use SOCKS (see above) for certain domains.
# A suitable PAC file might look like this:
#
# function FindProxyForURL(url, host)
# {
#	if (dnsDomainIs(host, "company.com"))
#                return "SOCKS5 localhost:1080";
#
#	return "DIRECT";
# }
#
#    PORT FORWARDING
#
# You can use SSH to forward certain ports, of course -- but there's another,
# simpler option.
#
# The included example of xinetd configuration will accept connections on
# port 25 and 993 of the host fec0::1, and will automatically forward them
# using netcat to the appropriate hosts within your VPN. This can be extended
# to forward other ports.
#
#    OTHER SERVICES
#
# Most other services should also be available through SSH, through the
# SOCKS proxy, or by port forwarding in some way. If all else fails, you
# can just ssh into the vpn namespace (ssh fec0::1) and have a shell with
# complete access.
#
#    BREAKING OUT OF THE VPN
#
# If you ssh _into_ your machine from the VPN side, you'll get a shell in
# the VPN namespace. To 'break out' from there, you may want to ssh to
# fec0::2 which is the normal machine.
#
#   CONTROLLING ACCESS TO THE VPN
#
# One serious flaw with the _traditional_ VPN setup is that it allows
# _all_ processes and users on the machine to have free access to the
# VPN, instead of only the user who is supposed to have access. The
# approach implemented here allows you to fix that, by running the
# SSHD in the VPN namespace with a separate configuration that allows
# only certain users to connect to it.
#
# (Be aware that using port forwarding or using SSH to run a SOCKS proxy
#  will negate that benefit, of course)
#
# David Woodhouse <dwmw2@infradead.org>
# 2009-06-06

scriptname=$(basename "$0")
netnsname=$scriptname

set -x
set -e

PS4=" \$\$+ "
connect_parent()
{
    export PARENT_NETNS=$$

    $IP link set "$TUNDEV" down
    if ! $IP link set "$TUNDEV" netns $$; then
        echo "Setting network namespace for $TUNDEV failed"
        echo "Perhaps you don't have network namespace support in your kernel?"
        exit 1
    fi

    $IP netns delete "$netnsname" >/dev/null 2>&1 || :

    mkdir -p "/etc/netns/$netnsname/"
    echo "nameserver 127.0.0.1" > "/etc/netns/$netnsname/resolv.conf"

    if ! $IP netns add "$netnsname"; then
        echo "Creating network namespace $netnsname failed"
        echo "Perhaps you don't have network namespace support in your kernel?"
        exit 1
    fi

    localdev=$TUNDEV-vpnssh0
    export remotedev=$TUNDEV-vpnssh1
    $IP link add dev "$localdev" type veth peer name "$remotedev"

    $IP netns exec "$netnsname" "$0" "$@" &
    CHILDPID=$!

    # XXX: If we do this too soon (before the unshare), we're just
    # giving it to our _own_ netns. which achieves nothing.
    # So give it away until we _can't_ give it away any more.
    while $IP link set "$remotedev" netns $CHILDPID 2>/dev/null; do
        sleep 0.1
    done

    # Give away the real VPN tun device too
    $IP link set "$TUNDEV" netns $CHILDPID

    $IP link set "$localdev" up
    $IP addr add fec0::2/64 dev "$localdev"

    echo "VPN now accessible through 'ssh fec0::1'"
    if ! grep -q 127.0.0.1 /etc/resolv.conf; then
        echo "WARNING: Your host needs to be running a local dnsmasq or named"
        echo "WARNING: and /etc/resolv.conf needs to point to 127.0.0.1"
        # XXX: We could probably fix that for ourselves...
    fi
}

connect()
{
    if [ -z "${PARENT_NETNS:-}" ]; then
        connect_parent "$@"
        exit 0
    fi

    # This is the child, which remains running in the background

    # Wait for the tundev to appear in this namespace
    while ! $IP link show "$TUNDEV" >/dev/null 2>&1 ; do
        sleep 0.1
    done

    # Set up Legacy IP in the new namespace
    $IP link set lo up
    $IP link set "$TUNDEV" up
    if [ -n "${INTERNAL_IP4_ADDRESS:-}" ]; then
        $IP -4 addr add "$INTERNAL_IP4_ADDRESS" dev "$TUNDEV"
        if [ "$INTERNAL_IP4_GATEWAY" != "" ]; then
            $IP -4 route add default via "$INTERNAL_IP4_GATEWAY"
        else
            $IP -4 route add default dev "$TUNDEV"
        fi
    fi
    if [ -n "${INTERNAL_IP6_ADDRESS:-}" ]; then
        $IP -6 addr add "$INTERNAL_IP6_ADDRESS" dev "$TUNDEV"
        $IP -6 route add default dev "$TUNDEV"
    fi
    if [ -n "${INTERNAL_IP4_MTU:-}" ]; then
        $IP link set "$TUNDEV" mtu "$INTERNAL_IP4_MTU"
    fi

    # Set up the veth back to the real system
    $IP link set "$remotedev" up
    $IP -6 addr add fec0::1/64 dev "$remotedev" nodad

    nscddir=/run/nscd-$netnsname
    mkdir -p "$nscddir"
    chown nscd "$nscddir"
    $MOUNT --bind "$nscddir" /run/nscd
    $SUDO -u nscd "$NSCD" &
    nscd_pid=$!

    # Run dnsmasq to provide DNS service for this namespace.
    # The host needs to be running its own local nameserver/dnsmasq and
    # /etc/resolv.conf should be pointing to 127.0.0.1 already.
    dnsmasq_args=(--port=53 -k -R -i lo)
    for ns in ${INTERNAL_IP4_DNS:-}; do
        dnsmasq_args+=(-S "$ns")
    done
    for ns in ${INTERNAL_IP6_DNS:-}; do
        dnsmasq_args+=(-S "$ns")
    done
    $DNSMASQ "${dnsmasq_args[@]}" &
    dnsmasq_pid=$!

    # Set up sshd
    $SSHD -D -o AddressFamily=inet6 -o "ListenAddress=[fec0::1]:22" &
    sshd_pid=$!

    # Wait for the veth link to be closed...
    ($IP monitor link dev "$remotedev" | grep --line-buffered Deleted | read -r _) || :

    kill -9 $dnsmasq_pid || :
    kill -TERM $sshd_pid || :
    kill -TERM $nscd_pid || :
    # Wait a while to avoid tun BUG() if we quit and the netns goes away
    # before vpnc/openconnect closes its tun fd.
    sleep 1
}

disconnect()
{
    # Kill our end of the veth link, leaving the child script to clean up
    $IP link del "$TUNDEV"-vpnssh0

    while ! $IP netns delete "$netnsname" >/dev/null 2>&1 ; do
        sleep 0.1
    done
}

case ${reason:?} in
    connect)
        connect "$@"
        ;;

    disconnect)
        disconnect
        ;;
esac
