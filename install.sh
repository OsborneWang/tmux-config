#!/usr/bin/env bash
# ==============================================================================
# install.sh —— 把本仓库的 tmux 配置与辅助脚本安装到当前用户
#
# 默认（软链模式，推荐）：git pull 后配置与脚本立即同步，无需重装
#   ~/.tmux.conf          -> <repo>/tmux.conf
#   ~/.local/bin/<脚本>   -> <repo>/bin/<脚本>
#
# 用法：
#   ./install.sh             软链安装（已存在的真实文件会先备份）
#   ./install.sh --copy      复制安装（不建立软链）
#   ./install.sh --dry-run   只打印动作，不落盘
#   ./install.sh --force     已有真实文件时直接覆盖，不备份
# ==============================================================================
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
bin_dir="$HOME/.local/bin"
conf_dst="$HOME/.tmux.conf"

mode="link"
dry_run=0
force=0

for arg in "$@"; do
	case "$arg" in
		--copy)    mode="copy" ;;
		--link)    mode="link" ;;
		--dry-run) dry_run=1 ;;
		--force)   force=1 ;;
		-h|--help)
			# 打印文件开头的连续注释块作为帮助
			awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "${BASH_SOURCE[0]}"
			exit 0
			;;
		*)
			printf '未知参数：%s（用 --help 查看用法）\n' "$arg" >&2
			exit 2
			;;
	esac
done

log() { printf '%s\n' "$*"; }
run() {
	if [ "$dry_run" = 1 ]; then
		log "  [dry-run] $*"
	else
		"$@"
	fi
}

# 安装单个文件：dst 已存在且不是指向 src 的软链时，按策略备份或覆盖
install_one() {
	local src="$1" dst="$2"
	if [ "$mode" = "link" ] && [ -L "$dst" ] && [ "$(readlink -f "$dst")" = "$(readlink -f "$src")" ]; then
		log "  已就绪：$dst"
		return 0
	fi
	if [ -e "$dst" ] || [ -L "$dst" ]; then
		if [ "$force" = 1 ]; then
			log "  覆盖：$dst"
			run rm -f "$dst"
		else
			local bak
			bak="$dst.bak.$(date +%Y%m%d%H%M%S)"
			log "  备份：$dst -> $bak"
			run mv "$dst" "$bak"
		fi
	fi
	if [ "$mode" = "link" ]; then
		log "  软链：$dst -> $src"
		run ln -s "$src" "$dst"
	else
		log "  复制：$src -> $dst"
		run cp -f "$src" "$dst"
		if [ -x "$src" ]; then
			run chmod +x "$dst"
		fi
	fi
}

log "仓库位置：$repo_dir"
log "安装模式：$mode$([ "$dry_run" = 1 ] && echo '（dry-run）')"
log ""

log "[1/3] 创建目录"
run mkdir -p "$bin_dir"

log "[2/3] 安装 tmux 配置"
install_one "$repo_dir/tmux.conf" "$conf_dst"

log "[3/3] 安装辅助脚本"
for src in "$repo_dir"/bin/*; do
	[ -f "$src" ] || continue
	install_one "$src" "$bin_dir/$(basename "$src")"
done

log ""
log "完成。后续步骤："

# PATH 检查
case ":$PATH:" in
	*":$bin_dir:"*) : ;;
	*) log "  ! $bin_dir 不在 PATH 中，请在 ~/.profile 或 ~/.bashrc 里追加："
	   log "      export PATH=\"\$HOME/.local/bin:\$PATH\"" ;;
esac

# 运行中的 tmux server 直接重载
if command -v tmux >/dev/null 2>&1 && tmux list-sessions >/dev/null 2>&1; then
	if [ "$dry_run" = 1 ]; then
		log "  [dry-run] 将执行：tmux source-file $conf_dst"
	elif tmux source-file "$conf_dst" 2>/dev/null; then
		log "  已重载运行中的 tmux（$conf_dst）"
	else
		log "  ! 重载失败，可手动执行：tmux source-file $conf_dst"
	fi
else
	log "  当前没有运行中的 tmux server，下次启动即生效"
fi

cat <<'EOF'

  注意：terminal-features / extended-keys / mode-keys 等选项只在 client
        建立连接时下发，改完首次生效需要 detach 再 attach：

            Ctrl+b d
            tmux attach

  校验：tmux info | grep Eneks      应为 Eneks: (string) \033[>4;2m
EOF
