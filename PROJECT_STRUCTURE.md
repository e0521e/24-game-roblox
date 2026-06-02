# 24-Game-Roblox 项目结构文档

## 项目概述

这是一个基于 **Roblox** 的游戏项目，使用 **Luau** (严格模式) 开发，采用 **Knit** 框架的客户端-服务器架构。

---

## 技术栈

| 项目 | 说明 |
| ---- | ---- |
| 语言 | Luau (strict mode) |
| 框架 | Knit v1.7.0 |
| UI 组件 | Component v2.4.8 |
| 包管理器 | Wally |
| 构建工具 | Rojo v7.6.1 |
| 工具管理 | Aftman |
| CI/CD | GitHub Actions |

---

## 目录结构

```txt
E:\game26\24-game-roblox\
│
├── .github\
│   └── workflows\
│       └── build.yml                    # GitHub Actions CI 构建流程
│
├── Packages\
│   ├── _Index\                          # Wally 解析的依赖源码
│   │   ├── 1foreverhd_topbarplus@3.4.0\ # 顶部导航栏组件
│   │   ├── csqrl_sift@0.0.11\           # 集合/字典工具库
│   │   ├── evaera_promise@4.0.0\        # Promise 实现
│   │   ├── howmanysmall_janitor@1.18.3\ # 资源清理管理
│   │   ├── howmanysmall_typed-promise@4.0.6\ # 类型化 Promise
│   │   ├── ryanlua_satchel@1.4.1\       # 状态管理
│   │   ├── sleitnick_comm@1.0.1\        # 远程通信
│   │   ├── sleitnick_component@2.4.8\   # UI 组件系统
│   │   ├── sleitnick_input@2.3.0\       # 输入处理
│   │   ├── sleitnick_knit@1.7.0\        # 游戏框架
│   │   ├── sleitnick_loader@2.0.0\      # 资源加载器
│   │   ├── sleitnick_net@0.2.0\         # 网络中间件
│   │   ├── sleitnick_observers@0.5.0\   # 观察者模式
│   │   ├── sleitnick_option@1.0.5\      # Option 类型
│   │   ├── sleitnick_shake@1.1.0\       # 屏幕震动效果
│   │   ├── sleitnick_signal@2.0.3\      # 信号/事件
│   │   ├── sleitnick_symbol@2.0.1\      # Symbol 实现
│   │   ├── sleitnick_table-util@1.2.1\  # 表工具函数
│   │   ├── sleitnick_timer@1.1.2\       # 定时器
│   │   ├── sleitnick_tree@1.1.0\        # 树数据结构
│   │   ├── sleitnick_trove@1.8.0\       # 对象生命周期管理
│   │   └── sleitnick_wait-for@1.0.0\    # 条件等待工具
│   │
│   └── *.lua                            # Rojo 映射文件 (指向 _Index 中的包)
│
├── src\
│   ├── client\                          # 客户端代码
│   │   ├── init.client.luau             # 客户端入口
│   │   └── Controllers\                 # Knit 客户端控制器
│   │       ├── ExampleController.luau   # 示例控制器
│   │       ├── GameController.luau      # 游戏控制器
│   │       └── PlayerDataController.luau # 玩家数据控制器
│   │
│   ├── server\                          # 服务端代码
│   │   ├── init.server.luau             # 服务端入口
│   │   └── Services\                    # Knit 服务端服务
│   │       ├── ExampleService.luau      # 示例服务
│   │       ├── GameService.luau         # 游戏服务
│   │       ├── LobbyService.luau        # 大厅服务
│   │       ├── PlayerDataService.luau   # 玩家数据服务
│   │       └── TowerService.luau        # 塔防服务
│   │
│   └── shared\                          # 共享代码
│       ├── Configuration\
│       │   └── Config.luau              # 共享配置
│       ├── constants\                   # 游戏数据常量
│       │   ├── GamePasses.luau          # 通行证配置
│       │   ├── Items.luau              # 物品配置
│       │   ├── LobbyConfig.luau         # 大厅配置
│       │   ├── OnlineRewards.luau       # 在线奖励配置
│       │   ├── PlayerLevels.luau        # 玩家等级配置
│       │   ├── Products.luau            # 产品配置
│       │   └── Questions.luau           # 题库配置
│       ├── DataStructures\              # 数据结构/工具
│       │   ├── Base64.luau              # Base64 编解码
│       │   ├── EventBus.luau            # 事件总线
│       │   ├── ObjectPool.luau          # 对象池
│       │   ├── PlayerData.luau          # 玩家数据结构
│       │   ├── U3.luau                  # 3D 向量/数学工具
│       │   └── Utils.luau               # 通用工具函数
│       └── types\                       # 类型定义 (预留)
│
├── .gitignore                           # Git 忽略规则
├── .luaurc                              # Luau 语言服务器配置
├── aftman.toml                          # Aftman 工具管理器配置
├── default.project.json                 # Rojo 项目清单
├── GameConfig.xlsx                      # Excel 游戏配置 (gitignore)
└── wally.toml                           # Wally 包清单
```

