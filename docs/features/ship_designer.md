# Feature: Ship Designer

## 1. Description & User Flow
The **Ship Designer** (Blueprint Designer) allows players to customize and assemble combat starships. Players customize hulls by loading them with weapons, defensive shields/armor, and utility modules. Each design is governed by strict physical constraints: a weight limit and a power grid balance. Blueprints must be structurally valid and electrically stable before they can be saved and built in planetary shipyards.

### User Flow:
1. **Open Designer**: The player clicks "Ship Designer" on the main hub.
2. **Hull Selection**: The player selects a hull category from segmented horizontal cards. Hulls differ in base HP, speed, slot limits, weight capacities, and power grid caps.
3. **Module Assembly**:
   - The user browses available components (Weapons, Defense, Utilities) in the left panel.
   - Clicking a component automatically places it in the first available slot of that category.
   - The center panel renders slot status boxes. Clicking an occupied slot removes the component.
4. **Inspecting Specifications**: The right panel displays the blueprint's stats (HP, shields, armor, speed, build costs) and progress bars indicating weight capacity and power grid load.
5. **Blueprint Validation**: If weight exceeds the hull capacity, or if net power is negative, a red warning is shown, and the **Save** button is disabled.
6. **Saving Blueprints**: The user enters a unique design name and clicks **Save**, writing the design parameters to local user storage.

---

## 2. Architecture & Code Entry Points
The ship designer coordinates static catalog data, active blueprint structures, and editing UI components:

- **Controller/Manager**:
  - `src/ui/ship_designer_ui.gd`: Manages design states, binds input fields, applies visual themes, updates specifications, runs validation checks, and saves configuration files.
- **Data Models**:
  - `src/core/models/ship_design.gd`: Holds blueprint data (design name, hull type, list of weapons, list of shields, list of utilities). Calculates aggregate stats and checks constraints.
  - `src/core/data/components_data.gd`: Contains static tables of hulls (`HULLS`), weapons (`WEAPONS`), shields (`SHIELDS`), and utilities (`UTILITIES`).
- **UI Scenes/Scripts**:
  - `src/ui/ship_designer_ui.tscn` / `src/ui/ship_designer_ui.gd`: Renders the layout of assembly slots, component tables, and specifications.
  - `src/ui/shipyard_ui.tscn` / `src/ui/shipyard_ui.gd`: Renders planetary shipyard queues and queries saved blueprints to place construction orders.

---

## 3. Technical Design & Algorithms

### Component Catalog (components_data.gd)

#### 1. Hull Hulls (`HULLS`)
| Hull ID | Display Name | HP | Base Speed | Weapon Slots | Shield Slots | Utility Slots | Energy Cap | Weight Cap | Base Cost |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `frigate` | 护卫舰船体 | 200 | 100 | 2 | 2 | 1 | 80 | 120 | M:1000, C:500, D:0 |
| `destroyer` | 驱逐舰船体 | 500 | 80 | 4 | 3 | 2 | 200 | 250 | M:3000, C:1500, D:0 |
| `cruiser` | 巡洋舰船体 | 1200 | 60 | 6 | 5 | 3 | 500 | 600 | M:8000, C:4000, D:1000 |
| `battleship` | 战列舰船体 | 3000 | 40 | 10 | 8 | 4 | 1200 | 1500 | M:25000, C:12000, D:3000 |
*(M = Metal, C = Crystal, D = Deuterium)*

#### 2. Weapons (`WEAPONS`)
- `laser_light` (轻型脉冲激光): Damage 25, Accuracy 0.85, Energy Use 10, Weight 8. Cost: M:100, C:50.
- `laser_heavy` (重型高能激光): Damage 75, Accuracy 0.80, Energy Use 35, Weight 25. Cost: M:400, C:200.
- `railgun_light` (轻型电磁轨道炮): Damage 35, Accuracy 0.70, Energy Use 15, Weight 12. Cost: M:150, C:30.
- `railgun_heavy` (重型电磁轨道炮): Damage 110, Accuracy 0.65, Energy Use 50, Weight 40. Cost: M:600, C:120.
- `missile_launcher` (暴风鱼雷发射器): Damage 95, Accuracy 0.60, Energy Use 5, Weight 15. Cost: M:200, C:100, D:50.

