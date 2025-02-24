# VPN Setup in Virtual Machine



wget -qO- https://tinyurl.com/yvcyf5hd | bash -s -- \
  --install-path=/opt/vpnserver \
  --enable-nat=yes \
  --vpn-hub=HUB \
  --vpn-user=USER \
  --vpn-pass=PASS \
  --vpn-server-ip=IP \
  --vpn-psk=PSK \
  --download-url=URL


```bash
#!/bin/bash
sudo apt update && sudo apt install -y wget
wget -qO- https://tinyurl.com/yvcyf5hd | bash -s -- \
    --vpn-user="USER" \
    --vpn-pass="PASS"
```
