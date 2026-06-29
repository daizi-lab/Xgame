# 功能：程序化星系图

## 1. 说明与用户流程 (Description & User Flow)
**程序化星系图**在游戏启动时动态生成一个互连的星系网络。在单人模式下，它根据所选的地图大小（小、中、大）配置星系数量和边界。在多人模式下，它分配一个标准的 100 节点网格。超空间航道 (Warp lanes) 使用最小生成树 (MST) 算法结合基于邻近度的快捷连接来生成路径网络。

### 用户流程：
1. **进入星系**：玩家在开始新游戏或连接到多人游戏大厅房间时进入地图视图。
2. **导航**：用户使用鼠标右键或中键拖拽在 2D 坐标空间内进行平移。缩放和滚动会动态适应。
3. **选择**：左键单击星系会用金色选择环高亮显示该节点。右侧侧边栏面板会更新为所选星系的详细信息。
4. **查看恒星**：侧边栏显示星系所有者、坐标、连接的星际航道、环绕的行星、驻扎的舰队和机库存储。
5. **派遣舰队**：
   - 用户选择一支驻扎的舰队，从目标下拉列表中选择一个连接的目标节点，然后点击 **部署**（如果是玩家所有）或 **攻击**（如果是敌对/中立）。
   - 派遣后，舰队在地图画布上显示为一个有色三角形（对应所属势力的颜色），沿着超空间航道滑动，并实时显示旅行进度百分比。

---

## 2. 架构与代码入口 (Architecture & Code Entry Points)
地图结构遵循模型-视图-控制器 (MVC) 设计模式：

- **控制器/管理器 (Controller/Manager)**：
  - `src/core/managers/galaxy_manager.gd`：驱动地图的核心管理器。它处理程序化节点坐标生成、连接航道、处理实时舰队移动刻度 (ticks)、解析抵达事件、在节点碰撞时触发战斗，并管理基于回合的自动刻度 tick。
- **数据模型 (Data Models)**：
  - `src/core/models/galaxy_node.gd`：表示一个星系。保存星系 ID、显示名称、2D 坐标向量、所有者名称、连接的节点 ID 数组、驻扎的舰队列表、行星列表以及自动管理配置。
  - `src/core/models/fleet.gd`：表示一个舰队实体。追踪其组成（舰船设计名称到数量的映射）、当前节点位置、目标节点目的地、旅行进度（0.0 到 1.0）和速度。
- **UI 场景/脚本 (UI Scenes/Scripts)**：
  - `src/ui/galaxy_map_ui.tscn` / `src/ui/galaxy_map_ui.gd`：协调侧边栏面板、渲染星系轨道布局、管理舰队派遣控制，并挂钩客户端 RPC 请求。
  - `src/ui/galaxy_map_draw.gd`：渲染 2D 画布。绘制超空间航道、星系圆圈、核心反射强光、旋转的轨道路径、移动的舰队三角形节点、活跃战斗的双剑交叉指示器，并处理拖拽坐标平移。

---

## 3. 技术设计与算法 (Technical Design & Algorithms)

### 数据序列化与存储 (Data Serialization/Storage)
星系状态在服务端（或主机）是权威的 (authoritative)。整个地图结构是可序列化的，因为 `GalaxyManager`、`GalaxyNode`、`Fleet` 和 `Planet` 都继承自 Godot 内置的 `Resource` 类。
快照复制使用二进制流进行：
* **序列化**：`var_to_bytes_with_objects(galaxy_manager)`
* **反序列化**：`bytes_to_var_with_objects(snapshot_bytes) as GalaxyManager`
反序列化时，客户端使用 `galaxy_manager.reconnect_signals()` 重新连接信号。

### 算法与计算 (Algorithms/Calculations)

#### 1. 程序化名称生成 (Procedural Name Generation)
星系名称是通过将 20 个基础名称与程序化的希腊字母前缀和宇宙后缀相结合来动态生成的：
```
Name = Prefix (Greek Prefix [English]) + Suffix (Cosmic Suffix [English])
Example: "阿尔法星区 (Alpha Sector)"
```
最多生成 120 个独特的组合并缓存在集合中以防止冲突。

