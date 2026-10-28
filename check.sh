#!/usr/bin/env bash
# ==============================================================================
# check.sh —— 本地自检，改完配置/脚本后跑一遍再提交
#
# 依次检查：
#   1. 脚本语法（sh -n / bash -n / python3 编译）
#   2. shellcheck（若已安装，缺失只提示不判失败）
#   3. tmux.conf 能否被一个干净的 server 完整解析
#   4. 关键自定义绑定是否真的存在（hjkl / Tab / v / V / y）
#
# 用法：./check.sh        全部通过退出码为 0
# ==============================================================================
set -uo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
fail=0
socket="tmuxcfg-check-$$"

pass() { printf '  \033[32m✓\033[0m %s\n' "$1"; }
bad()  { printf '  \033[31m✗\033[0m %s\n' "$1"; fail=1; }
skip() { printf '  \033[33m-\033[0m %s\n' "$1"; }

# ---------------------------------------------------------------- 1. 语法
printf '[1/4] 脚本语法\n'
for f in "$repo_dir"/bin/* "$repo_dir"/install.sh "$repo_dir"/check.sh; do
	[ -f "$f" ] || continue
	name=$(basename "$f")
	shebang=$(head -1 "$f")
	case "$shebang" in
		*'python'*)
			if python3 -m py_compile "$f" 2>/dev/null; then
				pass "$name（python3）"
			else
				bad "$name（python3 编译失败）"
			fi
			;;
		*'bash'*)
			if bash -n "$f" 2>/dev/null; then pass "$name（bash）"; else bad "$name（bash -n 失败）"; fi
			;;
		*'/sh'*|*' sh'*)
			if sh -n "$f" 2>/dev/null; then pass "$name（sh）"; else bad "$name（sh -n 失败）"; fi
			;;
		*)
			skip "$name（无法识别的 shebang）"
			;;
	esac
done

# ---------------------------------------------------------------- 2. shellcheck
printf '[2/4] shellcheck\n'
if command -v shellcheck >/dev/null 2>&1; then
	out=$(shellcheck -S warning -s sh "$repo_dir"/bin/clip-clean \
		"$repo_dir"/bin/clip-path "$repo_dir"/bin/clip-pick "$repo_dir"/bin/clip-show 2>&1)
	out+=$(shellcheck -S warning -s bash "$repo_dir"/install.sh "$repo_dir"/check.sh 2>&1)
	if [ -z "$out" ]; then pass "无告警"; else printf '%s\n' "$out"; bad "存在告警"; fi
else
	skip "未安装 shellcheck（sudo apt install shellcheck）"
fi

# ---------------------------------------------------------------- 3. 配置解析
printf '[3/4] tmux.conf 解析\n'
tmux -L "$socket" kill-server 2>/dev/null
if err=$(tmux -L "$socket" -f "$repo_dir/tmux.conf" new-session -d -x 100 -y 30 'sleep 5' 2>&1); then
	pass "干净 server 加载无报错"
else
	bad "加载失败：$err"
fi

# ---------------------------------------------------------------- 4. 关键绑定
printf '[4/4] 关键绑定\n'
expect() {
	local key="$1" want="$2" got
	got=$(tmux -L "$socket" list-keys -T prefix 2>/dev/null | awk -v k="$key" \
		'$0 ~ ("-T prefix " k " ") { for (i=5; i<=NF; i++) printf "%s ", $i }' | sed 's/ *$//')
	if printf '%s' "$got" | grep -qF -- "$want"; then
		pass "prefix $key → $want"
	else
		bad "prefix $key → 期望含「$want」，实际「${got:-未绑定}」"
	fi
}

expect h   'select-pane -L'
expect j   'select-pane -D'
expect k   'select-pane -U'
expect l   'select-pane -R'
expect Tab 'last-window'
expect v   'clip-path 1'
expect V   'clip-path 2'
expect y   'clip-pick'

tmux -L "$socket" kill-server 2>/dev/null
rm -rf "$repo_dir"/bin/__pycache__

printf '\n'
if [ "$fail" = 0 ]; then
	printf '\033[32m全部通过\033[0m\n'
else
	printf '\033[31m存在失败项，见上\033[0m\n'
fi
exit "$fail"
