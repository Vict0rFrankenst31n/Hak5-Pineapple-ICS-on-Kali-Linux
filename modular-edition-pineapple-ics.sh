#!/usr/bin/env bash
# =============================================================================
# WiFi Pineapple → Kali ICS (Hardened) - Modular Edition
# Author: Vict0rFrankenst31n with help from Grok
# Tested on Kali 2024–2025
# =============================================================================

set -euo pipefail
IFS=$'\n\t'

# ----------------------------- CONFIGURATION ---------------------------------
IF_LAN="eth1"                  # Interface connected to Pineapple
IF_WAN="eth0"                  # Interface connected to real router/Internet
LAN_IP="172.16.42.42/24"       # Kali IP on the Pineapple side
DHCP_START="172.16.42.50"
DHCP_END="172.16.42.150"
DHCP_NETMASK="255.255.255.0"
DHCP_LEASE="1h"
DNS_SERVERS="8.8.8.8,8.8.4.4"
# -----------------------------------------------------------------------------

log()    { echo -e "\033[1;34m[+]\033[0m $*"; }
warn()   { echo -e "\033[1;33m[!]\033[0m $*"; }
error()  { echo -e "\033[1;31m[-]\033[0m $*"; exit 1; }

check_root() {
    [[ $EUID -eq 0 ]] || error "This script must be run as root (sudo)."
}

check_interfaces() {
    ip link show "$IF_WAN" &>/dev/null || error "WAN interface $IF_WAN not found!"
    ip link show "$IF_LAN" &>/dev/null || error "LAN interface $IF_LAN not found!"
}

enable_ip_forward() {
    log "Enabling IP forwarding permanently..."
    echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/99-ipforward.conf
    sysctl -p /etc/sysctl.d/99-ipforward.conf >/dev/null
}

flush_iptables() {
    log "Flushing existing iptables rules..."
    iptables -F
    iptables -t nat -F
    iptables -t filter -X
    iptables -P INPUT ACCEPT
    iptables -P FORWARD DROP
    iptables -P OUTPUT ACCEPT
}

setup_input_chain() {
    log "Locking down INPUT chain (block Pineapple → Kali)..."
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    iptables -A INPUT -i "$IF_LAN" -p icmp -j ACCEPT          # optional ping
    iptables -A INPUT -i "$IF_LAN" -j DROP
}

setup_forward_chain() {
    log "Setting up FORWARD chain (Internet only, full client isolation)..."
    iptables -A FORWARD -i "$IF_LAN" -o "$IF_WAN" -s 172.16.42.0/24 \
        -m conntrack --ctstate NEW,ESTABLISHED,RELATED -j ACCEPT
    iptables -A FORWARD -i "$IF_WAN" -o "$IF_LAN" \
        -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

    # Anti-spoofing + block client-to-client
    iptables -A FORWARD -o "$IF_WAN" ! -s 172.16.42.0/24 -j DROP
    iptables -A FORWARD -i "$IF_LAN" -o "$IF_LAN" -j DROP
}

setup_nat() {
    log "Enabling MASQUERADE NAT..."
    iptables -t nat -A POSTROUTING -o "$IF_WAN" -j MASQUERADE
}

save_rules() {
    log "Saving rules with netfilter-persistent..."
    netfilter-persistent save >/dev/null 2>&1 || {
        warn "netfilter-persistent not installed → installing..."
        apt update -qq && apt install -y netfilter-persistent iptables-persistent
        netfilter-persistent save
    }
}

configure_interface() {
    log "Configuring $IF_LAN with static IP $LAN_IP..."
    ip addr flush dev "$IF_LAN" 2>/dev/null || true
    ip addr add "$LAN_IP" dev "$IF_LAN"
    ip link set "$IF_LAN" up
}

configure_dnsmasq() {
    log "Configuring locked-down dnsmasq..."
    systemctl stop dnsmasq 2>/dev/null || true

    cat > /etc/dnsmasq.conf <<EOF
# Hardened Pineapple config
interface=$IF_LAN
bind-interfaces
listen-address=${LAN_IP%/*}

dhcp-range=eth1,$DHCP_START,$DHCP_END,$DHCP_NETMASK,$DHCP_LEASE
dhcp-option=3,${LAN_IP%/*}
dhcp-option=6,$DNS_SERVERS

# Security
domain-needed
bogus-priv
no-resolv
dhcp-authoritative

# Logging
log-dhcp
log-queries
EOF

    systemctl restart dnsmasq
    systemctl enable dnsmasq
    log "dnsmasq is running and bound only to $IF_LAN"
}

show_status() {
    log "Setup complete! Current status:"
    echo "   • IP forwarding : $(sysctl -n net.ipv4.ip_forward)"
    echo "   • $IF_LAN IP     : $(ip -br addr show "$IF_LAN" | awk '{print $3}')"
    echo "   • Active clients: $(wc -l < /var/lib/misc/dnsmasq.leases 2>/dev/null || echo 0)"
    echo
    echo "Useful commands:"
    echo "   tail -f /var/log/syslog | grep dnsmasq      # live DHCP/DNS log"
    echo "   cat /var/lib/misc/dnsmasq.leases            # current clients"
    echo "   iptables -L -v -n ; iptables -t nat -L -v -n"
}

# ------------------------------- MAIN ----------------------------------------
main() {
    check_root
    check_interfaces

    echo -e "\033[1;36m=== Hardened WiFi Pineapple ICS Setup ===\033[0m"
    echo "LAN → $IF_LAN (Pineapple) | WAN → $IF_WAN (Internet)"
    echo

    enable_ip_forward
    flush_iptables
    setup_input_chain
    setup_forward_chain
    setup_nat
    save_rules
    configure_interface
    configure_dnsmasq
    show_status

    echo -e "\033[1;32mAll done. Your Pineapple network is fully isolated and hardened.\033[0m"
}

# Allow sourcing (for testing) or direct execution
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "$@"
