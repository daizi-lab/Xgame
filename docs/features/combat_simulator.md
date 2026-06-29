# Feature: Tactical Combat Simulator

## 1. Description & User Flow
The **Tactical Combat Simulator** resolves battles between opposing fleets in a deterministic, turn-based manner. Battles trigger when a fleet arrives at a star system occupied by a hostile faction or neutral garrison. During the battle, weapon fire is resolved in order of speed and grid positioning. Damage is applied to defensive systems (shields and armor) using weapon-type effectiveness multipliers before damaging the ship's hull. Debris is salvaged from the wreckage when the battle concludes.

### User Flow:
1. **Triggering Combat**: A fleet arrives at a system occupied by an opposing faction or neutral defenders, initiating combat on the server.
2. **Combat Indicator**: While a battle is active, a pulsing combat indicator (crossed swords) flashes next to the system node on the galaxy map.
3. **Log Viewing**:
   - Players can click on the system to inspect the combat log in real-time.
   - The log console records weapon hit chances, damage values, and shields/armor/hull status updates.
4. **Combat Resolution**: Once a fleet is destroyed, the battle concludes.
5. **Settlement Panel**: A full-screen settlement modal displays the outcome (Victory/Defeat) and lists resources recovered from the salvaged debris.

---

## 2. Architecture & Code Entry Points
Combat simulation is executed server-side and rendered on client interfaces:

- **Controller/Manager**:
  - `src/core/simulator/battle_simulator.gd`: Manages battle initialization, turns, targeting, hit rolls, damage calculations, and salvage rewards.
- **Data Models**:
  - `src/core/models/fleet.gd` -> `ActiveShip`: A nested class representing a ship during combat. Tracks its shield, armor, and hull status.
  - `src/core/models/commander.gd`: Modifies fleet stats (aiming, evasion, initiative) in combat calculations.
- **UI Scenes/Scripts**:
  - `src/ui/combat_view_ui.tscn` / `src/ui/combat_view_ui.gd`: Renders round logs, grid layouts, weapon cards, and the settlement modal panel.

---

## 3. Technical Design & Algorithms

### ActiveShip State
At the start of combat, each ship design is instantiated as an `ActiveShip` object:
* `current_shield` = `design.get_total_shield_hp()`
* `current_armor` = `design.get_total_armor_hp()`
* `current_hp` = `design.get_total_hull_hp()`

### Algorithms & Formulas

#### 1. Firing Order (Initiative)
At the start of each round, active ships are sorted by grid position and speed:
- **Grid Prioritization**:
  - Attacker (Left-to-Right): `slot_priority_a = [2, 5, 8, 1, 4, 7, 0, 3, 6]`
  - Defender (Right-to-Left): `slot_priority_b = [0, 3, 6, 1, 4, 7, 2, 5, 8]`
- **Speed Calculation**:
  Each ship's base speed is scaled by its commander's initiative multiplier:
  $$Speed_{\text{total}, A} = \sum_{i \in list\_a} Speed_i \cdot Initiative_{\text{commander}, A}$$
  $$Speed_{\text{total}, B} = \sum_{j \in list\_b} Speed_j \cdot Initiative_{\text{commander}, B}$$
- **Turn Alternation**:
  - If $Speed_{\text{total}, A} \ge Speed_{\text{total}, B}$, Attacker A fires first.
  - Firing turns alternate between the attacker and defender ($A_1, B_1, A_2, B_2, \dots$) until all active ships have fired.

#### 2. Accuracy & Hit Rolls
When a ship fires, it targets a random active enemy ship. Each weapon on the ship is fired individually. The hit chance is:
$$HitChance = \text{clamp}\left( \frac{Acc_{\text{weapon}} \cdot Aim_{\text{attacker}}}{Eva_{\text{defender}}}, 0.05, 0.95 \right)$$
where:
* $Acc_{\text{weapon}}$ is the weapon's base accuracy (e.g. $0.85$ for light lasers).
* $Aim_{\text{attacker}}$ is the attacker's commander aiming multiplier.
* $Eva_{\text{defender}}$ is the defender's commander evasion multiplier.

A random float in the range $[0, 1]$ is generated. If it is less than or equal to $HitChance$, the shot hits.

