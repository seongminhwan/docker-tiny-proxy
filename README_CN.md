# Docker Tiny Proxy

一个轻量级的Docker代理服务容器，提供HTTP(Squid)和SOCKS5(3proxy)代理功能，支持用户认证和Telegram通知。

[English](README.md) | [中文](README_CN.md)

## 功能特点

- 支持HTTP代理(Squid)和SOCKS5代理(3proxy)
- 自动生成随机用户名和密码
- 支持通过环境变量自定义用户名和密码
- 轻量级Alpine Linux基础镜像
- 支持通过Telegram机器人发送代理信息和状态通知

## 快速开始

### 使用Docker运行

```bash
docker run -d --name proxy-server \
  -p 3128:3128 \
  -p 1080:1080 \
  tiny-proxy-alpine
```

### 使用Docker Compose运行

创建`docker-compose.yml`文件：

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

然后运行：

```bash
docker-compose up -d
```

## 环境变量配置

可以通过环境变量自定义代理配置：

| 环境变量 | 描述 | 默认值 |
|----------|------|--------|
| SQUID_USER | HTTP代理用户名 | 随机生成 |
| SQUID_PASS | HTTP代理密码 | 随机生成 |
| PROXY_USER | SOCKS5代理用户名 | 随机生成 |
| PROXY_PASS | SOCKS5代理密码 | 随机生成 |
| TG_TOKEN_REG | Telegram机器人Token(注册通知) | 无 |
| TG_CHAT_ID_REG | Telegram聊天ID(注册通知) | 无 |
| TG_TOKEN_MON | Telegram机器人Token(监控通知) | 无 |
| TG_CHAT_ID_MON | Telegram聊天ID(监控通知) | 无 |

### 示例：自定义用户名和密码

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

### 示例：启用Telegram通知

```bash
docker run -d --name proxy-server \
  -p 3128:3128 \
  -p 1080:1080 \
  -e TG_TOKEN_REG=your_telegram_bot_token \
  -e TG_CHAT_ID_REG=your_telegram_chat_id \
  tiny-proxy-alpine
```

## Telegram通知功能

本项目支持两种Telegram通知：

1. **注册通知**：容器启动时发送代理服务信息
   - 设置`TG_TOKEN_REG`和`TG_CHAT_ID_REG`环境变量
   - 通知内容包括：代理地址、用户名、密码和验证命令

2. **监控通知**：定期发送服务状态
   - 设置`TG_TOKEN_MON`和`TG_CHAT_ID_MON`环境变量
   - 通知内容包括：服务状态、内存使用情况等

## 使用代理

### HTTP代理

```bash
curl -x 'http://username:password@server_ip:3128' ifconfig.me
```

### SOCKS5代理

```bash
curl --socks5-hostname username:password@server_ip:1080 ifconfig.me
```

## 手动构建镜像

```bash
git clone https://github.com/yourusername/docker-tiny-proxy.git
cd docker-tiny-proxy
docker build -t tiny-proxy-alpine .
```

## 网络优化和BBR加速

本Docker镜像处理代理服务层，但BBR（Bottleneck Bandwidth and RTT）等网络级优化需要在宿主机级别配置，因为Docker容器共享宿主机内核。

### 在宿主机上启用BBR

为了最大化代理性能，您可以在宿主机系统上启用BBR：

#### Linux宿主机（Ubuntu/Debian）

1. 检查BBR是否可用：
   ```bash
   sysctl net.ipv4.tcp_available_congestion_control
   ```

2. 启用BBR：
   ```bash
   # 将这些行添加到/etc/sysctl.conf
   net.core.default_qdisc=fq
   net.ipv4.tcp_congestion_control=bbr
   
   # 应用更改
   sudo sysctl -p
   ```

3. 验证BBR已启用：
   ```bash
   sysctl net.ipv4.tcp_congestion_control
   ```

#### 使用主机网络运行容器

为获得最佳性能，您可以使用主机网络模式运行容器，这通过跳过Docker的NAT提供更好的网络性能：

```bash
docker run -d --name proxy-server \
  --network host \
  --cap-add NET_ADMIN \
  -e SQUID_PORT=3128 \
  -e PROXY_PORT=1080 \
  tiny-proxy-alpine
```

注意：使用主机网络时，容器端口直接发布到主机，可能需要相应调整防火墙规则。

## 故障排除

### 1. 3proxy服务无法启动

检查`/etc/3proxy/3proxy.cfg`配置文件路径是否正确。如果修改了默认路径，请确保supervisord.conf中的路径与其一致。

### 2. 无法连接到代理

- 确保端口已正确映射
- 检查防火墙设置
- 验证用户名和密码是否正确
- 确保密码中不包含可能导致URL解析问题的特殊字符

## 贡献

欢迎提交问题报告和拉取请求。

## 许可证

详见[LICENSE](LICENSE)文件。