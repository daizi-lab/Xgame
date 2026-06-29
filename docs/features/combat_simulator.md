# 功能：战术战斗模拟器

## 1. 说明与用户流程 (Description & User Flow)
**战术战斗模拟器**以确定的、基于回合的方式结算敌对舰队之间的战斗。当舰队到达被敌对势力或中立驻军占领的星系时，就会触发战斗。在战斗中，武器开火是按照速度和网格位置顺序结算的。伤害在对舰船船体造成伤害之前，先使用武器类型克制系数作用于防御系统（护盾和装甲）。战斗结束时将从残骸中回收废料。

### 用户流程：
1. **触发战斗**：舰队到达被敌对势力或中立防守者占领的星系，在服务端发起战斗。
2. **战斗指示器**：战斗处于活跃状态时，星系图上的星系节点旁会闪烁一个脉冲战斗指示器（双剑交叉）。
3. **查看日志**：
   - 玩家可以点击星系来实时查看战斗日志。
   - 日志控制台记录武器命中概率、伤害值以及护盾/装甲/船体状态的更新。
4. **战斗结算**：一旦一方舰队被摧毁，战斗结束。
5. **结算面板**：全屏结算模态窗口显示结果（胜利/失败），并列出从回收的残骸中获得的资源。

---

## 2. 架构与代码入口 (Architecture & Code Entry Points)
战斗模拟在服务端执行，并在客户端界面上渲染：

- **控制器/管理器 (Controller/Manager)**：
  - `src/core/simulator/battle_simulator.gd`：管理战斗初始化、回合、目标选择、命中判定、伤害计算和回收奖励。
- **数据模型 (Data Models)**：
  - `src/core/models/fleet.gd` -> `ActiveShip`：一个嵌套类，表示战斗中的一艘舰船。追踪其护盾、装甲和船体状态。
  - `src/core/models/commander.gd`：在战斗计算中修改舰队属性（瞄准、闪避、先攻权）。
- **UI 场景/脚本 (UI Scenes/Scripts)**：
  - `src/ui/combat_view_ui.tscn` / `src/ui/combat_view_ui.gd`：渲染回合日志、网格布局、武器卡片和结算模态面板。

---

## 3. 技术设计与算法 (Technical Design & Algorithms)

### ActiveShip 状态 (ActiveShip State)
战斗开始时，每个舰船设计都会实例化为一个 `ActiveShip` 对象：
* `current_shield` = `design.get_total_shield_hp()`
* `current_armor` = `design.get_total_armor_hp()`
* `current_hp` = `design.get_total_hull_hp()`

### 算法与公式 (Algorithms & Formulas)

#### 1. 开火顺序/先攻权 (Firing Order / Initiative)
在每个回合开始时，活跃的舰船按网格位置和速度进行排序：
- **网格优先级 (Grid Prioritization)**：
  - 进攻方（从左到右）：`slot_priority_a = [2, 5, 8, 1, 4, 7, 0, 3, 6]`
  - 防守方（从右到左）：`slot_priority_b = [0, 3, 6, 1, 4, 7, 2, 5, 8]`
- **速度计算 (Speed Calculation)**：
  每艘船的基础速度乘以其指挥官的先攻权加成系数：
  $$Speed_{\text{total}, A} = \sum_{i \in list\_a} Speed_i \cdot Initiative_{\text{commander}, A}$$
  $$Speed_{\text{total}, B} = \sum_{j \in list\_b} Speed_j \cdot Initiative_{\text{commander}, B}$$
- **回合交替 (Turn Alternation)**：
  - 如果 $Speed_{\text{total}, A} \ge Speed_{\text{total}, B}$，进攻方 A 先开火。
  - 开火回合在进攻方和防守方之间交替进行（$A_1, B_1, A_2, B_2, \dots$），直到所有活跃舰船都已开火。

#### 2. 精准度与命中判定 (Accuracy & Hit Rolls)
当一艘舰船开火时，它会随机瞄准一艘活跃的敌舰。舰船上的每件武器都是单独开火的。命中概率为：
$$HitChance = \text{clamp}\left( \frac{Acc_{\text{weapon}} \cdot Aim_{\text{attacker}}}{Eva_{\text{defender}}}, 0.05, 0.95 \right)$$
其中：
* $Acc_{\text{weapon}}$ 是武器的基础精准度（例如轻型激光为 $0.85$）。
* $Aim_{\text{attacker}}$ 是进攻方指挥官的瞄准乘数。
* $Eva_{\text{defender}}$ 是防守方指挥官的闪避乘数。

生成 $[0, 1]$ 范围内的随机浮点数。如果它小于或等于 $HitChance$，则射击命中。

