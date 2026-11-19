# nginx-deb-builder

在 Docker 容器内将 nginx 官方源码包一键编译打包为 Ubuntu `.deb`，无需污染宿主机环境。

## 特性

- 基于 `ubuntu:24.04` (noble) 容器构建，环境干净可复现
- 直接使用 [nginx.org 官方 Ubuntu 源码包](https://nginx.org/packages/ubuntu/)（含官方 `debian/` 打包目录）
- 通过 `mk-build-deps` 自动安装 Build-Depends
- 使用 `dpkg-buildpackage` 完成编译与打包，跳过签名（`-uc -us`）
- 可自定义 nginx 版本、包修订号、apt 镜像源和输出目录
- 自动使用 `nproc` 并行编译加速

## 前置要求

- Docker（Windows 用户建议在 WSL 中运行）
- 网络可达 Docker 镜像仓库与 apt 镜像源

## 使用

```bash
bash build-nginx-deb.sh
```

产物默认输出到 `./nginx-deb-out/`：

```
nginx_1.30.6-1~noble_amd64.deb
nginx-dbg_1.30.6-1~noble_amd64.deb
```

安装：

```bash
sudo apt install ./nginx-deb-out/nginx_1.30.6-1~noble_amd64.deb
```

## 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `NGINX_VER` | `1.30.6` | nginx 版本号 |
| `PKG_REL` | `1~noble` | Debian 包修订号（需与 nginx.org 上 dsc 文件名一致） |
| `IMAGE` | `docker.m.daocloud.io/ubuntu:24.04` | Docker 基础镜像 |
| `APT_MIRROR` | `https://mirrors.tuna.tsinghua.edu.cn/ubuntu` | 容器内 apt 镜像源 |
| `OUT_DIR` | `./nginx-deb-out` | 产物输出目录 |

示例：构建其他版本并指定输出目录

```bash
NGINX_VER=1.28.0 PKG_REL=1~noble OUT_DIR=/tmp/out bash build-nginx-deb.sh
```

## 构建流程

1. 拉取 Ubuntu 24.04 镜像
2. 容器内配置 apt 镜像源，安装构建依赖（build-essential、dpkg-dev、debhelper 等）
3. 从 `nginx.org` 下载 `orig.tar.gz` + `.dsc` + `debian.tar.xz`
4. `dpkg-source -x` 解包源码
5. `mk-build-deps` 安装 Build-Depends
6. `dpkg-buildpackage -b -uc -us` 编译打包，产物复制到输出目录

## 注意事项

- 构建的包为 amd64 架构；如需其他架构请在对应架构的机器/容器中运行
- 修订号（`PKG_REL`）需与 nginx.org 仓库中对应版本的实际文件名匹配，否则下载会失败
- 脚本中禁用了 apt SSL 校验（`Verify-Peer false`）以兼容部分镜像源，如介意可自行移除

## License

MIT
