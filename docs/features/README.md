# Zhanlvejia Feature Documentation Index

Welcome to the technical feature documentation for **战略家 (Zhanlvejia)**. This directory contains detailed architecture documents, algorithms, mathematical formulas, and network APIs for the core gameplay systems.

---

## 🌌 Feature Matrix & Development Status

Below is the list of core features, their implementation status, and links to their modular design specifications:

| # | Feature Name | Documentation Link | Key Technologies | Development Status |
| :-: | :--- | :--- | :--- | :-: |
| 1 | **Procedural Galaxy Map** | [galaxy_map.md](file:///d:/Project/TsGame/zhanlvejia/docs/features/galaxy_map.md) | Minimum Spanning Tree (Prim's), BFS Pathfinding, 2D Draw Canvas Panning | **Completed** |
| 2 | **Ship Designer** | [ship_designer.md](file:///d:/Project/TsGame/zhanlvejia/docs/features/ship_designer.md) | Constraint Validation, Power Grid Load, 1:1 Aspect Previews | **Completed** |
| 3 | **Planet Infrastructure** | [planet_management.md](file:///d:/Project/TsGame/zhanlvejia/docs/features/planet_management.md) | 10-Slot Array Grid, Sub-Tick Event Loop, Efficiency Scaling Curves | **Completed** |
| 4 | **Tactical Combat Simulator** | [combat_simulator.md](file:///d:/Project/TsGame/zhanlvejia/docs/features/combat_simulator.md) | Turn Initiative, Weapon-Type Effectiveness, Wreckage Salvaging | **Completed** |
| 5 | **Multiplayer & Server Sync** | [multiplayer_sync.md](file:///d:/Project/TsGame/zhanlvejia/docs/features/multiplayer_sync.md) | ENet Lobbies, Binary Snapshot Replication, RPC Sender Validation | **Completed** |
| 6 | **Auto-Management & Expansion AI** | [expansion_ai.md](file:///d:/Project/TsGame/zhanlvejia/docs/features/expansion_ai.md) | Automation Priority Decision Trees, Garrison Scaling Curves | **Completed** |

---

## 🛠️ Verification Tests & Building

You can verify that all UI scenes parse and compile without compiling errors (avoiding null pointer and node path breakages) using the headless runner tool.

### Running Headless Integration Tests:
```bash
# Verify resource calculations and event loops
godot --headless -s res://scratch/test_resource_integration.gd

# Verify adversarial network inputs and boundary security checks
godot --headless -s res://scratch/test_adversarial_1.gd

# Verify room deadlocks and connection leaks
godot --headless -s res://scratch/test_adversarial_2.gd
```
*Make sure `godot` is in your environment PATH or replace it with the absolute path to your Godot 4.7 executable.*

---

## 📁 Document Templates & Standards
Each document in this directory is structured using the following sections:
1. **Description & User Flow**: High-level overview of player interactions.
2. **Architecture & Code Entry Points**: Mapping of Controller/Manager singletons, Resource Data Models, and View Scene/Scripts (MVC representation).
3. **Technical Design & Algorithms**: Exact math equations, database structures, network RPC interfaces, and validation rules.
4. **Development Status**: Current state, recent updates, and known technical debt.
