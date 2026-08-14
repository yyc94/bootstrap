# Pop!_OS 新电脑环境复现

这套文件用于在一台只有 `sh`/`bash` 的全新 Pop!_OS 电脑上，恢复当前的终端和开发环境。它会安装所选软件，部署 zsh、Neovim、Zellij、Git、Glow、Cheat、Neomutt 等配置，并初始化 zinit 和 Neovim 插件。

## 1. 把目录带到新电脑

将整个 `bootstrap-new-machine` 目录放到新电脑。可以使用 U 盘、局域网 `scp`，或先将它放进自己的私有 Git 仓库。不要只传 `install.sh`，脚本还依赖同目录下的配置和 `dotfiles/`。

例如目录位于 `~/bootstrap-new-machine`：

```sh
cd ~/bootstrap-new-machine
```

安装器使用 POSIX `sh`，新电脑无需预装 zsh。

## 2. 选择需要的软件

编辑 [packages.conf](packages.conf)。规则很简单：

- 行首没有 `#`：安装。
- 行首有 `#`：跳过。
- 行尾注释说明用途，通常不需要改动。

各分区的安装方式不同：

| 分区 | 安装方式 | 说明 |
| --- | --- | --- |
| `apt:*` | `apt-get` | Pop!_OS/Ubuntu 仓库软件；仓库中不存在的项会跳过并汇总 |
| `external:versioned` | 官方 release | 固定版本软件；当前启用 nvim、zellij、cmake 和 herdr |
| `external:optional` | 官方安装器 | rustup、Miniconda、xmake 等可选工具 |
| `npm:global` | `npm install -g` | 必须先选择 Node.js |
| `cargo:global` | `cargo install` | 必须先选择 rustup |
| `manual:local-and-private` | 仅盘点 | 公司内部工具、本地项目产物或来源未知的软件；取消注释也不会自动安装 |

对于 Node.js、Go 和 Cheat，如果希望复现当前版本，优先取消 `[external:versioned]` 中对应行的注释。例如：

```conf
node 22.14.0
go 1.24.2
cheat 4.4.2
```

`external:versioned` 会读取实际命令的版本并做精确比较。版本不同就从官方固定版本地址安装到 `~/.local/opt` 或 `~/.local/bin`；安装结束后再次校验，不一致时脚本以非零状态退出。Herdr 还会使用官方发布清单中的 SHA-256 校验二进制。

目前除 Herdr 同时支持 Linux x86_64/aarch64 外，其他固定版本安装规则只支持 Linux x86_64。如果新电脑是 ARM，需要关闭不支持的项目或补充对应架构的下载地址。

`packages.conf` 是面向人的顶层软件选择表，不会把每个自动依赖库都平铺进去。当前机器的完整原始快照位于 `inventory/`：apt 手动标记包、带版本 apt 包、Conda 两个环境、PyPI 包、Ruby gems、npm/cargo 全局包和 PATH 中的本地可执行文件都分别保存。审计口径和不能自动复现的项目见 [inventory/audit-summary.md](inventory/audit-summary.md)。

## 3. 设置换源和身份

编辑 [settings.conf](settings.conf)：

- pip 清华源默认开启。
- apt、npm、Rust 和 Conda 镜像默认注释，需要时取消注释。
- `GIT_USER_NAME` 和 `GIT_USER_EMAIL` 默认不设置，建议在新电脑上填写自己的身份。
- `NVIM_LAZY_SYNC=1` 表示安装后自动同步 Neovim 插件；网络不稳定时可暂时设为 `0`。

谨慎启用 `APT_MIRROR`。脚本只在 `/etc/apt/sources.list` 存在时改写其中的 Ubuntu 软件源，并先创建带时间戳的备份；Pop!_OS 自己的源文件不会被写入。较新的系统若使用 deb822 `.sources` 文件，此选项不会生效，应保留系统默认源或手动配置。

## 4. 检查私密配置