#### 3. Damage Calculation
Weapon damage fluctuates randomly within $\pm 10\%$ of its base value:
$$Damage_{\text{base}} = Damage_{\text{weapon}} \cdot randf\_range(0.9, 1.1)$$

#### 4. Weapon Effectiveness & Shield Bypass
Damage is applied in order to shields, armor, and hull, using weapon-type multipliers:
* **Laser**: $1.5\times$ vs Shield, $0.5\times$ vs Armor.
* **Kinetic**: $0.5\times$ vs Shield, $1.5\times$ vs Armor.
* **Missile**: $1.0\times$ vs Shield, $1.0\times$ vs Armor, but $20\%$ of damage bypasses shields entirely to hit armor and hull:
  $$D_{\text{bypass}} = Damage_{\text{base}} \cdot 0.2, \quad D_{\text{shield}} = Damage_{\text{base}} \cdot 0.8$$

#### 5. Damage Resolution Sequence (ActiveShip.take_damage)
When a ship takes damage, it is resolved in three steps:

##### Step 1: Shield Deflection
If the ship has active shields ($current\_shield > 0$):
* Calculate shield damage: $D_{\text{shield\_dmg}} = Damage_{\text{base}} \cdot Mult_{\text{shield\_type}}$
* If $D_{\text{shield\_dmg}} \le current\_shield$:
  - Deduct shield: $current\_shield = current\_shield - D_{\text{shield\_dmg}}$
  - Set remaining damage to zero.
* Else (shield breaks):
  - Calculate remaining shield damage: $D_{\text{shield\_rem}} = D_{\text{shield\_dmg}} - current\_shield$
  - Reset shield: $current\_shield = 0$
  - Convert remaining shield damage back to baseline damage using division:
    $$Damage_{\text{base}} = \begin{cases} \frac{D_{\text{shield\_rem}}}{1.5} & \text{if laser} \\ \frac{D_{\text{shield\_rem}}}{0.5} & \text{if kinetic} \\ \frac{D_{\text{shield\_rem}}}{0.8} & \text{if missile} \end{cases}$$

##### Step 2: Armor Blocking
If the ship has active armor ($current\_armor > 0$):
* Calculate armor damage: $D_{\text{armor\_dmg}} = Damage_{\text{base}} \cdot Mult_{\text{armor\_type}}$
* If $D_{\text{armor\_dmg}} \le current\_armor$:
  - Deduct armor: $current\_armor = current\_armor - D_{\text{armor\_dmg}}$
  - Set remaining damage to zero.
* Else (armor breaks):
  - Calculate remaining armor damage: $D_{\text{armor\_rem}} = D_{\text{armor\_dmg}} - current\_armor$
  - Reset armor: $current\_armor = 0$
  - Convert remaining armor damage back to baseline damage:
    $$Damage_{\text{base}} = \begin{cases} \frac{D_{\text{armor\_rem}}}{0.5} & \text{if laser} \\ \frac{D_{\text{armor\_rem}}}{1.5} & \text{if kinetic} \\ D_{\text{armor\_rem}} & \text{otherwise} \end{cases}$$

##### Step 3: Structural Hull Damage
Remaining damage is applied directly to the hull:
$$current\_hp = \max\left( 0.0, current\_hp - Damage_{\text{base}} \right)$$

If $current\_hp \le 0.0$, the ship is destroyed. If the target ship is destroyed before the attacker has fired all its weapons, a new target is selected for the remaining weapons.

#### 6. Debris/Salvage Calculation
When a ship is destroyed, $30\%$ of its total cost is added to the wreckage salvage pool:
$$Salvage_r = \sum_{\text{destroyed}} \left( Cost_{\text{ship}, r} \cdot 0.3 \right)$$
for $r \in \{\text{metal}, \text{crystal}, \text{deuterium}\}$.
Salvaged resources are awarded to the winning player's resource pool.

---

## 4. Development Status
- **Current Status**: Completed.
- **Recent Updates**: Implemented log de-duplication to prevent console clutter. Designed a full-screen modal settlement panel with victory/defeat color themes (胜利青蓝/失败红橙) and resource salvage summaries.
- **Known Issues / Tech Debts**: Combat logs are synchronized as large strings; could be optimized to stream event structs to save bandwidth.
