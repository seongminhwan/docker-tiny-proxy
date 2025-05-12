#!/bin/bash
set -e

# === TCP网络参数优化 ===
# 注意：这些参数只能在容器内部生效，不影响宿主机
echo "正在优化网络参数..."
# 增加TCP缓冲区大小
sysctl -w net.core.rmem_max=16777216 2>/dev/null || true
sysctl -w net.core.wmem_max=16777216 2>/dev/null || true
sysctl -w net.ipv4.tcp_rmem="4096 87380 16777216" 2>/dev/null || true
sysctl -w net.ipv4.tcp_wmem="4096 65536 16777216" 2>/dev/null || true

# 优化TCP连接参数
sysctl -w net.ipv4.tcp_fin_timeout=15 2>/dev/null || true
sysctl -w net.ipv4.tcp_keepalive_time=300 2>/dev/null || true
sysctl -w net.ipv4.tcp_keepalive_intvl=30 2>/dev/null || true
sysctl -w net.ipv4.tcp_keepalive_probes=5 2>/dev/null || true

# 检测宿主机BBR状态
if sysctl net.ipv4.tcp_congestion_control 2>/dev/null | grep -q bbr; then
  echo "✅ 宿主机已启用BBR加速"
else
  echo "⚠️ 宿主机未启用BBR加速，推荐在宿主机上启用BBR以获得更好的性能"
  echo "   可通过README中的指导在宿主机上启用BBR"
fi

# === Telegram通知配置 ===
TG_TOKEN_REG=${TG_TOKEN_REG:-""}
TG_CHAT_ID_REG=${TG_CHAT_ID_REG:-""}
TG_TOKEN_MON=${TG_TOKEN_MON:-""}
TG_CHAT_ID_MON=${TG_CHAT_ID_MON:-""}

# === 代理服务配置 ===
SQUID_USER=${SQUID_USER:-squid_$(openssl rand -hex 3)}
# 生成随机密码并去除特殊字符（:/?@\等）
SQUID_PASS=${SQUID_PASS:-$(openssl rand -base64 12 | tr -d ':/?@\&=+$,;%#' | head -c 12)}
SQUID_PORT=3128

PROXY_USER=${PROXY_USER:-socks5_$(openssl rand -hex 3)}
# 生成随机密码并去除特殊字符（:/?@\等）
PROXY_PASS=${PROXY_PASS:-$(openssl rand -base64 12 | tr -d ':/?@\&=+$,;%#' | head -c 12)}
PROXY_PORT=1080

# 配置 Squid
htpasswd -b -c /etc/squid/passwd "$SQUID_USER" "$SQUID_PASS"
cat >/etc/squid/squid.conf <<EOF
auth_param basic program /usr/lib/squid/basic_ncsa_auth /etc/squid/passwd
auth_param basic realm proxy
acl authenticated proxy_auth REQUIRED
http_access allow authenticated
http_port $SQUID_PORT
http_access deny all
EOF

mkdir -p /conf
# 配置 3proxy
cat >/etc/3proxy/3proxy.cfg <<EOF
nscache 65536
timeouts 1 5 30 60 180 1800 15 60
log /dev/null
auth strong
users $PROXY_USER:CL:$PROXY_PASS
allow $PROXY_USER
socks -p$PROXY_PORT
EOF


# 获取服务器IP
SERVER_IP=$(hostname -i)

# 生成验证命令
CURL_HTTP="curl -x 'http://$SQUID_USER:$SQUID_PASS@$SERVER_IP:$SQUID_PORT' ifconfig.me"
CURL_SOCKS5="curl --socks5-hostname $PROXY_USER:$PROXY_PASS@$SERVER_IP:$PROXY_PORT ifconfig.me"

# 输出代理信息
echo "HTTP 代理：http://$SQUID_USER:$SQUID_PASS@$SERVER_IP:$SQUID_PORT"
echo "SOCKS5 代理：$PROXY_USER:$PROXY_PASS@$SERVER_IP:$PROXY_PORT"
echo "HTTP验证命令: $CURL_HTTP"
echo "SOCKS5验证命令: $CURL_SOCKS5"

# 发送Telegram注册通知
if [[ -n "$TG_TOKEN_REG" && -n "$TG_CHAT_ID_REG" ]]; then
  MESSAGE="✅ 代理部署完成

🌐 HTTP 代理 (Squid)
地址: http://$SERVER_IP:$SQUID_PORT
用户名: $SQUID_USER
密码: $SQUID_PASS

验证命令:
$CURL_HTTP

🌐 SOCKS5 代理 (3proxy)
地址: $SERVER_IP:$PROXY_PORT
用户名: $PROXY_USER
密码: $PROXY_PASS

验证命令:
$CURL_SOCKS5
"

  # 后台发送Telegram通知，不阻塞主进程
  curl -s -X POST "https://api.telegram.org/bot$TG_TOKEN_REG/sendMessage" \
    -d chat_id="$TG_CHAT_ID_REG" \
    -d text="$MESSAGE" &
fi

# 配置监控通知（在Docker环境中使用supervisor）
if [[ -n "$TG_TOKEN_MON" && -n "$TG_CHAT_ID_MON" ]]; then
  # 创建定时发送监控状态的脚本
  mkdir -p /usr/local/bin
  cat >/usr/local/bin/tg_monitor.sh <<EOF
#!/bin/bash
curl -s -X POST https://api.telegram.org/bot$TG_TOKEN_MON/sendMessage \
  -d chat_id="$TG_CHAT_ID_MON" \
  -d text="[\$(date +'%F %T')] 🟢 \$(hostname) 状态: squid: 运行中, 3proxy: 运行中, 内存: \$(free -m | awk '/Mem:/ {print \$3\"MB/\"\$2\"MB\"}')"
EOF
  chmod +x /usr/local/bin/tg_monitor.sh
  
  # 添加到crontab (Alpine Linux使用/etc/crontabs)
  mkdir -p /etc/crontabs
  echo '0 * * * * /usr/local/bin/tg_monitor.sh' > /etc/crontabs/root
  
  # 启用supervisord中的cron服务（通过环境变量设置）
  export SUPERVISORD_CRON_AUTOSTART=true
fi

# 在启动supervisord之前，根据环境变量设置cron自动启动
# 创建一个临时的supervisord配置文件，根据是否启用cron进行调整
if [[ "$SUPERVISORD_CRON_AUTOSTART" == "true" ]]; then
  sed 's/autostart=false/autostart=true/g' /etc/supervisord.conf > /tmp/supervisord.conf
  echo "已启用Telegram监控服务"
  # 启动supervisord，使用临时配置文件
  exec /usr/bin/supervisord -c /tmp/supervisord.conf
else
  # 使用原始配置文件启动supervisord
  exec /usr/bin/supervisord -c /etc/supervisord.conf
fi