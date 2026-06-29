# 功能：舰船设计器

## 1. 说明与用户流程 (Description & User Flow)
**舰船设计器**（蓝图设计器）允许玩家自定义和组装战斗星舰。玩家通过为船体装配武器、防御护盾/装甲以及辅助模块来定制船体。每种设计都受严格的物理约束限制：重量限制和电网负载平衡。蓝图必须在结构上有效且电力稳定，然后才能保存并在行星造船厂中建造。

### 用户流程：
1. **打开设计器**：玩家在主枢纽点击“舰船设计器”。
2. **选择船体**：玩家从分段式水平卡片中选择一个船体类别。船体在基础生命值 (HP)、速度、槽位限制、重量容量和电网容量上限方面有所不同。
3. **模块组装**：
   - 用户在左侧面板中浏览可用组件（武器、防御、辅助）。
   - 单击某个组件会自动将其放入该类别的第一个可用槽位中。
   - 中间面板渲染槽位状态框。单击已占用的槽位会移除该组件。
4. **查看规格**：右侧面板显示蓝图的属性（HP、护盾、装甲、速度、建造消耗）以及指示重量容量和电网负载的进度条。
5. **蓝图验证**：如果重量超过船体容量，或者净电力为负，则显示红色警告，并且**保存**按钮被禁用。
6. **保存蓝图**：用户输入一个唯一的设计名称并点击**保存**，将设计参数写入本地用户存储。

---

## 2. 架构与代码入口 (Architecture & Code Entry Points)
舰船设计器协调静态目录数据、活动蓝图结构和编辑 UI 组件：

- **控制器/管理器 (Controller/Manager)**：
  - `src/ui/ship_designer_ui.gd`：管理设计状态、绑定输入字段、应用视觉主题、更新规格参数、运行验证检查并保存配置文件。
- **数据模型 (Data Models)**：
  - `src/core/models/ship_design.gd`：持有蓝图数据（设计名称、船体类型、武器列表、护盾列表、辅助模块列表）。计算汇总统计数据并检查约束。
  - `src/core/data/components_data.gd`：包含船体 (`HULLS`)、武器 (`WEAPONS`)、护盾 (`SHIELDS`) 和辅助模块 (`UTILITIES`) 的静态表。
- **UI 场景/脚本 (UI Scenes/Scripts)**：
  - `src/ui/ship_designer_ui.tscn` / `src/ui/ship_designer_ui.gd`：渲染组装槽位、组件表和规格参数的布局。
  - `src/ui/shipyard_ui.tscn` / `src/ui/shipyard_ui.gd`：渲染行星造船厂队列并查询已保存的蓝图以放置建造订单。

---

## 3. 技术设计与算法 (Technical Design & Algorithms)

### 组件目录 (components_data.gd)

#### 1. 船体 Hulls (`HULLS`)
| 船体 ID | 显示名称 | HP | 基础速度 | 武器槽位 | 护盾槽位 | 辅助槽位 | 电力上限 | 重量上限 | 基础消耗 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `frigate` | 护卫舰船体 | 200 | 100 | 2 | 2 | 1 | 80 | 120 | M:1000, C:500, D:0 |
| `destroyer` | 驱逐舰船体 | 500 | 80 | 4 | 3 | 2 | 200 | 250 | M:3000, C:1500, D:0 |
| `cruiser` | 巡洋舰船体 | 1200 | 60 | 6 | 5 | 3 | 500 | 600 | M:8000, C:4000, D:1000 |
| `battleship` | 战列舰船体 | 3000 | 40 | 10 | 8 | 4 | 1200 | 1500 | M:25000, C:12000, D:3000 |
*(M = 金属 Metal, C = 水晶 Crystal, D = 氘 Deuterium)*

#### 2. 武器 (`WEAPONS`)
- `laser_light` (轻型脉冲激光): 伤害 25, 精准度 0.85, 能量消耗 10, 重量 8. 消耗: M:100, C:50.
- `laser_heavy` (重型高能激光): 伤害 75, 精准度 0.80, 能量消耗 35, 重量 25. 消耗: M:400, C:200.
- `railgun_light` (轻型电磁轨道炮): 伤害 35, 精准度 0.70, 能量消耗 15, 重量 12. 消耗: M:150, C:30.
- `railgun_heavy` (重型电磁轨道炮): 伤害 110, 精准度 0.65, 能量消耗 50, 重量 40. 消耗: M:600, C:120.
- `missile_launcher` (暴风鱼雷发射器): 伤害 95, 精准度 0.60, 能量消耗 5, 重量 15. 消耗: M:200, C:100, D:50.

