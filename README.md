# Pop!_OS 新电脑环境复现

这套文件用于在一台只有 `sh`/`bash` 的全新 Pop!_OS 电脑上，恢复当前的终端和开发环境。它会安装所选软件，部署 zsh、Neovim、Zellij、Git、Glow、Cheat、Neomutt 等配置，并初始化 zinit、zsh 插件和 Neovim 插件。

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
| `external:fonts` | Powerlevel10k 官方字体文件 | 安装 MesloLGS Nerd Font 到当前用户的字体目录 |
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
- apt 清华镜像默认开启；npm、Rust 和 Conda 镜像默认注释，需要时取消注释。
- `GIT_USER_NAME` 和 `GIT_USER_EMAIL` 配置提交身份；复制给其他用户前应改成其身份。
- `GIT_GITHUB_PROTOCOL=https` 是注册 SSH Key 前的初始回退值；验证成功后脚本会自动
  改成 `ssh`。
- `GENERATE_GITHUB_SSH_KEY=1` 会在没有现有 SSH 公钥时生成 Ed25519 密钥。
- `NVIM_LAZY_SYNC=1` 表示安装后自动同步 Neovim 插件；网络不稳定时可暂时设为 `0`。
- `CONFIGURE_GNOME_TERMINAL_FONT=1` 会把当前 GNOME Terminal profile 设置为
  `TERMINAL_FONT`；其他终端需要在其设置中选择 `MesloLGS NF`。

脚本会在安装软件前先配置 `APT_MIRROR` 并执行 `apt-get update`。它支持传统的
`/etc/apt/sources.list`、新版 Ubuntu 的 deb822 `ubuntu.sources`，以及 Pop!_OS 的
`system.sources`，修改前会创建带时间戳的备份。Pop!_OS 其他独立源文件不会被
写入；不需要换源时可注释掉 `APT_MIRROR`。

Git 的提交身份不等于远端登录凭据。默认 HTTPS 配置足以拉取脚本使用的公开仓库；
脚本会复用已有的 `id_ed25519.pub`、`id_ecdsa.pub` 或 `id_rsa.pub`；如果都不存在，
则生成 `~/.ssh/id_ed25519` 并在终端输出公钥。脚本会先自动测试 SSH，尚未注册时
提示打开 <https://github.com/settings/ssh/new> 添加公钥，并等待回车后再次验证。
验证成功后，它会自动切换全局 Git 到 SSH，并将 `GIT_GITHUB_PROTOCOL=ssh` 写回
`settings.conf`，不需要手动修改。输入 `s` 可以跳过并继续使用 HTTPS。

通过管道或 CI 非交互执行时，脚本不会等待输入，而会继续使用 HTTPS，并提示稍后
执行 `ssh -T git@github.com`。脚本不会上传、复制或打印私钥，也不会保存 GitHub
Token。

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

如果当前网络不能直连 GitHub，在同一条命令中传入标准代理环境变量；git、curl、zinit
和字体下载都会继承它们：

```sh
http_proxy=http://proxy-host:port https_proxy=http://proxy-host:port sh install.sh
```

请使用普通用户执行，不要运行 `sudo sh install.sh`。脚本只在安装 apt 包或修改 apt
源时自行调用 `sudo`；整体使用 sudo 会把 dotfiles 和用户级工具安装到 root 的 home
目录。若脚本异常退出，可用 `sh -x install.sh` 显示逐条执行轨迹。

过程中会先预认证 `sudo`，并按以下依赖顺序执行：

1. 检查完整目录、运行用户和必要权限。
2. 询问是否启用 apt 镜像，修改源并执行 `apt-get update`。
3. 安装 apt 基础包，并确认 `git`、`curl`、`tar`、`ssh-keygen` 等命令可用。
4. 备份并部署 dotfiles，然后配置 pip/Rust 基础环境。
5. 配置 Git 提交身份，生成/验证 GitHub SSH Key；验证成功后才启用 SSH 通路。
6. 安装固定版本工具、zinit 和全部 zsh 插件，并验证补全、p10k、fzf-tab、自动建议、
   语法高亮和 z.lua 均已加载。
7. 安装 MesloLGS Nerd Font、刷新字体缓存，并尽可能配置 GNOME Terminal 使用该字体。
8. 询问并安装可选工具，随后配置 npm/Conda 源和 npm/cargo 全局包。
9. 询问 Neovim 插件同步和默认 shell，最后统一做版本校验和失败汇总。

网络失败、zinit 失败或可选工具失败会给出重试/跳过选择；核心 apt 更新、基础命令缺失
仍会中止，因为继续执行会放大后续错误。交互终端会询问 apt 镜像、可选工具、SSH、
Neovim 同步和默认 shell；管道/CI 运行时自动采用安全的默认选项且不会等待输入。

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

安装脚本已经下载并检查 Powerlevel10k、补全、自动建议、语法高亮、fzf-tab 和 z.lua，
首次进入 zsh 不应再依赖插件下载。首次进入 Neovim 时，lazy.nvim/Mason 仍可能继续下载
插件和 LSP。

