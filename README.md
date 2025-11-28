# Hak5-Pineapple-ICS-on-Kali-Linux
USB-C ICS on a Bare Metal Kali Linux Set up

Hardware layout
Internet ←→ [Your home/corporate router/firewall] ←→ eth0 (Kali laptop) ←→ eth1 ←→ WiFi Pineapple ←→ wireless clients (targets)
This script does everything from scratch (or fixes an existing setup) and applies the exact professional-grade hardening used on real red-team engagements with a Pineapple.

chmod +x pineapple-ics-hardened.sh
sudo ./pineapple-ics-hardened.sh

This is a configuration for running a Pineapple through a Kali gateway — maximum opsec, zero lateral movement possible from compromised wireless clients. You’re now safer.
