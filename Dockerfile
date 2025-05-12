# ---------- 构建阶段 ----------
FROM alpine:edge as builder

# 安装构建依赖
RUN apk update && apk add --no-cache \
    build-base \
    wget \
    curl \
    unzip \
    bash \
    ca-certificates \
    libc6-compat \
    supervisor \
    procps

# 下载并编译 3proxy
WORKDIR /opt
RUN wget https://github.com/3proxy/3proxy/archive/refs/tags/0.9.5.tar.gz -O 3proxy-0.9.5.tar.gz && \
    tar -xvzf 3proxy-0.9.5.tar.gz && \
    cd 3proxy-0.9.5 && \
    ln -s Makefile.Linux Makefile && \
    make && \
    make install

# ---------- 最小运行阶段 ----------
FROM alpine:edge

# 安装必须的运行时依赖
RUN apk update && apk add --no-cache \
    squid \
    apache2-utils \
    curl \
    supervisor \
    libc6-compat \
    bash \
    ca-certificates \
    openssl \
    procps \
    --repository=http://dl-cdn.alpinelinux.org/alpine/edge/main/ \
    && rm -rf /var/cache/apk/*  # 清理缓存


# 复制编译后的 3proxy 二进制文件及配置文件
COPY --from=builder /opt/3proxy-0.9.5/bin/3proxy /usr/bin/3proxy
COPY --from=builder /etc/3proxy/3proxy.cfg /etc/3proxy/3proxy.cfg

# 配置文件和脚本
COPY supervisord.conf /etc/supervisord.conf
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# 暴露端口
EXPOSE 3128 1080

# 启动容器时执行的命令
# 使用ENTRYPOINT确保命令行参数被传递给entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
CMD []

# 注意: 启动容器时需要添加 --cap-add NET_ADMIN 参数以允许网络参数优化
# 例如: docker run -d --name proxy-server --cap-add NET_ADMIN -p 3128:3128 -p 1080:1080 tiny-proxy-alpine