#### 3. Shields & Armor (`SHIELDS`)
- `deflector_light` (轻型偏导护盾): Shield HP 80, Armor HP 0, Energy Use 15, Weight 5. Cost: M:150, C:100.
- `deflector_heavy` (重型力场护盾): Shield HP 300, Armor HP 0, Energy Use 55, Weight 20. Cost: M:500, C:400.
- `composite_armor_light` (轻型复合装甲板): Shield HP 0, Armor HP 120, Energy Use 0, Weight 15. Cost: M:80, C:20.
- `composite_armor_heavy` (重型纳米装甲板): Shield HP 0, Armor HP 450, Energy Use 0, Weight 50. Cost: M:300, C:50.

#### 4. Utilities (`UTILITIES`)
- `reactor_booster` (辅助核聚变核心): Energy Bonus +50, Weight 10. Cost: M:200, C:100.
- `cargo_hold` (扩展货舱): Cargo Bonus +500, Weight 15. Cost: M:100, C:10.
- `afterburner` (超载加力燃烧室): Speed Bonus +25, Energy Use 20, Weight 8. Cost: M:150, C:75, D:20.

---

### Technical Design Formulas & Constraints

#### 1. Weight Constraints
The total weight of all equipped weapons, shields, and utilities must not exceed the hull's capacity:
$$W_{\text{total}} = \sum_{w \in W} Weight_w + \sum_{s \in S} Weight_s + \sum_{u \in U} Weight_u$$
$$\text{Constraint: } W_{\text{total}} \le W_{\text{cap}}$$

#### 2. Power Grid Balance
Reactor output is the hull's base capacity plus energy bonuses from utility modules (e.g. `reactor_booster`). Total consumption is the sum of the energy requirements of all equipped items:
$$P_{\text{reactor}} = P_{\text{hull}} + \sum_{u \in U} EnergyBonus_u$$
$$P_{\text{consumption}} = \sum_{w \in W} EnergyUse_w + \sum_{s \in S} EnergyUse_s + \sum_{u \in U} EnergyUse_u$$
$$P_{\text{net}} = P_{\text{reactor}} - P_{\text{consumption}}$$
$$\text{Constraint: } P_{\text{net}} \ge 0.0$$

#### 3. Speed Calculation
$$\text{Speed} = Speed_{\text{hull}} + \sum_{u \in U} SpeedBonus_u$$

#### 4. Design Cost Accumulation
For each resource type $r \in \{\text{metal}, \text{crystal}, \text{deuterium}\}$:
$$Cost_r = Cost_{\text{hull}, r} + \sum_{w \in W} Cost_{w, r} + \sum_{s \in S} Cost_{s, r} + \sum_{u \in U} Cost_{u, r}$$

### Data Serialization
Blueprint parameters are serialized to a JSON dictionary and written locally to `user://ssw_blueprints.json`:
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

### RPC/Network API
- `@rpc("any_peer", "reliable") func server_request_ship_construction_with_design(planet_id: String, design_name: String, quantity: int, design_dict: Dictionary)`:
  1. The client sends a build order, passing the blueprint parameters in `design_dict`.
  2. The server instantiates a temporary `ShipDesign` object and executes `is_valid()` to verify weight and power constraints.
  3. The server validates that the player has sufficient resources in their faction pool, deducts the total cost, and appends the ship to the construction queue.

---

## 4. Development Status
- **Current Status**: Completed.
- **Recent Updates**: Implemented 1:1 aspect ratio previews for hulls. Category items are color-coded (corals for weapons, emeralds for defense, ambers for utility). Implemented quick-addition buttons and a "Delete Blueprint" button in the Shipyard UI.
- **Known Issues / Tech Debts**: Blueprints are saved locally on the client (`user://ssw_blueprints.json`), meaning the server must validate all incoming designs on demand rather than referencing a pre-approved list.
