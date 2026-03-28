#!/bin/bash
# ============================================
#  Claude Code 一键安装脚本 (国内版)
#  适用于任意 Mac (Intel / Apple Silicon)
#  用法: bash install-claude-code.sh
# ============================================
set -eo pipefail

echo ""
echo "=============================="
echo " Claude Code 一键安装"
echo "=============================="
echo ""

[[ "$(uname -s)" == "Darwin" ]] || { echo "仅支持 macOS"; exit 1; }

# ---- 1. Homebrew ----
echo "[1/4] 检查 Homebrew..."
if command -v brew &>/dev/null; then
    echo "  已安装"
else
    echo "  正在安装 Homebrew (国内镜像)..."
    /bin/bash -c "$(curl -fsSL https://gitee.com/ineo6/homebrew-install/raw/master/install.sh)"
    if [[ -f /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
        grep -q '/opt/homebrew/bin/brew' ~/.zprofile 2>/dev/null || \
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
    fi
    command -v brew &>/dev/null || { echo "  Homebrew 安装失败，请重新打开终端后重试"; exit 1; }
    echo "  Homebrew 安装完成"
fi

# ---- 2. Node.js ----
echo "[2/4] 检查 Node.js..."
if command -v node &>/dev/null; then
    echo "  已安装: $(node --version)"
else
    echo "  正在安装 Node.js..."
    brew install node || { echo "  Node.js 安装失败"; exit 1; }
    echo "  Node.js $(node --version) 安装完成"
fi

# ---- 3. Claude Code ----
echo "[3/4] 安装 Claude Code..."
npm install -g @anthropic-ai/claude-code || { echo "  Claude Code 安装失败"; exit 1; }
echo "  Claude Code 安装完成"

# ---- 4. 配置环境变量 ----
echo "[4/4] 配置环境变量..."

SHELL_RC="$HOME/.zshrc"
[[ "$SHELL" == */bash ]] && SHELL_RC="$HOME/.bashrc"
touch "$SHELL_RC"

# 写入 API 地址
if ! grep -q 'ANTHROPIC_BASE_URL' "$SHELL_RC" 2>/dev/null; then
    echo 'export ANTHROPIC_BASE_URL="https://claudecc.top/"' >> "$SHELL_RC"
    echo "  已写入 ANTHROPIC_BASE_URL"
else
    echo "  ANTHROPIC_BASE_URL 已存在，跳过"
fi

# 输入 API Key
echo ""
read -p "  请输入你的 API Key: " API_KEY
if [[ -n "$API_KEY" ]]; then
    # 如果已有旧的 key，先删掉
    sed -i '' '/ANTHROPIC_AUTH_TOKEN/d' "$SHELL_RC" 2>/dev/null
    echo "export ANTHROPIC_AUTH_TOKEN=\"${API_KEY}\"" >> "$SHELL_RC"
    echo "  已写入 ANTHROPIC_AUTH_TOKEN"
else
    echo "  未输入，跳过。后续可手动设置:"
    echo "  echo 'export ANTHROPIC_AUTH_TOKEN=\"你的key\"' >> $SHELL_RC"
fi

source "$SHELL_RC" 2>/dev/null

echo ""
echo "=============================="
echo " 安装完成！打开新终端输入 claude"
echo "=============================="
echo ""
