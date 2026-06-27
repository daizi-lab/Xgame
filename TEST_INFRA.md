# Resource Verification Suite: End-to-End Testing Infrastructure

This document describes the End-to-End (E2E) testing infrastructure implemented to verify the Resource Verification Suite in **战略家 (Zhanlvejia)**.

---

## 1. Test Architecture

The E2E test suite resides under the `scratch/` directory:
- **Core Test Runner Script (`scratch/test_resource_integration.gd`)**: Extends `SceneTree`, executes 82 test cases/assertions covering Tiers 1 through 4 sequentially, and exits with code 0 on success or 1 on failure.
- **Wrapper Scene (`scratch/test_resource_integration.tscn`)**: A lightweight scene that loads `scratch/test_resource_integration_node.gd` as its root script. It instantiates the core test runner in-memory, executes all tests, and handles the scene tree exit logic.

This structure allows the suite to be run in two ways:
1. **As a SceneTree script (Direct CLI execution)**:
   ```bash
   godot --headless -s res://scratch/test_resource_integration.gd
   ```
2. **As a Scene (Wrapper execution)**:
   ```bash
   godot --headless res://scratch/test_resource_integration.tscn
   ```

---

## 2. Test Coverage & Tiers

The suite implements **82 assertions** split into 4 tiers to verify the 7 core features:
1. Metal Mine Production Yield
2. Crystal Mine Production Yield
3. Deuterium Synthesizer Production Yield
4. Energy Generation & Mine Consumption
5. Power Overload Scaling
6. Upgrade/Construction Cost Validation, Overdrafting & Double-Spending Blocks
7. UI Synchronization & Label Updates

### Tier 1: Feature Coverage (35 Assertions)
Verifies expected yield formulas, energy capacities, cost calculations, and text format helpers under standard conditions.
- **F1 (Metal Mine)**: Levels 1, 2, 5, 10, 20 yields at 100% efficiency.
- **F2 (Crystal Mine)**: Levels 1, 2, 5, 10, 20 yields at 100% efficiency.
- **F3 (Deuterium Synthesizer)**: Levels 1, 2, 5, 10, 20 yields at 100% efficiency.
- **F4 (Energy)**: Capacity and mine demand at levels 1 and 5.
- **F5 (Overload)**: Efficiency factor calculations for multiple load profiles.
- **F6 (Cost)**: Level 1 costs for mines, power plants, and shipyards, plus upgrade deduction correctness.
- **F7 (HUD Formatting)**: Formats large numbers using "K" and "M" suffixes.

### Tier 2: Boundary & Edge Cases (35 Assertions)
Tests boundaries such as maximum level limits, zero efficiency states, negative delta time, empty collections, and overdrafts.
- **F1-F3 Edge**: Level 0 yields, level 20 max bounds, upgrade rejection above 20, 0% efficiency yield, and negative delta safety.
- **F4 Edge**: Level 0 energy, level 20 energy demand, and client helper multiplier consistency.
- **F5 Edge**: Efficiency factor clamping (0.0 to 1.0) and division-by-zero safety.
- **F6 Edge**: Double-spending blocks on slot upgrade requests, insufficient wallet resources, and level 0 shipyard build blocks.
- **F7 Edge**: Empty shipyard queue status, progress ratio bounds clamping, countdown text formats, and build button states.

### Tier 3: Cross-Feature Combinations (7 Assertions)
Tests interactions between systems during updates, queue sequential execution, shipyard upgrades, and simultaneous transaction requests.
- **T3.1**: Mine yield update on upgrade completion within the same tick.
- **T3.2**: Solar power plant upgrade restoring efficiency and mine yields.
- **T3.3**: Upgrade causing overload and immediate yield reduction for other mines.
- **T3.4**: Parallel resource deduction for ship construction and mine yield production.
- **T3.5**: Upgrading up to 3 slots in parallel with sequential completion.
- **T3.6**: Shipyard level acceleration on queued ship items.
- **T3.7**: Wallet overdraft check under simultaneous building and ship upgrade requests.

### Tier 4: Real-World Workload Scenarios (5 Assertions)
Runs long-term simulations, automated scripts, multiplayer replication snapshots, and campaign pipelines.
- **T4.1**: Standard start workflow (building solar plant + metal mine, ticking 600s with game speed 300).
- **T4.2**: Automated economic strategy (AI auto-management loop).
- **T4.3**: Military campaign pipeline (shipyard queue building 5 ships, fleet formation, dispatching, and resolving combat/residues).
- **T4.4**: Client-server snapshot serialization and replica restoration.
- **T4.5**: 24-hour offline client (`PlanetState`) vs server authoritative (`Planet`) simulation synchronization.

---

## 3. Known Discrepancies & Codebase Bugs Exposed

The test suite deliberately asserts mathematically correct specs, exposing several bugs in the core codebase:
1. **Base Yield Mismatch**: Server has 10.0 base yield for all mines, whereas Client has 30.0 Metal, 15.0 Crystal, and 0.0 Deuterium.
2. **Efficiency Scaling Difference**: Server scales the entire yield including base yield (`(Base + Mine) * Eff`), whereas Client only scales mine yield (`Base + Mine * Eff`).
3. **Energy Max Helper Multiplier Mismatch**: Client `PlanetState.get_energy_max()` helper uses multiplier `32` while the actual `tick()` uses `30`.
4. **Negative Delta Time**: The ticking logic does not prevent resources from being deducted when ticking with negative delta times.
5. **No Double Upgrades Block on Same Slot**: The server allows queuing multiple upgrades on the same building slot simultaneously.
6. **No shipyard level 0 block**: If system shipyard level is 0, the server falls back to level 1 and still constructs ships.
7. **Tick-delayed Yield Updates**: Mine upgrades do not immediately update the yield calculation for the remaining delta time of the same tick.
