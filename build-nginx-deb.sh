#!/usr/bin/env bash
# 在 WSL 中执行：用 docker.m.daocloud.io/ubuntu:24.04 构建 nginx 1.30.4 的 .deb
# 用法:
#   bash build-nginx-deb.sh
#   OUT_DIR=/mnt/c/Users/46805/WorkBuddy/2026-10-20-11-31-02/nginx-deb-out bash build-nginx-deb.sh
set -euo pipefail

NGINX_VER="${NGINX_VER:-1.30.6}"
PKG_REL="${PKG_REL:-1~noble}"
IMAGE="${IMAGE:-docker.m.daocloud.io/ubuntu:24.04}"
APT_MIRROR="${APT_MIRROR:-https://mirrors.tuna.tsinghua.edu.cn/ubuntu}"
# 默认输出到 Windows 桌面可见的位置（若 /mnt/c 存在）
if [ -z "${OUT_DIR:-}" ]; then
  if [ -d /mnt/c/Users ]; then
    OUT_DIR="/mnt/c/Users/$(whoami 2>/dev/null || echo Public)/WorkBuddy/2026-10-20-11-31-02/nginx-deb-out"
  else
    OUT_DIR="$PWD/nginx-deb-out"
  fi
fi
mkdir -p "$OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"

echo ">>> image      : $IMAGE"
echo ">>> nginx ver  : $NGINX_VER ($PKG_REL)"
echo ">>> output dir : $OUT_DIR"
docker pull "$IMAGE" >/dev/null

docker run --rm -i \
  -v "$OUT_DIR":/out \
  -e NGINX_VER="$NGINX_VER" \
  -e PKG_REL="$PKG_REL" \
  -e APT_MIRROR="$APT_MIRROR" \
  "$IMAGE" bash -s <<'INNER'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
export LANG=C.UTF-8

echo "=== [1/5] 配置 apt 镜像源 (noble deb822) ==="
echo 'Acquire::https::Verify-Peer "false";' > /etc/apt/apt.conf.d/99-no-ssl-verify
if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then
  sed -i -E "s@https?://(archive|security)\.ubuntu\.com(:[0-9]+)?/ubuntu/?( )?@${APT_MIRROR} @g" \
    /etc/apt/sources.list.d/ubuntu.sources || true
  # 兜底：直接改写 URIs 行
  sed -i -E "s@^URIs:.*@URIs: ${APT_MIRROR}@g" /etc/apt/sources.list.d/ubuntu.sources || true
fi
cat /etc/apt/sources.list.d/ubuntu.sources 2>/dev/null || true

echo "=== [2/5] 安装构建依赖 ==="
apt-get update -y
apt-get install -y --no-install-recommends \
  ca-certificates curl xz-utils build-essential dpkg-dev debhelper quilt devscripts equivs

echo "=== [3/5] 下载 nginx 官方 noble 源码包 ==="
BASE="https://nginx.org/packages/ubuntu/pool/nginx/n/nginx"
cd /tmp
for f in "nginx_${NGINX_VER}.orig.tar.gz" \
         "nginx_${NGINX_VER}-${PKG_REL}.dsc" \
         "nginx_${NGINX_VER}-${PKG_REL}.debian.tar.xz"; do
  echo "  -> $f"
  curl -fSL --retry 5 --retry-delay 2 --connect-timeout 20 -O "$BASE/$f"
done
rm -rf "/tmp/nginx-${NGINX_VER}"
dpkg-source -x "nginx_${NGINX_VER}-${PKG_REL}.dsc" "/tmp/nginx-${NGINX_VER}"

echo "=== [4/5] 安装 Build-Depends (mk-build-deps) ==="
cd "/tmp/nginx-${NGINX_VER}"
mk-build-deps -i -r -t "apt-get -y --no-install-recommends -o Debug::pkgProblemResolver=yes" debian/control

echo "=== [5/5] 编译打包 ==="
DEB_BUILD_OPTIONS="nocheck parallel=$(nproc)" \
  dpkg-buildpackage -b -uc -us -j"$(nproc)"
if ! ls /tmp/*.deb >/dev/null 2>&1; then
  echo "!! 没有生成任何 .deb，构建失败" >&2
  exit 1
fi
cp -v /tmp/*.deb /out/
cd /out && ls -lh *.deb
INNER

echo
echo ">>> 完成，deb 输出目录: $OUT_DIR"
ls -lh "$OUT_DIR"

