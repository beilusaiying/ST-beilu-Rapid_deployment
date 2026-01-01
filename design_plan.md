# 项目重构设计方案：SillyTavern 移动端管理工具 (Termux版)

## 1. 项目目标

基于原“随行”项目进行二次开发，精简冗余功能，专注于以下核心需求：

1. **SillyTavern (酒馆)**: 稳定安装、启动、**修复更新问题**。
2. **gcli2api**: 一键安装、运行（用于获取 Google API）。
3. **轻量化**: 移除不常用的模块，优化菜单逻辑。

## 2. 目录结构设计

保持原有的模块化结构，但进行清理：

```text
project_root/
├── install.sh              # 一键安装脚本 (环境检查 + 拉取核心代码)
└── manager/                # 核心目录 (原 eralink)
    ├── core.sh             # 主程序 (菜单逻辑)
    ├── conf/               # 配置文件
    │   └── settings.conf   # 保存用户设置 (代理、自动启动等)
    └── modules/            # 功能模块
        ├── sillytavern/
        │   ├── functions.sh # ST的核心逻辑 (安装/启动/更新)
        │   └── menu.conf    # ST的菜单配置
        └── gcli2api/
            ├── functions.sh # gcli2api的核心逻辑
            └── menu.conf    # gcli2api的菜单配置
```

## 3. 核心功能改进方案

### A. SillyTavern 更新逻辑增强 (解决更新失败问题)

原脚本仅使用 `git pull`，容易因本地文件变动或网络问题导致失败。新方案将引入“智能更新”与“强制更新”：

1. **智能检测**: 检查 `.git` 目录完整性。
2. **常规更新**: 尝试 `git pull --rebase`。
3. **强制重置 (Fix)**:
    * 当常规更新失败时，提供选项执行：

        ```bash
        git fetch --all
        git reset --hard origin/release  # 强制重置到远程最新版
        npm install                      # 重新安装依赖
        ```

    * *注意：会提示用户这会覆盖本地修改的核心文件（不影响数据文件如聊天记录）。*
4. **分支切换**: 支持在 `release` (稳定版) 和 `staging` (测试版) 之间切换。

### B. gcli2api 集成方案

1. **依赖管理**: 在 `install.sh` 中增加 `python`, `pip`, `openssl` 等 Termux 依赖。
2. **安装逻辑**:
    * 拉取仓库: `https://github.com/su-kaka/gcli2api`
    * 安装 Python 依赖: `pip install -r requirements.txt`
3. **运行逻辑**: 后台运行或前台运行选项。

### C. 菜单与交互优化

* **主菜单**: 直接展示 SillyTavern 和 gcli2api 的状态（运行中/停止/版本号）。
* **一键修复**: 在主菜单增加“环境修复”选项，用于重装 nodejs/python 依赖。

## 4. 待确认事项

* **项目名称**: 你希望这个新脚本叫什么名字？（默认暂定为 `ST-Manager`）
* **gcli2api 仓库**: 确认使用 `su-kaka/gcli2api` 还是其他 fork 版本？

## 5. 执行步骤

1. 创建基础目录结构。
2. 编写 `install.sh`。
3. 编写 `core.sh` 框架。
4. 实现 `sillytavern` 模块（含强制更新逻辑）。
5. 实现 `gcli2api` 模块。
