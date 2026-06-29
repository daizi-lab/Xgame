# 功能：行星基础设施与建筑升级

## 1. 说明与用户流程 (Description & User Flow)
**行星基础设施与建筑升级**管理行星的经济生产、建筑升级和电网缩放。势力控制各个行星来生产金属 (Metal)、水晶 (Crystal) 和氘 (Deuterium)。行星拥有正好 10 个建筑槽位，支持建造金属矿、水晶矿、氘合成器、太阳能电站和空间造船厂。中央电网调节生产效率：如果电力需求超过供应，矿场的产出将按比例下调。

### 用户流程：
1. **打开行星视图**：用户在星系视图中选择一个行星，以打开基地管理仪表盘。
2. **槽位网格布局**：将 10 个槽位渲染为可视卡片。空槽位显示建筑选项（金属矿、水晶矿、氘合成器、太阳能电站、造船厂）。已占用的槽位显示其当前等级、属性、消耗以及**升级**按钮。
3. **排队升级**：
   - 用户为星系空槽位选择建筑类型，或点击已占用槽位上的**升级**按钮。
   - 消耗（金属和水晶）从玩家的资源池中扣除。
   - 建造订单被添加到活跃升级队列中（每个行星最多同时进行 3 个建造任务）。
4. **拆除建筑**：
   - 用户点击已占用槽位上的**拆除**按钮。
   - 弹出的模态确认窗口可防止误触。
   - 拆除会将槽位重置为空，且不退还资源。
5. **造船厂建造**：整个星系系统中的造船厂等级能够解锁战舰建造，并提高造船厂的建造速度。

---

## 2. 架构与代码入口 (Architecture & Code Entry Points)
行星管理由单独的本地模型和 UI 视图处理：

- **控制器/管理器 (Controller/Manager)**：
  - `src/core/managers/galaxy_manager.gd`：运行服务端针对星系内所有行星的刻度 (ticking) 逻辑。
- **数据模型 (Data Models)**：
  - `src/core/models/planet.gd`：持有权威的行星状态。追踪槽位（10个元素的字典数组）、升级队列、造船厂队列和机库存储。计算升级消耗、建造时间、电力负载和产出。
  - `src/core/models/planet_state.gd`：客户端视觉状态模型，用于本地 UI 缓存以及在服务端更新之间的实时预测。
- **UI 场景/脚本 (UI Scenes/Scripts)**：
  - `src/ui/planet_base_ui.tscn` / `src/ui/planet_base_ui.gd`：渲染建筑卡片网格、升级队列列表、拆除确认弹窗和消耗表。

---

## 3. 技术设计与算法 (Technical Design & Algorithms)

### 槽位结构 (slot Structure)
 行星基础设施存储为 10 个元素的字典数组：
```
buildings = [
  {"type": "metal_mine", "level": 5},
  {"type": "empty", "level": 0},
  ...
]
```

### 算法与公式 (Algorithms & Formulas)

#### 1. 建筑升级消耗 (Building Upgrade Cost)
将建筑从等级 $L$ 升级到 $L+1$ 所需的资源消耗遵循指数曲线：
- **金属矿 (Metal Mine)**：
  $$Cost_{\text{metal}} = \lfloor 60 \cdot 1.5^{L} \rfloor, \quad Cost_{\text{crystal}} = \lfloor 15 \cdot 1.5^{L} \rfloor$$
- **水晶矿 (Crystal Mine)**：
  $$Cost_{\text{metal}} = \lfloor 48 \cdot 1.6^{L} \rfloor, \quad Cost_{\text{crystal}} = \lfloor 24 \cdot 1.6^{L} \rfloor$$
- **氘合成器 (Deuterium Synthesizer)**：
  $$Cost_{\text{metal}} = \lfloor 225 \cdot 1.5^{L} \rfloor, \quad Cost_{\text{crystal}} = \lfloor 75 \cdot 1.5^{L} \rfloor$$
- **太阳能电站 (Solar Power Plant)**：
  $$Cost_{\text{metal}} = \lfloor 75 \cdot 1.5^{L} \rfloor, \quad Cost_{\text{crystal}} = \lfloor 30 \cdot 1.5^{L} \rfloor$$
- **造船厂 (Shipyard)**：
  $$Cost_{\text{metal}} = \lfloor 400 \cdot 2.0^{L} \rfloor, \quad Cost_{\text{crystal}} = \lfloor 200 \cdot 2.0^{L} \rfloor$$

#### 2. 升级建造时间 (Upgrade Construction Time)
完成升级所需的基础时间（以秒为单位）为：
$$T_{\text{upgrade}} = \max\left(3.0, \frac{Cost_{\text{metal}} + Cost_{\text{crystal}}}{100.0}\right)$$

