DDNS Cloudflare Bash Script for OpenWrt

This Script is a modified version for OpenWrt with the following changes:
 - The WAN IP is pulled from the wan interface
 - The DDNS Value is taken via cloudflare API instead of nslookup
 - It writes into the System Log

Original Script: [https://github.com/fire1ce/DDNS-Cloudflare-Bash.git](https://github.com/fire1ce/DDNS-Cloudflare-Bash)

Required Packages:

- curl
- bash
