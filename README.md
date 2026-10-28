# tmux-config

一套面向 **「macOS 终端经 SSH 连 Ubuntu，用 tmux 保持长会话」** 场景的 tmux 配置。
核心是：vim 风格切窗格（`prefix + hjkl`）、左侧主窗格 + 右侧堆叠的自动布局、
以及把 macOS 剪贴板里的图片路径一键敲进 AI 提示符。

```
OS:     Ubuntu (server)  ← ssh ←  macOS (Ghostty / kitty)
tmux:   3.6 实测（>= 3.3 可用，推荐 >= 3.5）
```

## 目录结构

```
tmux-config/
├── tmux.conf                 # 主配置，软链到 ~/.tmux.conf
├── install.sh                # 安装脚本（软链 / 复制 / dry-run）
├── check.sh                  # 本地自检（语法 / 解析 / 绑定核对）
└── bin/                      # 被配置调用的辅助脚本，软链到 ~/.local/bin
    ├── clip-path             # 插入第 N 新的图片路径（prefix v / V）
    ├── clip-pick             # fzf 弹窗挑图（prefix y）
    ├── clip-clean            # 清理超期图片（cron 每 30 分钟）
    ├── extkeys-check         # 扩展键链路自检（Shift+Enter 是否可用）
    ├── clip-show             # Kitty 协议高清看图（实测未通，仅存档）
    ├── tmux-image            # clip-show 的 DCS 透传包装器（仅存档）
    └── tmux-focus-style      # 非活动窗格变暗（未绑定，可选）
```

## 安装

```bash
git clone https://github.com/OsborneWang/tmux-config.git
cd tmux-config
./install.sh --dry-run   # 先看要做什么
./install.sh             # 软链安装（已有真实文件会自动备份成 *.bak.<时间戳>）
```

`--copy` 改为复制安装；`--force` 覆盖已有文件且不备份。

安装后：

- `~/.tmux.conf` → 仓库里的 `tmux.conf`
- `~/.local/bin/<脚本>` → 仓库里的 `bin/<脚本>`（确认 `~/.local/bin` 在 `PATH` 里）

脚本依赖：`fzf`、`chafa`、`python3`、以及 `ncurses-term`（提供 `tmux-256color` terminfo）。

### 改完先自检

```bash
./check.sh
```

依次检查：脚本语法（sh/bash/python）、shellcheck（装了才跑）、
`tmux.conf` 能否被一个干净的 server 完整解析、以及 `hjkl / Tab / v / V / y`
这几条关键绑定是否真的生效。全通过退出码为 0，可当作提交前的门禁。

### 首次生效需要重连一次

`terminal-features`（extkeys）、`extended-keys` 等选项只在 **client 建立连接时** 下发给终端，
`source-file` / `refresh-client` 都无法补发：

```bash
Ctrl+b d          # detach（会话不中断）
tmux attach
```

校验：

```bash
tmux info | grep Eneks      # 应显示 Eneks: (string) \033[>4;2m
extkeys-check               # 新窗格里跑，按一下 Shift+Enter，看是否 PASS
```

## 快捷键

前缀键保持默认的 **`Ctrl+b`**。

### 自定义绑定

| 按键 | 动作 | 说明 |
|---|---|---|
| `prefix h/j/k/l` | 切到左/下/上/右窗格 | 支持连按（`-r`），与默认方向键并存 |
| `prefix Tab` | 回到上一个窗口 | 原 `prefix l` 的位置，因 `l` 被切窗格占用 |
| `prefix Enter` | 竖向拆分窗格 | 继承当前工作目录 |
| `prefix =` | 主窗格收窄到 20% + 聚焦右上 | 配合 `main-vertical` 布局 |
| `prefix -` | 主窗格放宽到 80% + 聚焦主窗格 | 同上 |
| `prefix v` | 插入最新一张图片路径 | 用于让 AI 读图 |
| `prefix V` | 插入第 2 新的图片路径 | 补引用上一张 |
| `prefix y` | fzf 弹窗挑图（Tab 多选） | chafa 字符画预览 |
| `Ctrl+z` | 当前窗格最大化 / 还原 | **无需前缀**（root 表） |
| copy-mode `Enter` | 复制选中内容并退出复制模式 | 配合 `set-clipboard on` 直写 macOS 剪贴板 |

### 覆盖掉的默认绑定

| 键 | 默认行为 | 现在 |
|---|---|---|
| `prefix l` | `last-window` | 切右侧窗格（`last-window` 已挪到 `prefix Tab`） |
| `prefix =` | `choose-buffer -Z` | 主窗格宽度 20%（需要选择粘贴缓冲区时用 `prefix :choose-buffer`） |
| `prefix -` | `delete-buffer` | 主窗格宽度 80%（同上，`prefix :delete-buffer`） |
| copy-mode-vi `Enter` | `copy-pipe-and-cancel` | `copy-selection-and-cancel` |

其余默认绑定全部保留：`c n p d % " { } 方向键 z q o s w x t 0-9 M-1~5`、
`resize-pane` 的 `prefix C-方向键`（1 行）与 `prefix M-方向键`（5 行）等。

