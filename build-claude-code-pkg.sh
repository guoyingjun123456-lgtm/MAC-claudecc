#!/bin/bash
#
# ============================================================
#  Claude Code macOS 一键安装包构建脚本
# ============================================================
#
#  用法:
#    1. 在任意一台 Mac 上运行本脚本:
#       chmod +x build-claude-code-pkg.sh
#       ./build-claude-code-pkg.sh
#
#    2. 脚本自动生成 ClaudeCode-Installer.pkg
#
#    3. 将 .pkg 拷贝到任意 Mac, 双击安装即可
#
#  构建环境要求: macOS + Node.js + npm
#
# ============================================================

set -euo pipefail

# ==================== 配置 ====================
NODE_VERSION="22.14.0"
CLAUDE_PKG="@anthropic-ai/claude-code"
PKG_ID="com.anthropic.claude-code-installer"
# ==============================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK="${SCRIPT_DIR}/.build_pkg"
PAYLOAD="${WORK}/payload/usr/local/lib/claude-code-installer"

info()  { printf '\033[0;34m[INFO]\033[0m %s\n' "$*"; }
ok()    { printf '\033[0;32m[ OK ]\033[0m %s\n' "$*"; }
die()   { printf '\033[0;31m[FAIL]\033[0m %s\n' "$*"; exit 1; }

trap 'rm -rf "$WORK"' EXIT

# ==================== 检查环境 ====================
[[ "$(uname -s)" == "Darwin" ]] || die "请在 macOS 上运行"
for cmd in curl node npm pkgbuild productbuild; do
    command -v "$cmd" &>/dev/null || die "缺少: $cmd"
done

# ==================== 准备 ====================
rm -rf "$WORK"
mkdir -p "$PAYLOAD"/{node-arm64,node-x64,claude-code-pkg} \
         "$WORK"/{scripts,resources,downloads}

# ==================== 下载 Node.js ====================
download_node() {
    local arch=$1 url="https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-darwin-${1}.tar.gz"
    local dest="${WORK}/downloads/node-${arch}.tar.gz"
    [[ -f "$dest" ]] && return
    info "下载 Node.js v${NODE_VERSION} (${arch})..."
    curl -f -# -L -o "$dest" "$url" || die "下载失败, 请检查版本号 ${NODE_VERSION}"
    tar -xzf "$dest" -C "${PAYLOAD}/node-${arch}" --strip-components=1
    ok "Node.js ${arch} 准备完成"
}

download_node arm64 &
pid1=$!
download_node x64 &
pid2=$!
wait $pid1 || die "Node.js arm64 下载失败"
wait $pid2 || die "Node.js x64 下载失败"

# ==================== 下载 Claude Code ====================
info "安装 Claude Code (可能需要几分钟)..."
npm install -g "$CLAUDE_PKG" --prefix="${PAYLOAD}/claude-code-pkg" 2>&1 | tail -5
[[ -d "${PAYLOAD}/claude-code-pkg/lib/node_modules/${CLAUDE_PKG}" ]] || die "Claude Code 安装失败"

VERSION=$(node -e "console.log(require('${PAYLOAD}/claude-code-pkg/lib/node_modules/${CLAUDE_PKG}/package.json').version)" 2>/dev/null || echo "latest")
ok "Claude Code v${VERSION} 准备完成"

# ==================== 生成 postinstall ====================
cat > "${WORK}/scripts/postinstall" <<'POSTINSTALL'
#!/bin/bash
set -eo pipefail

INSTALLER="/usr/local/lib/claude-code-installer"
NODE_DIR="/usr/local/lib/nodejs"
LOG="/tmp/claude-code-install.log"

log() { echo "$(date '+%H:%M:%S') $*" | tee -a "$LOG"; }

log "=== Claude Code 安装开始 ==="

# 1. 按架构选择 Node.js
ARCH=$(uname -m)
case "$ARCH" in
    arm64)  NODE_SRC="${INSTALLER}/node-arm64" ;;
    x86_64) NODE_SRC="${INSTALLER}/node-x64" ;;
    *)      log "不支持的架构: $ARCH"; exit 1 ;;
esac
log "架构: $ARCH"

# 2. 安装 Node.js
[[ -d "$NODE_DIR" ]] && mv "$NODE_DIR" "${NODE_DIR}.bak.$(date +%s)"
mkdir -p "$NODE_DIR"
cp -R "${NODE_SRC}/"* "$NODE_DIR/"
log "Node.js $(${NODE_DIR}/bin/node --version) 已安装"

# 3. 创建 symlinks
mkdir -p /usr/local/bin
for bin in node npm npx; do
    ln -sf "${NODE_DIR}/bin/${bin}" "/usr/local/bin/${bin}"
done

# 4. 安装 Claude Code (纯文件复制)
PKG="${INSTALLER}/claude-code-pkg"
cp -R "${PKG}/lib/node_modules/"* "${NODE_DIR}/lib/node_modules/"
[[ -d "${PKG}/bin" ]] && cp -R "${PKG}/bin/"* "${NODE_DIR}/bin/" 2>/dev/null || true
ln -sf "${NODE_DIR}/bin/claude" /usr/local/bin/claude

# 5. 配置 PATH
grep -qxF "/usr/local/bin" /etc/paths 2>/dev/null || echo "/usr/local/bin" > /etc/paths.d/claude-code

# 6. 清理
rm -rf "$INSTALLER"

