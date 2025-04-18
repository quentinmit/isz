set -x
set -e

die() {
    echo "$@" >&2
    exit 1
}

declare containerName dev ifconfig_local

[ -n "$containerName" ] || die "Missing \$containerName"

leader=$(machinectl show "$containerName" -p Leader --value)

[ -n "$leader" ] || die "Unable to determine leader PID"

opt_lines() {
  for var in ''${!foreign_option_*}; do
    # shellcheck disable=SC2086
    set -- ''${!var}
    if [ "$1" = "dhcp-option" ]; then
    case $2 in
      DNS)
      echo "DNS=$3"
      ;;
    esac
    fi
  done
}

# Gateway=${ifconfig_remote}

systemd-run --machine="$containerName" --pipe /bin/sh -c "PATH=/run/current-system/sw/bin; mkdir -p /run/systemd/network && cat > /run/systemd/network/tun.network && networkctl reload" <<EOF
[Match]
Name=tun*
[Network]
Address=${ifconfig_local}/32
DefaultRouteOnDevice=true
$(opt_lines)
EOF

# Give away the VPN tun device
while $IP link set "$dev" netns "$leader" 2>/dev/null; do
    sleep 0.1
done
