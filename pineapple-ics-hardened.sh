#!/bin/bash
# Run as root on your Kali laptop
# Full ICS + Pineapple hardening – one-shot script

set -e

echo "=== WiFi Pineapple ICS + Hardening Setup ==="

# 1. Ensure IP forwarding is enabled permanently
echo "net.ipv4.ip_forward=1" | sudo tee /etc/sysctl.d/99-ipforward.conf
sudo sysctl -p /etc/sysctl.d/99-ipforward.conf > /dev/null

# 2. Flush everything clean
sudo iptables -F
sudo iptables -t nat -F
sudo iptables -t filter -X
sudo iptables -P INPUT ACCEPT
sudo iptables -P FORWARD DROP
sudo iptables -P OUTPUT ACCEPT

# 3. INPUT chain – completely isolate Kali host from Pineapple clients
sudo iptables -A INPUT -i lo -j ACCEPT
sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A INPUT -i eth1 -p icmp -j ACCEPT                  # optional ping for debugging
sudo iptables -A INPUT -i eth1 -j DROP                            # BLOCK ALL ELSE from Pineapple → Kali

# 4. FORWARD chain – only allow Pineapple clients → Internet (full client isolation)
sudo iptables -A FORWARD -i eth1 -o eth0 -s 172.16.42.0/24 -m conntrack --ctstate NEW,ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A FORWARD -i eth0 -o eth1 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A FORWARD -o eth0 ! -s 172.16.42.0/24 -j DROP       # anti-spoofing
sudo iptables -A FORWARD -i eth1 -o eth1 -j DROP                  # no client-to-client traffic

# 5. NAT – MASQUERADE all Pineapple traffic out eth0
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

# 6. Save rules so they survive reboot
sudo netfilter-persistent save

# 7. dnsmasq – ultra-locked-down config
sudo systemctl stop dnsmasq 2>/dev/null || true

cat <<EOF | sudo tee /etc/dnsmasq.conf
# Only listen on the Pineapple interface
interface=eth1
bind-interfaces
listen-address=172.16.42.42

# DHCP range
dhcp-range=eth1,172.16.42.50,172.16.42.150,255.255.255.0,1h

# Gateway and DNS for clients
dhcp-option=3,172.16.42.42          # gateway = Kali
dhcp-option=6,8.8.8.8,8.8.4.4        # DNS = Google

# Security hardening
domain-needed
bogus-priv
no-resolv
dhcp-authoritative

# Logging (optional – helps spot rogue clients)
log-dhcp
log-queries
EOF

sudo systemctl restart dnsmasq
sudo systemctl enable dnsmasq

# 8. Make sure eth1 has the correct static IP
sudo ip addr flush dev eth1
sudo ip addr add 172.16.42.42/24 dev eth1
sudo ip link set eth1 up

echo "=== DONE ==="
echo "Pineapple clients will now:"
echo "   • Get IPs 172.16.42.50–150 automatically"
echo "   • Have full Internet access"
echo "   • Be completely unable to reach your Kali box or each other"
echo "   • Be unable to spoof source IPs"
echo ""
echo "Verify with:"
echo "   sudo iptables -L -v -n && sudo iptables -t nat -L -v -n"
echo "   cat /var/lib/misc/dnsmasq.leases"