#### 3. 电网计算 (Power Grid Calculations)
电力输出（来自太阳能电站）和电力消耗（来自矿场）遵循指数曲线：
- **最大电力（太阳能电站）**：
  $$E_{\text{max}} = \lfloor 30 \cdot L_{\text{solar}} \cdot 1.15^{L_{\text{solar}}} \rfloor$$
  *（其中 $L_{\text{solar}}$ 是所有槽位中太阳能电站等级的总和）*
- **消耗的电力**：
  $$E_{\text{needed}} = E_{\text{metal\_mine}} + E_{\text{crystal\_mine}} + E_{\text{deut\_synth}}$$
  - 金属矿：$E_{\text{metal\_mine}} = \lfloor 10 \cdot L \cdot 1.1^{L} \rfloor$
  - 水晶矿：$E_{\text{crystal\_mine}} = \lfloor 10 \cdot L \cdot 1.1^{L} \rfloor$
  - 氘合成器：$E_{\text{deut\_synth}} = \lfloor 20 \cdot L \cdot 1.1^{L} \rfloor$
- **效率缩放因子 ($\eta$)**：
  $$\eta = \begin{cases} 1.0 & \text{if } E_{\text{needed}} \le E_{\text{max}} \\ \frac{E_{\text{max}}}{E_{\text{needed}}} & \text{if } E_{\text{needed}} > E_{\text{max}} \end{cases}$$

#### 4. 子刻度生产事件循环 (Sub-Tick Production Event Loop)
行星在服务端进行权威的刻度计算 (ticking)。因为资源产出取决于电网效率，而效率在刻度中期升级任务完成时会发生动态变化，因此服务端运行一个子刻度 (sub-tick) 事件循环：
1. 确定剩余的增量时间：$dt_{\text{remaining}} = \text{delta}$。
2. 确定距离下一个队列事件的时间：
   $$dt_{\text{event}} = \min\left( dt_{\text{remaining}}, T_{\text{upgrade\_remaining}}, T_{\text{ship\_remaining}} \right)$$
3. 计算当前的每小时产出：
   - 金属：$\text{Yield}_{\text{metal}} = (10.0 + 30 \cdot L_{\text{metal\_mine}} \cdot 1.1^{L_{\text{metal\_mine}}}) \cdot \eta$
   - 水晶：$\text{Yield}_{\text{crystal}} = (10.0 + 20 \cdot L_{\text{crystal\_mine}} \cdot 1.1^{L_{\text{crystal\_mine}}}) \cdot \eta$
   - 氘：$\text{Yield}_{\text{deuterium}} = (10.0 + 10 \cdot L_{\text{deut\_synth}} \cdot 1.1^{L_{\text{deut\_synth}}}) \cdot \eta$
4. 应用该子刻度持续时间内的资源产出：
   $$\Delta R_r = \frac{dt_{\text{event}} \cdot 300.0}{3600.0} \cdot \text{Yield}_r$$
   *（其中 $300.0$ 是游戏速度缩放因子：真实时间 1秒 = 游戏时间 300秒）。*
5. 从定时器中减去 $dt_{\text{event}}$。处理完成事件（升级等级或将建造好的船体添加到机库），从队列中移除已完成的项，重新评估效率 $\eta$，并重复此过程，直到 $dt_{\text{remaining}} \approx 0.0$。

### RPC 与网络 API (RPC/Network API)
- `@rpc("any_peer", "reliable") func server_request_upgrade_building(planet_id: String, slot_index: int, proposed_type: String)`：由客户端发送。服务端验证槽位索引边界（$0 \le slot \le 9$），检查等级上限（$\le 20$），扣除资源，并将升级追加到队列中。
- `@rpc("any_peer", "reliable") func server_request_demolish_building(planet_id: String, slot_index: int)`：由客户端发送。服务端检查该槽位是否不在活跃的升级队列中，且造船厂在重置该槽位为级别 `0` 的 `empty` 状态前没有处于繁忙状态。

---

## 4. 开发状态 (Development Status)
- **当前状态**：已完成。
- **最近更新**：将超载时的二进制断电替换为分数级效率缩放。将 UI 布局分成了卡片网格（left 侧）和进度卡片（右侧），带有拆除确认检查以防止误触。
- **已知问题 / 技术债务**：客户端的 `PlanetState` 没有完全复制 10 槽位结构，而是基于简化后的汇总数据进行操作，这可能会在第一次完整的服务端快照同步到达之前，导致初始加载时出现轻微的布局闪烁。