---

## 架构说明

### Rojo 映射关系

| 文件系统路径 | Roblox DataModel 位置 |
| ----------- | -------------------- |
| `Packages/` | `ReplicatedStorage.Packages` |
| `src/shared/` | `ReplicatedStorage.Shared` |
| `src/server/` | `ServerScriptService.Server` |
| `src/client/` | `StarterPlayer.StarterPlayerScripts.Client` |

### Knit 架构

```txt
┌─────────────────────────────────────────┐
│ 客户端 (Client)                          │
│  ├── Controllers/                        │
│  │   ├── GameController                  │
│  │   └── PlayerDataController            │
│  └── init.client.luau                    │
├─────────────────────────────────────────┤
│ 通信层 (Comm / Net)                      │
├─────────────────────────────────────────┤
│ 服务端 (Server)                          │
│  ├── Services/                           │
│  │   ├── GameService                     │
│  │   ├── LobbyService                    │
│  │   ├── PlayerDataService               │
│  │   └── TowerService                    │
│  └── init.server.luau                    │
├─────────────────────────────────────────┤
│ 共享层 (Shared)                          │
│  ├── Configuration, constants            │
│  ├── DataStructures                      │
│  └── types                               │
└─────────────────────────────────────────┘
```

### Wally 依赖清单 (23个包)

| 包名 | 版本 | 用途 |
| ---- | ---- | ---- |
| 1foreverhd/topbarplus | 3.4.0 | 顶部导航栏 |
| csqrl/sift | 0.0.11 | 集合/字典工具 |
| evaera/promise | 4.0.0 | Promise |
| howmanysmall/janitor | 1.18.3 | 资源清理 |
| howmanysmall/typed-promise | 4.0.6 | 类型化 Promise |
| ryanlua/satchel | 1.4.1 | 状态管理 |
| sleitnick/comm | 1.0.1 | 远程通信 |
| sleitnick/component | 2.4.8 | UI 组件 |
| sleitnick/input | 2.3.0 | 输入处理 |
| sleitnick/knit | 1.7.0 | 游戏框架 |
| sleitnick/loader | 2.0.0 | 资源加载 |
| sleitnick/net | 0.2.0 | 网络层 |
| sleitnick/observers | 0.5.0 | 观察者 |
| sleitnick/option | 1.0.5 | Option 类型 |
| sleitnick/shake | 1.1.0 | 屏幕震动 |
| sleitnick/signal | 2.0.3 | 信号系统 |
| sleitnick/symbol | 2.0.1 | Symbol |
| sleitnick/table-util | 1.2.1 | 表工具 |
| sleitnick/timer | 1.1.2 | 定时器 |
| sleitnick/tree | 1.1.0 | 树结构 |
| sleitnick/trove | 1.8.0 | 生命周期 |
| sleitnick/wait-for | 1.0.0 | 条件等待 |

---

## 配置文件说明

| 文件 | 用途 |
| ---- | ---- |
| `default.project.json` | Rojo 项目清单，定义文件到 Roblox 的映射 |
| `wally.toml` | Wally 包依赖声明 (包名: `erenjr/24-game-roblox`) |
| `aftman.toml` | 工具版本管理 (rojo 7.6.1) |
| `.luaurc` | Luau LSP 配置 (strict 模式) |
| `.gitignore` | 忽略 Roblox 模型文件、编译输出、Packages 目录 |
| `build.yml` | GitHub Actions CI 构建流水线 |

---

## 游戏功能模块

基于代码结构分析，该游戏包含以下功能模块：

1. **大厅系统** (`LobbyService`, `LobbyConfig`) - 玩家匹配与等待
2. **塔防玩法** (`TowerService`) - 核心塔防游戏逻辑
3. **24点游戏** (`Questions.luau`) - 数学答题玩法
4. **玩家数据** (`PlayerDataService`, `PlayerDataController`, `PlayerData`) - 玩家存档与数据同步
5. **游戏进程** (`GameService`, `GameController`) - 游戏流程控制
6. **商城系统** (`Products.luau`, `Items.luau`, `GamePasses.luau`) - 虚拟商品与通行证
7. **等级系统** (`PlayerLevels.luau`) - 玩家等级与进度
8. **在线奖励** (`OnlineRewards.luau`) - 在线时长奖励
