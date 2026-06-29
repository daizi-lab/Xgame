# Zhanlvejia 功能文档索引

欢迎阅读 **战略家 (Zhanlvejia)** 的技术功能文档。本目录包含核心玩法系统的详细架构文档、算法、数学公式以及网络 API。

---

## 🌌 功能矩阵与开发状态

以下是核心功能列表、它们的实现状态以及指向其模块化设计规范的链接：

| # | 功能名称 | 文档链接 | 核心技术 | 开发状态 |
| :-: | :--- | :--- | :--- | :-: |
| 1 | **程序化星系图** | [galaxy_map.md](file:///d:/Project/TsGame/zhanlvejia/docs/features/galaxy_map.md) | 最小生成树 (Prim 算法)、BFS 路径规划、2D 画布平移绘制 | **已完成** |
| 2 | **舰船设计器** | [ship_designer.md](file:///d:/Project/TsGame/zhanlvejia/docs/features/ship_designer.md) | 约束验证、电网负载、1:1 比例预览 | **已完成** |
| 3 | **行星基础设施** | [planet_management.md](file:///d:/Project/TsGame/zhanlvejia/docs/features/planet_management.md) | 10槽位数组网格、子刻度 (Sub-Tick) 事件循环、效率缩放曲线 | **已完成** |
| 4 | **战术战斗模拟器** | [combat_simulator.md](file:///d:/Project/TsGame/zhanlvejia/docs/features/combat_simulator.md) | 回合先攻权、武器类型克制、残骸回收 | **已完成** |
| 5 | **多玩家与服务器同步** | [multiplayer_sync.md](file:///d:/Project/TsGame/zhanlvejia/docs/features/multiplayer_sync.md) | ENet 大厅、二进制快照复制、RPC 发送方验证 | **已完成** |
| 6 | **自动管理与扩张 AI** | [expansion_ai.md](file:///d:/Project/TsGame/zhanlvejia/docs/features/expansion_ai.md) | 自动化优先级决策树、驻军缩放曲线 | **已完成** |

---

## 🛠️ 验证测试与构建

您可以使用无头运行器工具来验证所有 UI 场景是否能够解析并编译通过（避免空指针和节点路径断裂），而无需完整编译。

### 运行无头集成测试：
```bash
# 验证资源计算和事件循环
godot --headless -s res://scratch/test_resource_integration.gd

# 验证对抗性网络输入与边界安全检查
godot --headless -s res://scratch/test_adversarial_1.gd

# 验证房间死锁和连接泄露
godot --headless -s res://scratch/test_adversarial_2.gd
```
*请确保 `godot` 已添加到您的环境变量 PATH 中，或者将其替换为指向您的 Godot 4.7 可执行文件的绝对路径。*

---

## 📁 文档模板与标准
本目录中的每个文档都按照以下部分进行组织：
1. **说明与用户流程 (Description & User Flow)**：玩家交互的高级概述。
2. **架构与代码入口 (Architecture & Code Entry Points)**：控制器/管理器单例、资源数据模型和视图场景/脚本的映射 (MVC 表示)。
3. **技术设计与算法 (Technical Design & Algorithms)**：精确的数学方程、数据库结构、网络 RPC 接口和验证规则。
4. **开发状态 (Development Status)**：当前状态、最近的更新以及已知的技术债务。