## 关键选项与取舍

| 选项 | 值 | 原因 |
|---|---|---|
| `extended-keys` | `on` | tmux 3.3 起默认 `off`，会把 Shift/Ctrl/Alt+Enter 折叠成普通 Enter，导致 pi、nvim 无法用 Shift+Enter 换行 |
| `terminal-features` | `+xterm-ghostty:extkeys`、`+xterm-kitty:extkeys` | 只开开关不够，tmux 还需知道**外层终端**支持扩展键，才会向其请求 |
| `extended-keys-format` | `csi-u` | 仅此格式能把 Shift+Enter 编码成清晰的 `ESC[13;2u`；pi 启动时会校验此项 |
| `set-clipboard` | `on` | 3.2 起默认 `external`，不向终端发 OSC 52，复制不会进 macOS 剪贴板 |
| `allow-passthrough` | `on` | 允许 nvim / pi / chafa 直接向外层终端发转义序列与图片协议 |
| `mouse` | `on` | 拖选由 tmux 接管，松手即写入系统剪贴板（需要终端原生选择时按住 Shift 拖） |
| `history-limit` | `50000` | 默认 2000 行，长会话回溯不够 |
| `focus-events` | `on` | 供 nvim、pi 感知失焦/聚焦 |
| `main-pane-width` | `20%` | 配合 `after-split-window` 钩子强制 `main-vertical` 布局 |

**刻意没有写**（这些值 tmux 3.5/3.6 已与所需一致，写出来只是噪音，配置里以注释形式留了说明）：
`default-terminal`（3.5+ 默认 `tmux-256color`）、`escape-time`（3.6 默认 10ms）、`mode-keys`（3.6 默认 `vi`）。
在旧版 tmux 上运行时，把 `tmux.conf` 里对应的注释行取消即可。

## 辅助脚本

| 脚本 | 触发方式 | 作用 |
|---|---|---|
| `clip-path [n]` | `prefix v` / `prefix V` | 把 `~/.clip/inbox` 里第 n 新的 png 绝对路径 `send-keys` 到当前窗格 |
| `clip-pick` | `prefix y` | `display-popup` + fzf 选图，Tab 多选，一次插入多个路径 |
| `clip-clean` | cron | 删除超过 `CLIP_KEEP_MINUTES`（默认 1440）的图片，顺带清理 `latest.png` |
| `extkeys-check` | 手动 | 模拟程序发 `ESC[>4;2m`，判定 Shift+Enter 到达时是 `ESC[13;2u` 还是被吃成 `0d` |
| `clip-show` | 未绑定 | 用 `chafa --format=kitty` + `tmux-image` 走 DCS 透传显示真图 |
| `tmux-focus-style` | 未绑定 | 遍历窗格给非活动窗格套 `dim` 样式，样式可用 `@focus-active-pane-style` / `@focus-inactive-pane-style` 覆盖 |

### 图片链路（Linux 侧只负责后半段）

```
macOS: 截图/复制 → clipsync  →  ssh  →  Ubuntu: ~/.clip/inbox/<时间戳>.png
                                              ↓
                            clip-clean 定期清理（cron，默认 24h）
                                              ↓
                     prefix v / V / y → 路径敲进 pi 提示符 → 回车让 AI 读图
```

文件名是同步时间戳、内容不可覆盖，所以同一轮对话里可以先后引用多张不同的图。
macOS 侧的 `clipsync` 不在本仓库内。

## 已知限制

- **`clip-show` / `tmux-image` 在 Ghostty + tmux 下不出图**：DCS 透传未生效，只有 chafa 字符画可用。
  脚本保留备查、未绑定按键。想高清看图：用 `prefix v` 取到路径后用 `yazi` 打开，或直接 `yazi ~/.clip/inbox`。
- **`terminal-features` 按终端全名精确声明**（`xterm-ghostty`、`xterm-kitty`）。
  换用其他终端（如 iTerm2、Alacritty 的新版本）时，需要自行追加对应条目。
- **`prefix =` / `prefix -` 覆盖了 `choose-buffer` / `delete-buffer`**，
  偶尔要选粘贴缓冲区时用 `prefix :choose-buffer`。
- **`after-split-window` 钩子会在每次拆窗时重排 `main-vertical`**，
  手动 `resize-pane` 的宽度会被重置；想固定宽度请改 `main-pane-width`。

## 回滚

安装脚本会把被替换的文件备份成 `*.bak.<时间戳>`，直接改回即可：

```bash
mv ~/.tmux.conf.bak.20261028153000 ~/.tmux.conf
tmux source-file ~/.tmux.conf
```

（若已按默认方式装了软链，更直接的回滚是：`rm ~/.tmux.conf`，再把仓库 `tmux.conf` 拷回去。）

## 许可

[MIT](LICENSE)。

需要提醒的是：这份配置是围绕个人工作习惯调出来的（Ghostty/kitty + SSH + 中文注释），
照搬未必舒服。fork 后建议先读 `tmux.conf` 里的注释再动手改 —— 里面的“为什么”比“是什么”更有参考价值。