`.p10k.zsh` 使用 Nerd Font v3 图标。脚本会安装 Powerlevel10k 官方推荐的四种
MesloLGS NF 字体并自动配置 GNOME Terminal。对于 VS Code、Konsole、Tilix、Kitty、
WezTerm 等终端，需要在对应的 profile 中手动选择 `MesloLGS NF`；仅把字体安装到系统
并不会改变这些终端自己的字体设置。

建议检查：

```sh
echo "$SHELL"
zsh --version
zsh -ic 'print "compdef=$+functions[compdef] p10k=$+functions[p10k] fzf-tab=$+widgets[fzf-tab-complete]"'
fc-match 'MesloLGS NF'
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

如果安装后 Git 的代理、URL 映射或身份配置异常，可以一键恢复第一次运行脚本前的
`~/.gitconfig`：

```sh
sh install.sh --restore
```

`--restore-git` 与 `--restore` 等价。恢复模式不会请求 sudo、安装软件、修改 apt 源或
访问网络；它会自动选择最早的 `.bootstrap-backup-*` Git 配置，并先把当前配置保存为
`~/.gitconfig.before-bootstrap-restore-*`。如需指定某次备份：

```sh
sh install.sh --restore-git="$HOME/.bootstrap-backup-20260814-120000"
```

其他文件仍可从备份目录手动恢复。脚本不会复制或删除 SSH/GPG 私钥、浏览器资料、
项目目录和与本次安装无关的缓存。完整覆盖范围见 [config-coverage.md](config-coverage.md)。

## 一键交互清理

安装器从开始运行时就把实际新增或替换的内容写入
`~/.local/state/bootstrap-new-machine/runs/`。即使安装中途失败，账本也会保留。执行：

```sh
sh install.sh --cleanup
```

也可以使用等价参数 `--uninstall`，或者直接运行 `sh cleanup.sh`。清理必须在交互终端
中进行。每个文件、目录、apt/npm/Cargo 包、字体、终端设置、apt 源和默认 shell 都会
单独询问，默认答案是删除或恢复，直接按回车即可；输入 `n` 会保留该项。

被脚本覆盖的原文件不会直接丢弃，清理时会删除脚本部署的版本并恢复安装前备份。
apt 只删除账本确认由脚本新安装的包；原本已安装的软件即使也列在 `packages.conf` 中，
也不会被删除。apt 删除前还会执行模拟，如果会连带删除任何非脚本安装的软件，该项会
被拒绝。

成功清理的项目会立即从账本移除；即使清理本身中途退出，下次运行也会从剩余项继续。
某项被跳过或失败后，清理会停止，不再删除依赖它的更早项目。若目录中只剩用户后来
加入的内容，目录会被安全保留；清理器不会通过递归删除父目录绕过这个选择。存在未完成
的新安装记录时，也不会继续清理更早的安装记录，避免恢复顺序错误。

旧版安装器没有账本时，清理器会扫描本仓库管理的 dotfiles、zinit、固定版本工具、
Nerd Font 和已知缓存并逐项确认，同时尝试使用最早的 `.bootstrap-backup-*` 恢复文件。
旧安装的 apt 包和原登录 shell 无法可靠判断来源，因此不会猜测删除。

## 常见问题

- `apt-get update` 失败：先恢复默认源，或检查 `APT_MIRROR` 是否适配当前 Pop!_OS 的 Ubuntu 基础版本。
- GitHub/官方 release 下载失败：检查代理/DNS 后直接重跑，已正确安装的固定版本会跳过。
- `Lazy sync failed`：进入 Neovim 后执行 `:Lazy sync`。
- zsh 插件检查失败：确认 `git`、`curl`、`lua5.4` 和 `fzf` 可用，然后重新运行安装脚本；
  更新已有插件可执行 `zinit update`。
- p10k/Neovim 图标显示方框：执行 `fc-match 'MesloLGS NF'` 确认字体已注册，并在当前
  终端的 profile 中选择 `MesloLGS NF`；终端字体设置独立于桌面界面字体。
- 某个 apt 包未找到：安装末尾会列出名称；这通常是 Pop!_OS 版本仓库差异，不会阻止其他软件安装。
- `chsh` 失败：确认 `/etc/shells` 中包含 `command -v zsh` 的输出，再手动运行 `chsh`。

## 容器迁移测试

zsh 安装链路可以在全新的 Ubuntu 22.04 容器和空 HOME 中验证，不会读取或修改宿主机的
zinit、插件、字体或 dotfiles。测试会执行安装、真实 PTY 首次启动和交互清理：

```sh
sh tests/test-zsh-migration.sh
```

默认镜像是 `ubuntu:22.04`。离线环境可以指定已有的干净 Ubuntu 22.04 镜像：

```sh
BOOTSTRAP_TEST_IMAGE=your-ubuntu:22.04 sh tests/test-zsh-migration.sh
```

测试网络需要代理时，只对测试容器传入代理地址：

```sh
BOOTSTRAP_TEST_PROXY=http://proxy-host:port sh tests/test-zsh-migration.sh
```