#### 3. 伤害计算 (Damage Calculation)
武器伤害在其基础值的 $\pm 10\%$ 范围内随机波动：
$$Damage_{\text{base}} = Damage_{\text{weapon}} \cdot randf\_range(0.9, 1.1)$$

#### 4. 武器克制与护盾穿透 (Weapon Effectiveness & Shield Bypass)
伤害按护盾、装甲和船体的顺序应用，使用武器类型克制系数：
* **激光 (Laser)**：对护盾造成 $1.5\times$ 伤害，对装甲造成 $0.5\times$ 伤害。
* **动能 (Kinetic)**：对护盾造成 $0.5\times$ 伤害，对装甲造成 $1.5\times$ 伤害。
* **导弹 (Missile)**：对护盾造成 $1.0\times$ 伤害，对装甲造成 $1.0\times$ 伤害，但有 $20\%$ 的伤害会完全穿透护盾，直接击中装甲和船体：
  $$D_{\text{bypass}} = Damage_{\text{base}} \cdot 0.2, \quad D_{\text{shield}} = Damage_{\text{base}} \cdot 0.8$$

#### 5. 伤害结算步骤 (Damage Resolution Sequence - ActiveShip.take_damage)
当舰船受到伤害时，会分三个步骤进行结算：

##### 步骤 1：护盾偏导 (Shield Deflection)
如果舰船具有活跃护盾 ($current\_shield > 0$)：
* 计算护盾伤害：$D_{\text{shield\_dmg}} = Damage_{\text{base}} \cdot Mult_{\text{shield\_type}}$
* 如果 $D_{\text{shield\_dmg}} \le current\_shield$：
  - 扣除护盾值：$current\_shield = current\_shield - D_{\text{shield\_dmg}}$
  - 将剩余伤害设为零。
* 否则（护盾破裂）：
  - 计算剩余护盾伤害：$D_{\text{shield\_rem}} = D_{\text{shield\_dmg}} - current\_shield$
  - 重置护盾值：$current\_shield = 0$
  - 使用除法将剩余的护盾伤害折算回基础伤害值：
    $$Damage_{\text{base}} = \begin{cases} \frac{D_{\text{shield\_rem}}}{1.5} & \text{if laser} \\ \frac{D_{\text{shield\_rem}}}{0.5} & \text{if kinetic} \\ \frac{D_{\text{shield\_rem}}}{0.8} & \text{if missile} \end{cases}$$

##### 步骤 2：装甲阻挡 (Armor Blocking)
如果舰船具有活跃装甲 ($current\_armor > 0$)：
* 计算装甲伤害：$D_{\text{armor\_dmg}} = Damage_{\text{base}} \cdot Mult_{\text{armor\_type}}$
* 如果 $D_{\text{armor\_dmg}} \le current\_armor$：
  - 扣除装甲值：$current\_armor = current\_armor - D_{\text{armor\_dmg}}$
  - 将剩余伤害设为零。
* 否则（装甲破裂）：
  - 计算剩余装甲伤害：$D_{\text{armor\_rem}} = D_{\text{armor\_dmg}} - current\_armor$
  - 重置装甲值：$current\_armor = 0$
  - 将剩余装甲伤害折算回基础伤害值：
    $$Damage_{\text{base}} = \begin{cases} \frac{D_{\text{armor\_rem}}}{0.5} & \text{if laser} \\ \frac{D_{\text{armor\_rem}}}{1.5} & \text{if kinetic} \\ D_{\text{armor\_rem}} & \text{otherwise} \end{cases}$$

##### 步骤 3：结构船体伤害 (Structural Hull Damage)
剩余伤害直接作用于船体：
$$current\_hp = \max\left( 0.0, current\_hp - Damage_{\text{base}} \right)$$

如果 $current\_hp \le 0.0$，则舰船被摧毁。如果目标舰船在进攻方发射完所有武器前被摧毁，则会为剩余武器选择一个新目标。

#### 6. 残骸/废料回收计算 (Debris/Salvage Calculation)
当舰船被摧毁时，其总消耗的 $30\%$ 将被添加到残骸回收池中：
$$Salvage_r = \sum_{\text{destroyed}} \left( Cost_{\text{ship}, r} \cdot 0.3 \right)$$
其中 $r \in \{\text{metal}, \text{crystal}, \text{deuterium}\}$。
回收的资源将发放给获胜玩家的资源池。

---

## 4. 开发状态 (Development Status)
- **当前状态**：已完成。
- **最近更新**：实现了日志去重以防止控制台杂乱。设计了全屏模态结算面板，采用了胜利/失败的专属色彩主题（胜利青蓝/失败红橙）并包含资源回收汇总。
- **已知问题 / 技术债务**：战斗日志是以大字符串形式进行同步的；可以优化为流式传输事件结构体以节省带宽。
