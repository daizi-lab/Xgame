# 战略家 (Zhanlvejia) - Space Strategy War Remake (Xgame)

[![Godot](https://img.shields.io/badge/Godot-4.7-blue.svg?logo=godot-engine&logoColor=white)](https://godotengine.org)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux-brightgreen.svg)]()
[![Status](https://img.shields.io/badge/Status-Beta-orange.svg)]()

《战略家 (Zhanlvejia)》是一款基于 **Godot Engine 4.7** 开发的多人联机实时太空策略沙盒游戏。玩家可以在随机生成的星区图中发展星球经济、在蓝图设计器中个性化定制装载各种武器防具的战舰、组建混合舰队并在星道上进行移动调配、与其他玩家或敌方AI在太空战役中一决雌雄。

---

## 🌌 核心特色 (Key Features)

1. **随机星区生成 (Procedural Galaxy Map)**
   - 动态生成拥有 **100 个** 独立命名星系的星区，通过最小生成树 (MST) 算法物理碰撞检测生成连通星路。
   - 界面全新升级为**科幻 HUD 风格**，深海透明毛玻璃搭配霓虹青（Cyan）外发光描边圆角，完全支持低分辨率滚动自适应防截断。

2. **战舰设计器 (Blueprint Designer)**
   - **4 大船体选择**（护卫舰、驱逐舰、巡洋舰、战列舰），以横向卡片分段按钮（Segmented Cards）进行直观指标对比。
   - 支持插槽装配武器、防具及辅助组件。集成 **Reactor 反应堆电力载重平衡校验**。
   - **图标 1:1 等比防拉伸布局**，组件和已装配卡片按武器/防御/辅助分别以青蓝/绿/橙主题色分类高亮展示。

3. **星球基础设施与十槽位建设 (Infrastructure & Slots)**
   - 行星提供 **10 个自由基建槽位**（支持金属矿、晶体矿、重氢合成器、太阳能电站、造船厂建设与升级）。
   - **自动托管机制 (Auto-Manage)**：支持“均衡发展”、“经济优先”和“军事战备”三种托管运行目标，后台由托管决策引擎驱动自适应造船及基建。
   - 独立电网负载机制，若电网过载则该星球产出按比例进行功率衰减，避免老版直接死锁归零的问题。

4. **回合制战术太空战役 (Tactical Combat Simulator)**
   - 命中率、护盾重联、装甲吸收、结构值破坏的分层计算战斗演示。
   - 根据两军总速度与指挥官先攻属性动态决定**每回合开火先手顺序 (Initiative)**。
   - 同名武器在开火阶段进行去重判定，极大精简交火日志。
   - **全屏模态战局结算弹窗 (Settlement Panel)**：以呼吸闪烁的胜负色（胜利青蓝/失败红橙）动态结算展示战场残骸金属等资源回收清单。

5. **多人联机与服务端权威同步 (Server-Authoritative Multiplayer)**
   - 基于 `ENetMultiplayerPeer` 建立的局域网/广域网多人独立大厅，支持准备就绪判定和多房间并发对战。
   - 采用**服务端权威 Tick 模拟**与**全量二进制快照快慢广播 (Snapshot Replication)**（使用 `var_to_bytes_with_objects`）。
   - 客户端行为完全 RPC 管道化，服务端进行严格的所有权和造船/基建开销安全校验。

6. **智能化敌方AI扩张 (Intelligent Expansion AI)**
   - 并行驱动的多房间 PvE 决策。AI 根据所持星系军民发展状况（库存战舰规模是否大于8艘）动态切换建造或发展优先级。
   - 智能寻找空槽位，匹配行星上缓存的自定义或初始设计蓝图进行飞船组装，集结大规模舰队对外侵略扩张。

---

## 📂 项目结构说明 (Directory Structure)

```
zhanlvejia/
├── project.godot                # Godot 项目配置文件
├── export_presets.cfg           # 导出 presets (Windows 客户端、PCK包等)
├── .gitignore                   # 精细化 Git 过滤，自动忽略大二进制与文本日志
├── assets/                      # 全息素材、星体、自定义战舰侧视图及建筑图标 PNG
├── src/                         # 核心源码
│   ├── core/                    # 数据层与核心模拟逻辑 (Model-Controller)
│   │   ├── data/                # 基础配表数据 (武器、船体属性)
│   │   ├── models/              # 数据模型类 (Resource 二进制可反序列化类)
│   │   │   ├── planet.gd        # 星球模型 (资源产出、升级建造队列、机库存储)
│   │   │   ├── fleet.gd         # 舰队模型 (包含舰船集合、路径BFS寻路、遭遇战状态)
│   │   │   ├── galaxy_node.gd   # 星系节点模型 (控制权、托管参数、驻扎舰队)
│   │   │   └── ship_design.gd   # 自定义蓝图设计数据 (组件配装、电力校验)
│   │   ├── simulator/           # 模拟器
│   │   │   └── battle_simulator.gd # 战斗计算引擎 (先手排序、去重开火、残骸回收)
│   │   └── managers/            # 时钟单例与控制类
│   │       ├── galaxy_manager.gd   # 时序 Tick 驱动、玩家/AI 托管决策引擎
│   │       └── network_manager.gd  # RPC 指令处理、二进制快照序列化与同步单例
│   └── ui/                      # 视图展现层 (View)
│       ├── main_menu.tscn       # 主菜单 (单人/多人大厅入口)
│       ├── network_lobby.tscn   # 广域网多人大厅 (房间密码、人数、准备就绪判定)
│       ├── main_game_hub.tscn   # 游戏主看板 (顶部资源降频刷新、标签切换)
│       ├── galaxy_map_ui.tscn   # 宇宙星系图 UI (科幻 HUD 面板、Scroll防溢出包装)
│       ├── galaxy_map_draw.gd   # 地图平移拖拽、星系节点与连通星路动态画布绘制
│       ├── planet_base_ui.tscn  # 基地建造卡片面板 (升级与拆除防误触垂直对齐)
│       ├── ship_designer_ui.tscn# 战舰蓝图设计器 (分段船体卡片、图标1:1防失真)
│       ├── shipyard_ui.tscn     # 造船厂面板 (队列进度条倒计时)
│       └── combat_view_ui.tscn  # 战斗观战画面 (圆角发光武器插槽、结算弹窗)
└── scratch/                     # 自动化测试脚本与部署脚本
    ├── test_map_ui.gd           # 星图 UI 场景实例化编译测试
    ├── run_godot_debug.py       # 无头模式加载与 STDERR 错误日志导出脚本
    └── compile_and_copy_client.py  # 快速编译 Godot Windows 独立客户端程序
```

---

## 🚀 快速开始 (Quick Start)

### 运行环境
- **Godot Engine 4.7-stable** 或更高版本。

### 启动客户端 (Windows)
在发布包或项目根目录中，直接运行编译完成的程序：
- `运行程序/zhanlvejia.exe` (或 `zhanlvejia.exe`)
- 调试版本控制台运行器：`运行程序/zhanlvejia.console.exe`

### 运行 headless 多人联机服务端 (Linux)
在服务器上传最新的 `.pck` 资源包以及 Godot 无头运行器，使用以下命令启动常驻服务：
```bash
./Godot_v4.7-stable_linux.x86_64 --headless --main-pack zhanlvejia.pck
```
*(多人联机大厅默认连接至 Jakarta 联机服务器：`8.215.89.194:9999`)*

---

## 🛠️ 测试与验证 (Verification Tests)

您可以使用 Godot 无头命令测试相关 UI 场景的解析是否正常（确保没有空指针和编译错误）：
```bash
godot --headless -s res://scratch/test_map_ui.gd
```
调试运行日志会自动生成在 `scratch/godot_run_log.txt` 中。