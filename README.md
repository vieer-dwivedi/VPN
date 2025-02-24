# VPN Setup in Virtual Machine



wget -qO- https://raw.githubusercontent.com/vieer-dwivedi/VPN/refs/heads/main/VPN_INSTALL.bash | bash -s -- \n
  --install-path=/opt/vpnserver --enable-nat=yes --vpn-hub=HUB --vpn-user=USER --vpn-pass=PASS --vpn-server-ip=IP --vpn-psk=PSK --download-url=URL
