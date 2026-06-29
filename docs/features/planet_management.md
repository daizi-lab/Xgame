# Feature: Planet Infrastructure & Building Upgrades

## 1. Description & User Flow
**Planet Infrastructure & Building Upgrades** governs planetary economic production, building upgrades, and power grid scaling. Factions control individual planets to produce Metal, Crystal, and Deuterium. Planets feature exactly 10 building slots supporting Metal Mines, Crystal Mines, Deuterium Synthesizers, Solar Power Plants, and Space Shipyards. A central power grid regulates production efficiency: if power demand exceeds supply, mine output scales down proportionally.

### User Flow:
1. **Open Planet View**: The user selects a planet inside system view to open the base management dashboard.
2. **slot Grid Layout**: Renders 10 slots as visual cards. Empty slots show building choices (Metal Mine, Crystal Mine, Deuterium Synthesizer, Solar Power Plant, Shipyard). Occupied slots display their current level, statistics, cost, and an **Upgrade** button.
3. **Queuing Upgrades**:
   - The user selects a building type for an empty slot or clicks **Upgrade** on an occupied slot.
   - The cost (Metal and Crystal) is deducted from the player's resource pool.
   - The build order is added to the active upgrade queue (maximum of 3 concurrent builds per planet).
4. **Demolishing Buildings**:
   - The user clicks **Demolish** on an occupied slot.
   - A modal confirmation popup prevents accidental clicks.
   - Demolishing resets the slot to empty and does not refund resources.
5. **造船厂 Shipyard Construction**: Shipyard levels across the system enable warship construction and boost shipyard build speed.

---

## 2. Architecture & Code Entry Points
Planetary management is handled by separate local models and UI views:

- **Controller/Manager**:
  - `src/core/managers/galaxy_manager.gd`: Runs the server-side ticking logic for all planets inside the galaxy.
- **Data Models**:
  - `src/core/models/planet.gd`: Holds the authoritative planet state. Tracks slots (10-element array of dictionaries), upgrade queues, shipyard queues, and hangar storage. Calculates upgrade costs, build times, energy loads, and yields.
  - `src/core/models/planet_state.gd`: Client-side visual state model used for local UI caching and real-time prediction between server updates.
- **UI Scenes/Scripts**:
  - `src/ui/planet_base_ui.tscn` / `src/ui/planet_base_ui.gd`: Renders the building card grid, upgrade queue list, demolish popups, and cost tables.

---

## 3. Technical Design & Algorithms

### slot Structure
 Planetary infrastructure is stored as a 10-element array of dictionaries:
```
buildings = [
  {"type": "metal_mine", "level": 5},
  {"type": "empty", "level": 0},
  ...
]
```

### Algorithms & Formulas

#### 1. Building Upgrade Cost
The resource cost to upgrade a building from level $L$ to $L+1$ follows an exponential curve:
- **Metal Mine**:
  $$Cost_{\text{metal}} = \lfloor 60 \cdot 1.5^{L} \rfloor, \quad Cost_{\text{crystal}} = \lfloor 15 \cdot 1.5^{L} \rfloor$$
- **Crystal Mine**:
  $$Cost_{\text{metal}} = \lfloor 48 \cdot 1.6^{L} \rfloor, \quad Cost_{\text{crystal}} = \lfloor 24 \cdot 1.6^{L} \rfloor$$
- **Deuterium Synthesizer**:
  $$Cost_{\text{metal}} = \lfloor 225 \cdot 1.5^{L} \rfloor, \quad Cost_{\text{crystal}} = \lfloor 75 \cdot 1.5^{L} \rfloor$$
- **Solar Power Plant**:
  $$Cost_{\text{metal}} = \lfloor 75 \cdot 1.5^{L} \rfloor, \quad Cost_{\text{crystal}} = \lfloor 30 \cdot 1.5^{L} \rfloor$$
- **Shipyard**:
  $$Cost_{\text{metal}} = \lfloor 400 \cdot 2.0^{L} \rfloor, \quad Cost_{\text{crystal}} = \lfloor 200 \cdot 2.0^{L} \rfloor$$

#### 2. Upgrade Construction Time
The base time in seconds required to complete an upgrade is:
$$T_{\text{upgrade}} = \max\left(3.0, \frac{Cost_{\text{metal}} + Cost_{\text{crystal}}}{100.0}\right)$$

