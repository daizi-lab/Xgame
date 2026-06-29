# Feature: Procedural Galaxy Map

## 1. Description & User Flow
The **Procedural Galaxy Map** dynamically generates a connected network of star systems on game startup. In singleplayer, it configures system count and boundaries depending on the chosen map size (Small, Medium, Large). In multiplayer, it allocates a standardized grid of 100 nodes. Warp lanes are generated using a Minimum Spanning Tree (MST) algorithm combined with proximity-based shortcut connections to form the path network.

### User Flow:
1. **Entering the Galaxy**: The player enters the map view upon starting a new game or connecting to a multiplayer lobby room.
2. **Navigation**: The user pans across the 2D coordinate space using Right-Click or Middle-Click drag. Zooming and scrolling adapt dynamically.
3. **Selection**: Left-clicking a star system highlights the node with a golden selection ring. The right-hand sidebar panel updates with details of the selected system.
4. **Inspecting Stars**: The sidebar displays the system owner, coordinates, connected star lanes, orbited planets, stationed fleets, and hangar storage.
5. **Fleet Dispatch**:
   - The user selects a stationed fleet, chooses a connected destination node from the target dropdown list, and clicks **Deploy** (if player-owned) or **Attack** (if hostile/neutral).
   - Once dispatched, the fleet is shown on the map canvas as a colored triangle (corresponding to the owning faction's color) sliding along the warp lane with a real-time travel progress percentage.

---

## 2. Architecture & Code Entry Points
The map structure follows a Model-View-Controller design pattern:

- **Controller/Manager**:
  - `src/core/managers/galaxy_manager.gd`: The core manager driving the map. It handles procedural node coordinates generation, connects lanes, processes real-time fleet movement ticks, resolves arrivals, triggers battles on node collision, and manages automated turn-based ticking.
- **Data Models**:
  - `src/core/models/galaxy_node.gd`: Represents a star system. Holds system ID, display name, 2D coordinates vector, owner name, connected node ID arrays, stationed fleets list, planets list, and auto-management configurations.
  - `src/core/models/fleet.gd`: Represents a fleet entity. Tracks its composition (ship design name to quantity), current node location, target node destination, travel progress (0.0 to 1.0), and speed.
- **UI Scenes/Scripts**:
  - `src/ui/galaxy_map_ui.tscn` / `src/ui/galaxy_map_ui.gd`: Coordinates the sidebar panels, renders the solar system orbit layouts, manages fleet dispatch controls, and hooks client RPC requests.
  - `src/ui/galaxy_map_draw.gd`: Renders the 2D canvas. Draws the warp lanes, star system circles, core reflection glares, rotating orbit paths, moving fleet triangle nodes, active battle crossed swords indicators, and handles drag-and-drop coordinate panning.

---

## 3. Technical Design & Algorithms

### Data Serialization/Storage
The galaxy state is authoritative on the server (or host). The entire map structure is serializable since `GalaxyManager`, `GalaxyNode`, `Fleet`, and `Planet` extend Godot's built-in `Resource` class. 
Snapshot replication is performed using binary streams:
* **Serialization**: `var_to_bytes_with_objects(galaxy_manager)`
* **Deserialization**: `bytes_to_var_with_objects(snapshot_bytes) as GalaxyManager`
Signals are reconnected client-side using `galaxy_manager.reconnect_signals()` upon deserialization.

### Algorithms/Calculations

#### 1. Procedural Name Generation
Star systems are dynamically named by combining 20 base names with procedural greek prefixes and cosmic suffixes:
```
Name = Prefix (Greek Prefix [English]) + Suffix (Cosmic Suffix [English])
Example: "阿尔法星区 (Alpha Sector)"
```
Up to 120 unique combinations are generated and cached in a set to prevent collision.

#### 2. Layout Positioning
* **Multiplayer**: Generates exactly 100 systems randomly distributed inside a $1800 \times 1800$ viewport container (boundaries $100.0$ to $1900.0$) ensuring a minimum spacing distance of $100.0$ units.
* **Singleplayer**:
  - *Small*: 20 systems, spacing $\ge 85.0$ units.
  - *Medium*: 50 systems, spacing $\ge 90.0$ units.
  - *Large*: 100 systems, spacing $\ge 100.0$ units.
Factions' starting systems are placed first, separated from each other by at least $140.0$ to $350.0$ units depending on map size.

#### 3. Lane Connectivity (Minimum Spanning Tree)
To guarantee all systems are interconnected (no isolated nodes), the generator runs Prim's algorithm to establish a Minimum Spanning Tree:
1. Initialize a `visited` list containing the first node, and an `unvisited` list containing all other nodes.
2. While `unvisited` is not empty:
   - Find nodes $u \in \text{visited}$ and $v \in \text{unvisited}$ that minimize the Euclidean distance:
     $$d(u, v) = \sqrt{(u.x - v.x)^2 + (u.y - v.y)^2}$$
   - Create a bidirectional connection (warp lane) between $u$ and $v$.
   - Move $v$ from `unvisited` to `visited`.

#### 4. Proximity Shortcut Connections
To make navigation interesting, additional warp lanes are created between close nodes:
- Warp lanes are added if $d(u, v) < \text{prox\_limit}$ ($250.0$ in multiplayer, $160.0$ in singleplayer).
- To prevent clutter, a lane is only created if both nodes currently have fewer than 3 connections.

#### 5. Shortest Path Navigation (BFS)
When a fleet is dispatched, its path is determined using a Breadth-First Search (BFS) algorithm:
1. Start a search queue with a path containing only the origin system ID: `[[start_id]]`.
2. Pop the front path. Let $c$ be the last node in this path.
3. If $c == \text{end\_id}$, return the path (excluding the start element).
4. Otherwise, for each neighbor $n$ of $c$ not yet visited:
   - Add a duplicate of the current path with $n$ appended to the queue.
5. If the queue becomes empty and no path is found, the target is unreachable.

#### 6. Fleet Travel Time / ETA
The speed of a fleet is the weighted average speed of its constituent ship designs:
$$S_{\text{avg}} = \frac{\sum_{i} (S_i \cdot N_i)}{\sum_i N_i}$$
where $S_i$ is the speed of design $i$, and $N_i$ is the quantity of design $i$.
For each hop, the travel time in seconds is:
$$T_{\text{travel}} = \frac{\text{Distance}(Node_{\text{origin}}, Node_{\text{target}})}{S_{\text{avg}}} \times 3.0$$

### RPC/Network API
- `@rpc("any_peer", "reliable") func server_request_dispatch_fleet(fleet_name: String, origin_node_id: String, target_node_id: String)`: Sent by client to move a fleet. The server:
  1. Checks if the remote sender ID mapped to a faction name (`peer_` + sender_id) matches the owner of the fleet.
  2. Verifies path availability. Hostile systems block reassignments.
  3. Begins ticking the fleet on the server's moving list, distributing coordinates snapshots to all clients.

---

## 4. Development Status
- **Current Status**: Completed.
- **Recent Updates**: Reworked UI panels to adopt a translucent glassmorphism HUD design with neon cyan borders. Added active queue pulse indicators on system nodes.
- **Known Issues / Tech Debts**: The BFS pathfinder calculates distance by hops (edge count) instead of physical spatial coordinates (Dijkstra's algorithm), which can result in slightly suboptimal routes on skewed networks.
