# How to run systemd in docker
## dockerfile
```
FROM ubuntu:22.04

# 安装 systemd 和其他必要工具
RUN apt-get update && \
    apt-get install -y systemd && \
    apt-get clean

# 设置启动命令
CMD ["/sbin/init"]
# or CMD ["/usr/bin/systemd"]
```
## build dockerfile

`docker build -t ubuntu-systemd `
## run docker container
```
docker run -d \
  --name ubuntu-systemd \
  --tmpfs /run \
  --tmpfs /run/lock \
  --tmpfs /tmp \
  -v /sys/fs/cgroup:/sys/fs/cgroup:ro \
  --privileged \
  ubuntu-systemd
  ```