#### 3. Power Grid Calculations
Power output (from Solar Power Plants) and power consumption (from mines) follow exponential curves:
- **Max Energy (Solar Plants)**:
  $$E_{\text{max}} = \lfloor 30 \cdot L_{\text{solar}} \cdot 1.15^{L_{\text{solar}}} \rfloor$$
  *(where $L_{\text{solar}}$ is the sum of Solar Power Plant levels across all slots)*
- **Energy Consumed**:
  $$E_{\text{needed}} = E_{\text{metal\_mine}} + E_{\text{crystal\_mine}} + E_{\text{deut\_synth}}$$
  - Metal Mine: $E_{\text{metal\_mine}} = \lfloor 10 \cdot L \cdot 1.1^{L} \rfloor$
  - Crystal Mine: $E_{\text{crystal\_mine}} = \lfloor 10 \cdot L \cdot 1.1^{L} \rfloor$
  - Deuterium Synthesizer: $E_{\text{deut\_synth}} = \lfloor 20 \cdot L \cdot 1.1^{L} \rfloor$
- **Efficiency Scaling Factor ($\eta$)**:
  $$\eta = \begin{cases} 1.0 & \text{if } E_{\text{needed}} \le E_{\text{max}} \\ \frac{E_{\text{max}}}{E_{\text{needed}}} & \text{if } E_{\text{needed}} > E_{\text{max}} \end{cases}$$

#### 4. Sub-Tick Production Event Loop
Planets are ticked authorizations on the server. Because resource yields depend on power grid efficiency, and efficiency changes dynamically when upgrade tasks complete mid-tick, the server runs a sub-tick event loop:
1. Identify the remaining delta time: $dt_{\text{remaining}} = \text{delta}$.
2. Determine the time to the next queue event:
   $$dt_{\text{event}} = \min\left( dt_{\text{remaining}}, T_{\text{upgrade\_remaining}}, T_{\text{ship\_remaining}} \right)$$
3. Calculate current hourly yields:
   - Metal: $\text{Yield}_{\text{metal}} = (10.0 + 30 \cdot L_{\text{metal\_mine}} \cdot 1.1^{L_{\text{metal\_mine}}}) \cdot \eta$
   - Crystal: $\text{Yield}_{\text{crystal}} = (10.0 + 20 \cdot L_{\text{crystal\_mine}} \cdot 1.1^{L_{\text{crystal\_mine}}}) \cdot \eta$
   - Deuterium: $\text{Yield}_{\text{deuterium}} = (10.0 + 10 \cdot L_{\text{deut\_synth}} \cdot 1.1^{L_{\text{deut\_synth}}}) \cdot \eta$
4. Apply the resource yield for the sub-tick duration:
   $$\Delta R_r = \frac{dt_{\text{event}} \cdot 300.0}{3600.0} \cdot \text{Yield}_r$$
   *(where $300.0$ is the gameplay speed scaling factor: 1s real-time = 300s game-time).*
5. Subtract $dt_{\text{event}}$ from timers. Process completions (upgrading levels or adding constructed hulls to the hangar), remove completed items from the queues, re-evaluate efficiency $\eta$, and repeat until $dt_{\text{remaining}} \approx 0.0$.

### RPC/Network API
- `@rpc("any_peer", "reliable") func server_request_upgrade_building(planet_id: String, slot_index: int, proposed_type: String)`: Sent by client. Server validates slot index bounds ($0 \le slot \le 9$), checks level caps ($\le 20$), deducts resources, and appends the upgrade to the queue.
- `@rpc("any_peer", "reliable") func server_request_demolish_building(planet_id: String, slot_index: int)`: Sent by client. Server checks that the slot is not in the active upgrade queue and that a shipyard is not busy before resetting the slot to `empty` with level `0`.

---

## 4. Development Status
- **Current Status**: Completed.
- **Recent Updates**: Replaced binary blackouts on overloads with fractional efficiency scaling. Separated UI layout into card grid (left) and progress cards (right) with demolition confirmation checks to prevent misclicks.
- **Known Issues / Tech Debts**: The client-side `PlanetState` does not fully duplicate the 10-slot structure and operates on simplified aggregates, which can cause minor layout flickering on initial load before the first full server snapshot sync arrives.
