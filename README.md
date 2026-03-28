# Claude Code 一键安装脚本 (Mac)

在任意 Mac 上一条命令安装 Claude Code，自动处理所有依赖。

## 使用方法

打开 Mac 终端，粘贴运行：

```bash
curl -fsSL https://gitee.com/zth_zh/mac-claudecc/raw/main/install-claude-code.sh | bash
```

或者下载后运行：

```bash
curl -fsSL -o install.sh https://gitee.com/zth_zh/mac-claudecc/raw/main/install-claude-code.sh
bash install.sh
```

## 自动安装内容

| 步骤 | 内容 | 说明 |
|------|------|------|
| 1/4 | Homebrew | 使用国内镜像，不会超时 |
| 2/4 | Node.js | 通过 brew install node |
| 3/4 | Claude Code | 通过 npm install -g |
| 4/4 | 环境变量 | 自动配置 API 地址，手动输入 API Key |

## 支持环境

- macOS 11 (Big Sur) 及以上
- Intel (x86_64) + Apple Silicon (M1/M2/M3/M4)
- zsh / bash

## 文件说明

- `install-claude-code.sh` — 一键安装脚本（用这个就够了）
- `build-claude-code-pkg.sh` — .pkg 离线安装包构建脚本（可选）