脚本包中不包含 SSH/GPG 私钥、邮箱密码、令牌或天气 API Key。

Neomutt 使用的是脱敏模板。安装完成后，需要编辑：

```sh
chmod 600 ~/.config/neomutt/private.muttrc
nvim ~/.config/neomutt/private.muttrc
```

天气脚本需要环境变量 `AMAP_WEATHER_KEY`。安装后的 `.zshenv` 会自动读取 `~/.config/bootstrap/private.env`，可以这样配置：

```sh
mkdir -p ~/.config/bootstrap
nvim ~/.config/bootstrap/private.env
chmod 600 ~/.config/bootstrap/private.env
```

文件内容为：

```sh
export AMAP_WEATHER_KEY='你的 Key'
# 可选，深圳默认是 440300
export AMAP_CITY_ADCODE='440300'
```

这个私有文件不在 bootstrap 包中，不要提交到 Git。

## 5. 执行一键安装

先确保网络正常，然后运行：

```sh
sh install.sh
```

过程中会要求输入 `sudo` 密码，也可能由 `chsh` 再次要求密码。安装器会依次完成：apt 软件、dotfiles、镜像设置、Git 身份、zinit、固定版本工具、可选工具、npm/cargo 全局包、Neovim 插件同步、默认 shell 和版本校验。

也可以临时用参数启用部分外部工具，无需修改 `packages.conf`：

```sh
sh install.sh --with-rust --with-miniconda --with-xmake
```

可用参数：`--with-rust`、`--with-go`、`--with-miniconda`、`--with-node`、`--with-cheat`、`--with-xmake`、`--no-chsh`。

注意：`--with-go` 使用 apt 的 Go，不保证与当前版本一致；要固定版本请使用 `[external:versioned]`。`--with-node` 只给出提示，不会安装旧版 apt Node.js，同样应使用 `[external:versioned]`。

## 6. 安装后首次启动

执行：

```sh
exec zsh
```

首次进入 zsh 时，zinit 可能继续下载 Powerlevel10k、补全、自动建议、语法高亮、fzf-tab 等插件。首次进入 Neovim 时，lazy.nvim/Mason 也可能继续下载插件和 LSP。

建议检查：

```sh
echo "$SHELL"
zsh --version
nvim --version
zellij --version
cmake --version
git config --global --list
```

如果默认 shell 尚未改变，注销并重新登录；或者手动执行：

```sh
chsh -s "$(command -v zsh)"
```

## 备份、重跑和恢复

脚本部署 dotfiles 并覆盖同名配置文件前，会把原文件移动到：

```text
~/.bootstrap-backup-YYYYmmdd-HHMMSS/
```

配置目录采用合并方式。例如安装 `~/.config/nvim` 不会删除 `~/.config` 中其他应用的配置；已有的 Neomutt 私密文件也会保留。脚本可以重跑，但每次重跑都会重新部署本项目管理的配置，并为被替换的同名文件生成新备份。

需要恢复时，从最近的备份目录把对应文件移回原位置即可。脚本不会复制或删除 SSH/GPG 密钥、浏览器资料、项目目录和缓存。完整覆盖范围见 [config-coverage.md](config-coverage.md)。

## 常见问题

- `apt-get update` 失败：先恢复默认源，或检查 `APT_MIRROR` 是否适配当前 Pop!_OS 的 Ubuntu 基础版本。
- GitHub/官方 release 下载失败：检查代理/DNS 后直接重跑，已正确安装的固定版本会跳过。
- `Lazy sync failed`：进入 Neovim 后执行 `:Lazy sync`。
- zsh 插件不完整：在网络正常时重新打开 zsh，或执行 `zinit update`。
- 某个 apt 包未找到：安装末尾会列出名称；这通常是 Pop!_OS 版本仓库差异，不会阻止其他软件安装。
- `chsh` 失败：确认 `/etc/shells` 中包含 `command -v zsh` 的输出，再手动运行 `chsh`。
