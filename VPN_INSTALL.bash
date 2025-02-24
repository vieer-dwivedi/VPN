#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
LOG_FILE="/var/log/vpn_setup.log"
exec > >(sudo tee -a "$LOG_FILE") 2>&1
helpFunction() {
    echo "Usage: $0 --install-path=/opt/vpnserver --enable-nat=yes --vpn-hub=HUB --vpn-user=USER --vpn-pass=PASS --vpn-server-ip=IP --vpn-psk=PSK --download-url=URL"
    exit 1
}

INSTALL_PATH="/opt/vpnserver"
ENABLE_NAT=""
VPN_HUB=""
VPN_USER=""
VPN_PASS=""
VPN_SERVER_IP=""
VPN_PSK=""
DOWNLOAD_URL=""

ARGS=$(getopt -o "" \
    --long install-path:,enable-nat:,vpn-hub:,vpn-user:,vpn-pass:,vpn-server-ip:,vpn-psk:,download-url: \
    -- "$@")

if [ $? -ne 0 ]; then
    helpFunction
fi

eval set -- "$ARGS"

while true; do
    case "$1" in
        --install-path) INSTALL_PATH="$2"; shift 2 ;;
        --enable-nat) ENABLE_NAT="$2"; shift 2 ;;
        --vpn-hub) VPN_HUB="$2"; shift 2 ;;
        --vpn-user) VPN_USER="$2"; shift 2 ;;
        --vpn-pass) VPN_PASS="$2"; shift 2 ;;
        --vpn-server-ip) VPN_SERVER_IP="$2"; shift 2 ;;
        --vpn-psk) VPN_PSK="$2"; shift 2 ;;
        --download-url) DOWNLOAD_URL="$2"; shift 2 ;;
        --) shift; break ;;
        *) helpFunction ;;
    esac
done

main() {
    dependencies
    install
    create_user
}

allowed_ports=("443/tcp" "992/tcp" "1194/udp" "5555/tcp" "22/tcp" "500/udp" "4500/udp" "1701/udp" "8080/tcp")

dependencies() {
    sudo bash -c """
    apt-get update >> /dev/null && echo 'System updated'
    apt-get install -y build-essential libreadline-dev libssl-dev zlib1g-dev wget ufw >> /dev/null && echo 'Dependencies installed'
    """ || { echo "Failed to install dependencies"; exit 1; }
}

setup_ufw(){
    for port in "${allowed_ports[@]}"; do
        sudo ufw allow "$port" >> /dev/null && echo "$port allowed" || echo "$port not allowed"
    done
    sudo bash -c """
    yes | ufw enable >> /dev/null && echo 'Firewall enabled'
    ufw reload >> /dev/null && echo 'Firewall reloaded'
    """
}

install() { 
    sudo mkdir -p "$INSTALL_PATH" && echo "Directory created" || { echo "Directory creation failed"; return 1; }
    cd "$INSTALL_PATH" && echo "Changed directory" || { echo "Directory change failed"; return 1; }
    sudo chmod 777 "$INSTALL_PATH" && echo "Permissions granted" || { echo "Permission change failed"; return 1; }

    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)
            DOWNLOAD_URL=${DOWNLOAD_URL:-"https://www.softether-download.com/files/softether/v4.43-9799-beta-2023.08.31-tree/Linux/SoftEther_VPN_Server/64bit_-_Intel_x64_or_AMD64/softether-vpnserver-v4.43-9799-beta-2023.08.31-linux-x64-64bit.tar.gz"}
            ;;
        *)
            echo "Unsupported architecture: $ARCH"
            echo "Please get download link from https://www.softether-download.com/en.aspx?product=softether for this architecture: $ARCH"
            return 1
            ;;
    esac

    if wget --show-progress -O softether.tar.gz "$DOWNLOAD_URL"; then
        echo "Downloaded file"
    else
        echo "Download failed"
        return 1
    fi

    tar -xvf softether.tar.gz && echo "Extracted file" || { echo "Extraction failed"; return 1; }
    cd vpnserver && echo "Changed directory" || { echo "Directory change failed"; return 1; }
    make && echo "Installation complete" || { echo "Installation failed"; return 1; }

    cat <<EOF | sudo tee /etc/systemd/system/vpnserver.service
[Unit]
Description=SoftEther VPN Server
After=network.target

[Service]
ExecStart=/opt/vpnserver/vpnserver/vpnserver execsvc
WorkingDirectory=/opt/vpnserver/vpnserver
Restart=always
User=root
Group=root
Type=simple

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable vpnserver
    sudo systemctl start vpnserver

    echo "Waiting for vpnserver to start..."
    while ! systemctl is-active --quiet vpnserver; do
        sleep 1
    done
    sleep 5
    echo "vpnserver is now running."
}

create_user(){
    VPN_HUB=${VPN_HUB:-"VPN"}
    VPN_USER=${VPN_USER:-"vpnuser"}
    VPN_PASS=${VPN_PASS:-"vpnpass"}
    ENABLE_NAT=${ENABLE_NAT:-"yes"}
    VPN_PSK=${VPN_PSK:-"YourPreSharedKey"}
    VPN_SERVER_IP=${VPN_SERVER_IP:-$(curl -s http://checkip.amazonaws.com)}
    VPNCMD="/opt/vpnserver/vpnserver/vpncmd"

    $VPNCMD localhost /SERVER:$VPN_SERVER_IP <<EOF
Hub DEFAULT
UserCreate $VPN_USER /GROUP:none /REALNAME:"Test User" /NOTE:"VPN User"
UserPasswordSet $VPN_USER /PASSWORD:$VPN_PASS
$(if [ "$ENABLE_NAT" = "yes" ]; then echo "SecureNatEnable"; fi)
IPsecEnable /L2TP:yes /L2TPRAW:yes /ETHERIP:yes /PSK:$VPN_PSK /DEFAULTHUB:$VPN_HUB
EOF
}

main