#### 3. 护盾与装甲 (`SHIELDS`)
- `deflector_light` (轻型偏导护盾): 护盾 HP 80, 装甲 HP 0, 能量消耗 15, 重量 5. 消耗: M:150, C:100.
- `deflector_heavy` (重型力场护盾): 护盾 HP 300, 装甲 HP 0, 能量消耗 55, 重量 20. 消耗: M:500, C:400.
- `composite_armor_light` (轻型复合装甲板): 护盾 HP 0, 装甲 HP 120, 能量消耗 0, 重量 15. 消耗: M:80, C:20.
- `composite_armor_heavy` (重型纳米装甲板): 护盾 HP 0, 装甲 HP 450, 能量消耗 0, 重量 50. 消耗: M:300, C:50.

#### 4. 辅助模块 (`UTILITIES`)
- `reactor_booster` (辅助核聚变核心): 能量加成 +50, 重量 10. 消耗: M:200, C:100.
- `cargo_hold` (扩展货舱): 货舱加成 +500, 重量 15. 消耗: M:100, C:10.
- `afterburner` (超载加力燃烧室): 速度加成 +25, 能量消耗 20, 重量 8. 消耗: M:150, C:75, D:20.

---

## 3. 技术设计与算法 (Technical Design & Algorithms)

### 技术设计公式与约束 (Technical Design Formulas & Constraints)

#### 1. 重量约束 (Weight Constraints)
所有装备的武器、护盾和辅助模块的总重量不能超过船体的容量上限：
$$W_{\text{total}} = \sum_{w \in W} Weight_w + \sum_{s \in S} Weight_s + \sum_{u \in U} Weight_u$$
$$\text{Constraint: } W_{\text{total}} \le W_{\text{cap}}$$

#### 2. 电网负载平衡 (Power Grid Balance)
反应堆输出为船体的基础容量加上来自辅助模块（例如 `reactor_booster`）的能量加成。总能耗是所有装备物品能耗需求的总和：
$$P_{\text{reactor}} = P_{\text{hull}} + \sum_{u \in U} EnergyBonus_u$$
$$P_{\text{consumption}} = \sum_{w \in W} EnergyUse_w + \sum_{s \in S} EnergyUse_s + \sum_{u \in U} EnergyUse_u$$
$$P_{\text{net}} = P_{\text{reactor}} - P_{\text{consumption}}$$
$$\text{Constraint: } P_{\text{net}} \ge 0.0$$

#### 3. 速度计算 (Speed Calculation)
$$\text{Speed} = Speed_{\text{hull}} + \sum_{u \in U} SpeedBonus_u$$

#### 4. 设计消耗累计 (Design Cost Accumulation)
对于每种资源类型 $r \in \{\text{metal}, \text{crystal}, \text{deuterium}\}$：
$$Cost_r = Cost_{\text{hull}, r} + \sum_{w \in W} Cost_{w, r} + \sum_{s \in S} Cost_{s, r} + \sum_{u \in U} Cost_{u, r}$$

### 数据序列化 (Data Serialization)
蓝图参数被序列化为一个 JSON 字典并本地写入 `user://ssw_blueprints.json`：
```json
{
  "暴风护卫舰": {
    "design_name": "暴风护卫舰",
    "hull_id": "frigate",
    "weapons": ["laser_light", "laser_light"],
    "shields": ["deflector_light", "composite_armor_light"],
    "utilities": ["afterburner"]
  }
}
```

### RPC 与网络 API (RPC/Network API)
- `@rpc("any_peer", "reliable") func server_request_ship_construction_with_design(planet_id: String, design_name: String, quantity: int, design_dict: Dictionary)`：
  1. 客户端发送建造订单，在 `design_dict` 中传递蓝图参数。
  2. 服务端实例化一个临时的 `ShipDesign` 对象并执行 `is_valid()` 来验证重量和电力约束。
  3. 服务端验证玩家在其势力资源池中是否有足够的资源，扣除总消耗，并将舰船追加到建造队列中。

---

## 4. 开发状态 (Development Status)
- **当前状态**：已完成。
- **最近更新**：实现了船体的 1:1 比例预览。类别物品采用颜色编码（珊瑚色代表武器，翡翠绿代表防御，琥珀色代表辅助）。在造船厂 UI 中实现了快速添加按钮和“删除蓝图”按钮。
- **已知问题 / 技术债务**：蓝图保存在客户端本地（`user://ssw_blueprints.json`），这意味着服务端必须根据需求验证所有传入的设计，而不是引用预先批准的列表。
