# Docker Tiny Proxy

A lightweight Docker proxy service container providing HTTP (Squid) and SOCKS5 (3proxy) proxy functionality with user authentication and Telegram notifications.

[English](README.md) | [中文](README_CN.md)

## Features

- Supports HTTP proxy (Squid) and SOCKS5 proxy (3proxy)
- Automatically generates random usernames and passwords
- Customizable usernames and passwords via environment variables
- Lightweight Alpine Linux base image
- Supports sending proxy information and status notifications via Telegram bot

## Quick Start

### Run with Docker

```bash
docker run -d --name proxy-server \
  -p 3128:3128 \
  -p 1080:1080 \
  tiny-proxy-alpine
```

### Run with Docker Compose

Create a `docker-compose.yml` file:

```yaml
version: '3'
services:
  proxy:
    image: tiny-proxy-alpine
    container_name: proxy-server
    ports:
      - "3128:3128"
      - "1080:1080"
    restart: unless-stopped
```

Then run:

```bash
docker-compose up -d
```

## Environment Variables

Customize proxy configuration using environment variables:

| Environment Variable | Description | Default Value |
|----------|------|--------|
| SQUID_USER | HTTP proxy username | Randomly generated |
| SQUID_PASS | HTTP proxy password | Randomly generated |
| PROXY_USER | SOCKS5 proxy username | Randomly generated |
| PROXY_PASS | SOCKS5 proxy password | Randomly generated |
| TG_TOKEN_REG | Telegram bot token (registration notification) | None |
| TG_CHAT_ID_REG | Telegram chat ID (registration notification) | None |
| TG_TOKEN_MON | Telegram bot token (monitoring notification) | None |
| TG_CHAT_ID_MON | Telegram chat ID (monitoring notification) | None |

### Example: Custom Usernames and Passwords

```bash
docker run -d --name proxy-server \
  -p 3128:3128 \
  -p 1080:1080 \
  -e SQUID_USER=http_user \
  -e SQUID_PASS=http_password \
  -e PROXY_USER=socks_user \
  -e PROXY_PASS=socks_password \
  tiny-proxy-alpine
```

### Example: Enable Telegram Notifications

```bash
docker run -d --name proxy-server \
  -p 3128:3128 \
  -p 1080:1080 \
  -e TG_TOKEN_REG=your_telegram_bot_token \
  -e TG_CHAT_ID_REG=your_telegram_chat_id \
  tiny-proxy-alpine
```

## Telegram Notification Features

This project supports two types of Telegram notifications:

1. **Registration Notification**: Sends proxy service information when the container starts
   - Set `TG_TOKEN_REG` and `TG_CHAT_ID_REG` environment variables
   - Notification includes: proxy address, username, password, and verification commands

2. **Monitoring Notification**: Sends service status periodically
   - Set `TG_TOKEN_MON` and `TG_CHAT_ID_MON` environment variables
   - Notification includes: service status, memory usage, etc.

## Using the Proxy

### HTTP Proxy

```bash
curl -x 'http://username:password@server_ip:3128' ifconfig.me
```

### SOCKS5 Proxy

```bash
curl --socks5-hostname username:password@server_ip:1080 ifconfig.me
```

## Build the Image Manually

```bash
git clone https://github.com/yourusername/docker-tiny-proxy.git
cd docker-tiny-proxy
docker build -t tiny-proxy-alpine .
```

## Network Optimization and BBR Acceleration

This Docker image handles the proxy service layer, but network-level optimizations like BBR (Bottleneck Bandwidth and RTT) need to be configured at the host level since Docker containers share the host kernel.

### Enabling BBR on Host System

To maximize proxy performance, you can enable BBR on your host system:

#### Linux host (Ubuntu/Debian)

1. Check if BBR is available:
   ```bash
   sysctl net.ipv4.tcp_available_congestion_control
   ```

2. Enable BBR:
   ```bash
   # Add these lines to /etc/sysctl.conf
   net.core.default_qdisc=fq
   net.ipv4.tcp_congestion_control=bbr
   
   # Apply changes
   sudo sysctl -p
   ```

3. Verify BBR is enabled:
   ```bash
   sysctl net.ipv4.tcp_congestion_control
   ```

#### Running container with host networking

For maximum performance, you can run the container with host networking mode, which offers better network performance by skipping Docker's NAT:

```bash
docker run -d --name proxy-server \
  --network host \
  -e SQUID_PORT=3128 \
  -e PROXY_PORT=1080 \
  tiny-proxy-alpine
```

Note: When using host networking, the container ports are published directly to the host, which may require adjusting firewall rules accordingly.

## Troubleshooting

### 1. 3proxy Service Won't Start

Check if the `/etc/3proxy/3proxy.cfg` configuration file path is correct. If you've modified the default path, ensure it matches the path in supervisord.conf.

### 2. Cannot Connect to Proxy

- Ensure ports are correctly mapped
- Check firewall settings
- Verify username and password are correct
- Make sure your password doesn't contain special characters that may cause URL parsing issues

## Contributing

Issue reports and pull requests are welcome.

## License

See the [LICENSE](LICENSE) file for details.