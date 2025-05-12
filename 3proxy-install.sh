#!/bin/bash
set -e

ARCH=$(dpkg --print-architecture)
cd /tmp
if [[ "$ARCH" == "amd64" ]]; then
    FILE="3proxy-0.9.5.x86_64.deb"
elif [[ "$ARCH" == "arm64" ]]; then
    FILE="3proxy-0.9.5.aarch64.deb"
else
    echo "不支持的架构: $ARCH"
    exit 1
fi

wget -q "https://github.com/3proxy/3proxy/releases/download/0.9.5/$FILE"
dpkg -i "$FILE" || apt-get install -f -y
rm "$FILE"