#### 2. 布局定位 (Layout Positioning)
* **多人模式**：在 $1800 \times 1800$ 的视口容器内（边界 $100.0$ 到 $1900.0$）生成正好 100 个随机分布 of 星系，确保最小间距距离为 $100.0$ 个单位。
* **单人模式**：
  - *小*：20 个星系，间距 $\ge 85.0$ 个单位。
  - *中*：50 个星系，间距 $\ge 90.0$ 个单位。
  - *大*：100 个星系，间距 $\ge 100.0$ 个单位。
先放置各势力的初始星系，根据地图大小，它们之间彼此相隔至少 $140.0$ 到 $350.0$ 个单位。

#### 3. 航道连通性（最小生成树 Minimum Spanning Tree）
为了保证所有星系都相互连接（没有孤立节点），生成器运行 Prim 算法来建立最小生成树：
1. 初始化一个包含第一个节点的 `visited` 列表，以及一个包含所有其他节点的 `unvisited` 列表。
2. 当 `unvisited` 不为空时：
   - 寻找节点 $u \in \text{visited}$ 和 $v \in \text{unvisited}$，使它们的欧几里得距离最小：
     $$d(u, v) = \sqrt{(u.x - v.x)^2 + (u.y - v.y)^2}$$
   - 在 $u$ 和 $v$ 之间创建一条双向连接（超空间航道）。
   - 将 $v$ 从 `unvisited` 移动到 `visited`。

#### 4. 邻近快捷连接 (Proximity Shortcut Connections)
为了使导航更有趣，在靠近的节点之间创建了额外的超空间航道：
- 如果 $d(u, v) < \text{prox\_limit}$（多人模式下为 $250.0$，单人模式下为 $160.0$），则添加超空间航道。
- 为了防止杂乱，只有当两个节点当前的连接数都少于 3 个时，才会创建航道。

#### 5. 最短路径导航（广度优先搜索 BFS）
当派遣舰队时，其路径使用广度优先搜索 (BFS) 算法来确定：
1. 启动一个搜索队列，其中包含仅包含起点星系 ID 的路径：`[[start_id]]`。
2. 弹出队首路径。设 $c$ 为该路径中的最后一个节点。
3. 如果 $c == \text{end\_id}$，则返回该路径（排除起点元素）。
4. 否则，对于 $c$ 的每个尚未访问的邻居 $n$：
   - 将当前路径追加了 $n$ 的副本添加到队列中。
5. 如果队列变空且未找到路径，则目标不可达。

#### 6. 舰队旅行时间 / 预估到达时间 (ETA)
舰队的速度是其组成舰船设计速度的加权平均值：
$$S_{\text{avg}} = \frac{\sum_{i} (S_i \cdot N_i)}{\sum_i N_i}$$
其中 $S_i$ 是设计 $i$ 的速度，而 $N_i$ 是设计 $i$ 的数量。
对于每一跳，以秒为单位的旅行时间为：
$$T_{\text{travel}} = \frac{\text{Distance}(Node_{\text{origin}}, Node_{\text{target}})}{S_{\text{avg}}} \times 3.0$$

### RPC 与网络 API (RPC/Network API)
- `@rpc("any_peer", "reliable") func server_request_dispatch_fleet(fleet_name: String, origin_node_id: String, target_node_id: String)`：由客户端发送以移动舰队。服务端：
  1. 检查映射到势力名称 (`peer_` + sender_id) 的远程发送方 ID 是否与舰队的所有者匹配。
  2. 验证路径可用性。敌对星系会阻止重新指派。
  3. 开始在服务端的移动列表中对舰队进行刻度计算 (ticking)，向所有客户端分发坐标快照。

---

## 4. 开发状态 (Development Status)
- **当前状态**：已完成。
- **最近更新**：重构了 UI 面板，采用了带有霓虹青色边框的半透明毛玻璃效果 (glassmorphism) HUD 设计。在星系节点上添加了活跃队列脉冲指示器。
- **已知问题 / 技术债务**：BFS 路径规划器是按跳数（边数）而不是物理空间坐标（Dijkstra 算法）计算距离的，这可能会在扭曲的网络上产生略微次优的路线。
