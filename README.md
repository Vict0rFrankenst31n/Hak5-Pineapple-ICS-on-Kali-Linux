# Hak5 WiFi Pineapple → Kali Linux ICS (Hardened)

A secured Internet Connection Sharing (ICS) configuration for running a **Hak5 WiFi Pineapple** through a **bare-metal Kali Linux** system, with full client isolation and hardening.

---

## 🔧 Hardware Layout

Internet ←→ [Router/Firewall] ←→ eth0 (Kali Laptop) ←→ eth1 ←→ WiFi Pineapple ←→ Wireless Clients (Targets)


---

## ❓ Why This Setup?

- Provides real Internet access to Pineapple clients (required for modules, payloads, and implants).
- Ensures **zero lateral movement**—clients cannot access:
  - your Kali host
  - other clients
  - or spoof IPs
- Fully persistent (survives reboots).
- Two script versions: **one-shot** and **modular**.

---

## ⭐ Features (Both Scripts)

- Permanent IP forwarding  
- Full client isolation  
- Anti-spoofing egress filtering  
- NAT masquerading  
- Hardened **dnsmasq** (binds only to Pineapple interface)  
- Persistent firewall rules via `netfilter-persistent`  
- Clean, repeatable configuration—safe to re-run  

---

# 📜 Scripts

## 1. One-Shot Script — `pineapple-ics-hardened.sh`

Simple, fast, and ready to deploy.

```bash
wget https://raw.githubusercontent.com/Vict0rFrankenst31n/Hak5-Pineapple-ICS-on-Kali-Linux/refs/heads/main/pineapple-ics-hardened.sh
```
```bash
chmod +x pineapple-ics-hardened.sh
```
```bash
sudo ./pineapple-ics-hardened.sh
```
## 2. Modular Edition — modular-edition-pineapple-ics.sh

Clean, configurable, and reusable. Safe to source in other tools.

Install once:

```bash
wget https://raw.githubusercontent.com/Vict0rFrankenst31n/Hak5-Pineapple-ICS-on-Kali-Linux/refs/heads/main/modular-edition-pineapple-ics.sh
```
```bash
sudo chmod +x ./modular-edition-pineapple.sh
```

Run anytime:
```bash
sudo modular-edition-pineapple-ics.sh
```

Import individual functions:
```bash
source /your/local/directory/modular-edition-pineapple-ics.sh
```
```bash
setup_forward_chain   # example function
```
Fully configurable at the top of the script (interfaces, IP ranges, DNS, etc.).

## 🔍 Verification

After running either script:

Check firewall rules:
```bash
sudo iptables -L -v -n
```
```bash
sudo iptables -t nat -L -v -n
```
Show connected clients:
```bash
cat /var/lib/misc/dnsmasq.leases
```

Live DHCP/DNS logs:
```bash
journalctl -u dnsmasq -f
```
or:
```bash
tail -f /var/log/syslog | grep dnsmasq
```

## 🛠️ Customization (Modular Version)

Edit these variables at the top of the script:
```bash
IF_LAN="eth1"                  # Interface connected to Pineapple
IF_WAN="eth0"                  # Interface to Internet
LAN_IP="172.16.42.42/24"
DHCP_START="172.16.42.50"
DHCP_END="172.16.42.150"
DNS_SERVERS="8.8.8.8,1.1.1.1"
```

## 🔐 Security Notes

Kali host is completely unreachable from Pineapple clients

No client-to-client communication

dnsmasq bound only to the Pineapple interface

Anti-spoofing prevents clients from impersonating other networks

## 🧹 Uninstallation / Teardown
```bash
sudo systemctl disable --now dnsmasq
sudo rm -f /etc/dnsmasq.conf /usr/local/bin/pineapple-ics.sh
sudo apt purge -y dnsmasq netfilter-persistent iptables-persistent
sudo rm -f /etc/sysctl.d/99-ipforward.conf
sudo sysctl -w net.ipv4.ip_forward=0
sudo iptables -F && sudo iptables -t nat -F
sudo iptables -P FORWARD ACCEPT
```
## Happy hunting. Stay ethical.