# 7. 验证
if [[ -x /usr/local/bin/claude ]]; then
    log "Claude Code $(/usr/local/bin/claude --version 2>/dev/null || echo '') 安装成功!"
else
    log "警告: 安装可能未完成, 请查看 $LOG"
fi
log "=== 请打开新终端, 运行 claude ==="
POSTINSTALL
chmod +x "${WORK}/scripts/postinstall"

# ==================== 生成 preinstall ====================
cat > "${WORK}/scripts/preinstall" <<'EOF'
#!/bin/bash
echo "系统检查: $(uname -s) $(uname -m)"
[[ "$(uname -s)" == "Darwin" ]] || { echo "仅支持 macOS"; exit 1; }
command -v node &>/dev/null && echo "检测到已有 Node.js: $(node --version), /usr/local/bin 链接将被替换"
exit 0
EOF
chmod +x "${WORK}/scripts/preinstall"

# ==================== 生成安装界面 ====================
cat > "${WORK}/resources/welcome.html" <<'HTML'
<html><head><meta charset="utf-8"></head>
<body style="font-family:-apple-system,sans-serif;padding:20px;line-height:1.6">
<h2>Claude Code 一键安装</h2>
<p>将自动安装 <b>Node.js</b> + <b>Claude Code</b>，安装完成后打开终端运行 <code>claude</code> 即可。</p>
<p style="color:#888;font-size:12px">支持 Intel + Apple Silicon | 安装路径: /usr/local/lib/nodejs</p>
</body></html>
HTML

cat > "${WORK}/resources/conclusion.html" <<'HTML'
<html><head><meta charset="utf-8"></head>
<body style="font-family:-apple-system,sans-serif;padding:20px;line-height:1.6">
<h2>安装完成!</h2>
<p>打开 <b>终端</b>，输入 <code>claude</code> 即可使用。</p>
<p>如果提示找不到命令，请关闭终端重新打开。</p>
</body></html>
HTML

cat > "${WORK}/resources/license.txt" <<'TXT'
本软件由 Anthropic, PBC 提供。使用即表示同意 Anthropic 使用条款。
详情: https://www.anthropic.com/terms
Node.js 使用 MIT 许可证: https://github.com/nodejs/node/blob/main/LICENSE
TXT

# ==================== 生成 distribution.xml ====================
cat > "${WORK}/distribution.xml" <<XML
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
    <title>Claude Code Installer</title>
    <welcome file="welcome.html" mime-type="text/html"/>
    <license file="license.txt"/>
    <conclusion file="conclusion.html" mime-type="text/html"/>
    <options customize="never" hostArchitectures="x86_64,arm64"/>
    <domains enable_localSystem="true"/>
    <volume-check><allowed-os-versions><os-version min="11.0"/></allowed-os-versions></volume-check>
    <choices-outline><line choice="default"><line choice="pkg"/></line></choices-outline>
    <choice id="default"/><choice id="pkg" visible="false"><pkg-ref id="${PKG_ID}"/></choice>
    <pkg-ref id="${PKG_ID}" version="1.0.0">component.pkg</pkg-ref>
</installer-gui-script>
XML

# ==================== 打包 ====================
OUTPUT="${SCRIPT_DIR}/ClaudeCode-Installer-v${VERSION}.pkg"

info "打包 .pkg..."
pkgbuild --root "${WORK}/payload" --scripts "${WORK}/scripts" \
    --identifier "$PKG_ID" --version "1.0.0" --install-location "/" \
    "${WORK}/component.pkg" >/dev/null

productbuild --distribution "${WORK}/distribution.xml" \
    --resources "${WORK}/resources" --package-path "$WORK" \
    "$OUTPUT" >/dev/null

# ==================== 生成卸载脚本 ====================
cat > "${SCRIPT_DIR}/uninstall-claude-code.sh" <<'UNINSTALL'
#!/bin/bash
echo "Claude Code 卸载工具"
echo "将删除: /usr/local/lib/nodejs, /usr/local/bin/{node,npm,npx,claude}"
read -p "确认? (y/N) " c; [[ "$c" == [yY] ]] || { echo "已取消"; exit 0; }
sudo -v
for bin in node npm npx claude; do
    link="/usr/local/bin/$bin"
    [[ -L "$link" ]] && target=$(readlink "$link") && \
        [[ "$target" == */usr/local/lib/nodejs/* ]] && sudo rm -f "$link" && echo "  删除 $link"
done
[[ -d /usr/local/lib/nodejs ]] && sudo rm -rf /usr/local/lib/nodejs && echo "  删除 /usr/local/lib/nodejs"
[[ -f /etc/paths.d/claude-code ]] && sudo rm -f /etc/paths.d/claude-code
sudo rm -f /tmp/claude-code-install.log
sudo pkgutil --forget com.anthropic.claude-code-installer 2>/dev/null || true
echo "卸载完成! 请重新打开终端。"
UNINSTALL
chmod +x "${SCRIPT_DIR}/uninstall-claude-code.sh"

# ==================== 完成 ====================
SIZE=$(du -sh "$OUTPUT" | cut -f1)
echo ""
echo "============================================"
ok "构建完成!"
echo ""
echo "  文件: $OUTPUT"
echo "  大小: $SIZE"
echo "  版本: Claude Code v${VERSION} + Node.js v${NODE_VERSION}"
echo ""
echo "  使用: 将 .pkg 拷贝到任意 Mac, 双击安装"
echo "============================================"
