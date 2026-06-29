# Feature: Idle/Auto-Management & Expansion AI

## 1. Description & User Flow
The **Idle/Auto-Management & Expansion AI** system controls enemy faction expansion and provides automation tools for players to automate base development. Players can toggle "Auto-Manage" on systems they own to automate building upgrades and ship construction according to predefined priorities. Non-player factions are controlled by the **Expansion AI**, which upgrades infrastructure, builds warships, assembles fleets in orbit, and launches attacks on adjacent systems.

### User Flow:
1. **Enabling Auto-Management**:
   - The player selects an owned system on the map.
   - In the sidebar header, they check the **Auto-Manage** box.
   - They select a target mode from the dropdown list: **Balanced**, **Economic**, or **Military**.
2. **AI Action**: The system runs automatically in the background, upgrading mines, building power plants, and constructing warships.
3. **Enemy AI Expansion**: Enemy factions expand dynamically, building fleets and invading neutral or player-controlled star systems.

---

## 2. Architecture & Code Entry Points
The AI systems run server-side and update player states:

- **Controller/Manager**:
  - `src/core/managers/galaxy_manager.gd`: Runs the player auto-management loop (`_run_player_auto_manage()`), the enemy AI loop (`_run_enemy_ai()`, `_run_ai_for_faction()`), and handles neutral/hostile garrison spawning (`_create_garrison_fleet()`). Binds logic to a 10-second timer.
- **Data Models**:
  - `src/core/models/galaxy_node.gd`: Stores system configuration fields `is_auto_managed` and `auto_manage_target`.
- **UI Scenes/Scripts**:
  - `src/ui/galaxy_map_ui.gd`: Displays checkbox controls and target mode selection dropdowns in the sidebar header.

---

## 3. Technical Design & Algorithms

### AI Loop Ticking
AI routines run server-side in `galaxy_manager.gd`'s `tick(delta)` loop, using a 10-second timer:
```gdscript
ai_tick_timer += delta
if ai_tick_timer >= 10.0:
    ai_tick_timer = 0.0
    _run_enemy_ai()
    _run_player_auto_manage()
```

---

### Player Auto-Management Logic
Auto-management evaluates system resource pools and upgrades planets based on the selected mode:

#### 1. Mode Selection Priorities
* **Economic**: Focuses exclusively on building upgrades. Ship construction is disabled.
* **Military**: Focuses on building ships, then upgrades shipyards and supporting infrastructure.
* **Balanced**: If the system fleet size (fleets + hangars) is under 6 ships, prioritizes ship construction; otherwise, prioritizes infrastructure upgrades.

#### 2. Building Upgrade Logic
For each planet, the AI queues up to 3 building upgrades. If a queue slot is available, it evaluates needs in the following order:
1. **Power Grid Check**: If power demand is close to capacity ($E_{\text{needed}} + 15 \ge E_{\text{max}}$), it upgrades a **Solar Power Plant**.
2. **Shipyard Priority**: In military mode, it upgrades a **Space Shipyard** if none exist.
3. **Mine Ratios**: It maintains a balanced ratio between metal, crystal, and deuterium production:
   - If $Level_{\text{metal\_mine}} < Level_{\text{crystal\_mine}} \cdot 1.5$: upgrade **Metal Mine**.
   - Else if $Level_{\text{crystal\_mine}} < Level_{\text{deut\_synth}} \cdot 2.0$: upgrade **Crystal Mine**.
   - Else if $Level_{\text{deut\_synth}} < 3$: upgrade **Deuterium Synthesizer**.
4. **Fallback**: If all mines are balanced, it selects a building based on weighted probabilities:
   - *Metal Mine*: $40\%$
   - *Crystal Mine*: $30\%$
   - *Deuterium Synthesizer*: $15\%$
   - *Space Shipyard*: $15\%$
5. **Slot Allocation**: The AI searches for an existing building of the chosen type to upgrade. If none exist and the level limit ($20$) is reached, it builds in an empty slot.

#### 3. Warship Construction Logic
The AI checks for active shipyards in the system and queues new builds. It prioritizes the most expensive ship design it can afford:
1. If resources are sufficient, queues a **Cruiser** (using a custom blueprint if available, or the default design).
2. Else if resources are sufficient, queues a **Destroyer**.
3. Else if resources are sufficient, queues a **Frigate**.

---

### Enemy Expansion AI Logic
The Enemy AI controls expansion and fleet movements for AI factions.

#### 1. Industrial Development
The AI checks systems under its control. If a system contains fewer than 8 warships, it prioritizes ship construction; otherwise, it prioritizes infrastructure upgrades.

#### 2. Hangar Fleet Assembly
At each tick, the AI transfers completed ships from planet hangars to orbit. If no fleet is stationed in the system, it spawns a new fleet and assigns the ships to it.

#### 3. Threat Assessment & Aggression
If a stationed fleet contains at least 5 ships, the AI evaluates adjacent systems for movement:
* **Defensive Assessment**: The AI calculates the defense strength of neighboring systems ($N_{\text{defenders}}$) by summing the ships in stationed fleets, or estimating the garrison strength based on game time elapsed.
  - **Neutral Garrison Scaling**: Base 3 Frigates. Adds +1 Frigate every 120s, +1 Destroyer every 120s after 180s, and +1 Cruiser every 180s after 300s.
  - **Enemy Garrison Scaling**: Base 5 Frigates. Adds +1 Frigate every 100s, +1 Destroyer every 100s after 120s, and +1 Cruiser every 150s after 240s.
* **Action Decision**:
  - **Attack**: If the fleet size $\ge \max(5, N_{\text{defenders}} + 2)$, the system is added to the attack list.
  - **Reinforce**: If the adjacent system is owned by the same faction, it is added to the reinforce list.
* **Dispatch Probability**:
  - $70\%$ chance to dispatch the fleet to attack a system on the attack list.
  - $30\%$ chance to dispatch the fleet to reinforce a system on the reinforce list.

---

## 4. Development Status
- **Current Status**: Completed.
- **Recent Updates**: Implemented time-scaled garrisons for neutral and enemy star systems. Designed customized UI cards for auto-management and integrated them into the map sidebar.
- **Known Issues / Tech Debts**: The AI does not coordinate fleet movements across multiple systems; fleets act independently at the system level.
