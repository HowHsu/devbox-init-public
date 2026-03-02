# devbox_init

一条命令搭建 Ubuntu 开发环境 —— 从裸机到完整工作站。

## 概览

```
裸机  ──►  自动安装 USB  ──►  Ubuntu Desktop  ──►  bootstrap.sh  ──►  就绪
```

1. **autoinstall/** — 制作无人值守安装 USB（或 ISO）
2. **init/bootstrap.sh** — 安装所有开发工具、恢复备份、配置 dotfiles
3. **init/oss_\*.sh** — 加密备份/恢复到阿里云 OSS（基于 rclone）
4. **daily/** — 日常工具脚本

## 快速开始

### 新机器上（Ubuntu 安装完成后）

```bash
git clone https://github.com/HowHsu/devbox_init ~/devbox_init
cd ~/devbox_init && bash init/bootstrap.sh
```

脚本会先询问 **桌面模式** 还是 **服务器模式**，然后分两阶段执行：

| 阶段 | 前提条件 | 安装内容 |
|------|---------|---------|
| 阶段 1 | 可直连互联网 | 基础包、Docker、微信、HexChat、OSS 恢复、SSH 密钥、dotfiles、Trojan 代理 |
| 阶段 2 | 代理可用（端口 1081） | GitHub CLI、Firefox、Chrome、Claude Code、Cursor、Signal |

每一步都记录在 `init/bootstrap_done` 中，中断后可安全重跑。

### 制作自动安装 USB

```bash
cd ~/devbox_init/autoinstall
bash make_usb.sh
```

脚本会依次：
1. 查询最新 Ubuntu LTS / stable 版本
2. 下载 Desktop ISO（优先国内镜像，失败后 proxychains 走官方源）
3. 校验 SHA256（校验值始终从 `releases.ubuntu.com` 获取，不信任镜像站）
4. 注入 autoinstall 配置，重新打包 ISO
5. 可选写入 USB

详见 [autoinstall/README.md](autoinstall/README.md)（含虚拟机测试流程）。

## 项目结构

```
devbox_init/
├── autoinstall/              # 无人值守安装工具
│   ├── make_usb.sh           #   主脚本：下载、校验、打包、写盘
│   ├── user-data             #   cloud-init autoinstall 模板
│   └── meta-data
├── init/                     # 初始化 & 备份
│   ├── bootstrap.sh          #   编排器：按顺序执行 packages/*.sh
│   ├── bootstrap_done        #   步骤完成状态
│   ├── packages/             #   每个软件一个脚本
│   │   ├── base_packages.sh
│   │   ├── docker.sh
│   │   ├── trojan.sh
│   │   ├── claude_code.sh
│   │   └── ...
│   ├── oss_common.sh         #   rclone 共享配置（OSS + 加密）
│   ├── oss_restore.sh        #   从 OSS 恢复（交互式或脚本调用）
│   └── oss_encrypted_backup.sh  # 加密备份到 OSS
├── daily/                    # 日常工具
│   └── oss_download.sh       #   交互式 OSS 文件浏览器
├── qemu_test_box/            # QEMU 虚拟机测试（git submodule）
└── README.md
```

## OSS 备份与恢复

文件在客户端通过 rclone crypt 加密后存储到阿里云 OSS。凭证在首次运行时交互输入，不存储在仓库中。

```bash
# 备份（copy 模式：只增不删，不影响远端已有文件）
bash init/oss_encrypted_backup.sh [--dry-run]

# 恢复指定路径
bash init/oss_restore.sh ssh_keys trojan

# 全量恢复
bash init/oss_restore.sh

# 交互式文件浏览器
bash daily/oss_download.sh
```

## 系统要求

- Ubuntu 24.04+（桌面版或服务器版）
- 可联网（支持国内镜像；proxychains 翻墙）

## License

MIT
