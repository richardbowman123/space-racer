# SPACE RACER — Build Plan

## Objective
Get to a go/no-go decision as fast as possible by building the core racing prototype in Godot 4.x. Everything else (narrative, art, progression) comes after approval.

---

## Prerequisites

### Godot Setup
- **Godot 4.3+** (stable) — download from godotengine.org
- Use the **standard** build (not .NET) — GDScript is simpler and sufficient
- Mobile export templates installed if testing on device

### Project Initialisation
Open Godot → New Project → select the `Space Racer` folder → Create & Edit. Godot will generate `project.godot` and `.godot/` directory automatically.

---

## Phase 1 Build Steps (Go/No-Go Prototype)

### Step 1: Track Spline System
**Goal**: A winding 3D path that defines the race course.

**Tasks**:
1. Create `scenes/tracks/test_track.tscn`
2. Add a `Path3D` node with `Curve3D` resource
3. Define control points for "The Kessel Stretch" layout:
   - Gentle S-curves → asteroid slalom → tunnel dive → corkscrew → speed straight → chicane
4. Create `scripts/tracks/track_manager.gd`:
   - Expose track spline for other systems to query
   - Calculate progress along track (0.0 to 1.0)
   - Provide nearest-point-on-spline queries for the guide force
5. Generate visual track geometry:
   - Option A: Extruded mesh along spline (CSG or procedural)
   - Option B: Repeated segment meshes placed along path
   - Use a simple grid/glow material for prototype

**Deliverable**: A visible winding track floating in space that you can orbit around in the editor.

---

### Step 2: Ship & Physics
**Goal**: A ship that moves forward along/near the track with physics-based steering.

**Tasks**:
1. Create `scenes/ships/player_ship.tscn`
2. Use `CharacterBody3D` (more control than RigidBody for racing feel):
   - Forward movement: constant velocity along track tangent direction
   - Lateral/vertical offset from track centre based on steering input
   - Guide force: spring-like pull toward track centre, strength proportional to distance
3. Create `scripts/ships/ship_controller.gd`:
   - `_physics_process()` handles movement each frame
   - Track the ship's progress along the spline
   - Apply forward velocity in the spline's tangent direction at current progress
   - Apply steering offset perpendicular to the track
   - Apply guide force pulling back toward centre
   - Recovery snap if distance exceeds threshold
4. Placeholder ship mesh:
   - Simple `MeshInstance3D` with a cone/wedge shape
   - Emissive material on rear face for engine glow
5. Add `GPUParticles3D` for engine trail

**Deliverable**: A ship that flies forward along the track, maintaining orientation with the path.

---

### Step 3: Touch/Mouse Input
**Goal**: Single-finger drag steering that feels precise and responsive.

**Tasks**:
1. Create `scripts/core/touch_input.gd` (autoload singleton):
   - Detect touch begin → record anchor point
   - Track drag delta from anchor
   - Normalise to screen-relative values (-1 to 1 on each axis)
   - Apply dead zone (central ~10% ignored)
   - Apply sensitivity curve (non-linear, more precision near centre)
   - On release → return to (0, 0) with smoothing
   - Support mouse input as equivalent (for desktop testing)
2. Wire input to `ship_controller.gd`:
   - X input → lateral steering force
   - Y input → vertical steering force
   - Steering sensitivity scales inversely with current speed

**Deliverable**: Drag anywhere on screen to steer the ship smoothly through the track.

---

### Step 4: Camera Rig
**Goal**: A chase camera that sells speed and reads the track geometry.

**Tasks**:
1. Create `scripts/core/camera_rig.gd`:
   - Position: behind ship along negative track tangent, offset up
   - Look-at: point ahead of ship on track (not at ship directly)
   - Smooth follow with configurable lag (lerp/slerp)
   - Roll: camera banks into turns (match track bank angle, damped)
   - FOV: base 70°, scales up to ~90° at max speed
   - Optional subtle shake at high speed
2. Camera is a child of Main scene, not the ship (avoids jitter)
3. Tune damping values until it feels cinematic but not nauseating

**Deliverable**: Camera that swoops through the track behind the ship, banking into turns, widening FOV at speed.

---

### Step 5: Speed Zones
**Goal**: Boost pads and slow zones that create gameplay variety.

**Tasks**:
1. Create `scenes/tracks/boost_zone.tscn`:
   - `Area3D` with `CollisionShape3D` (box trigger)
   - Glowing animated material (shader with scrolling UV)
   - On body entered → signal to ship controller
2. Create `scenes/tracks/slow_zone.tscn`:
   - Same structure, different visual (red/orange particles, debris mesh)
   - On body entered → reduce speed, add screen effect
3. Create `scripts/tracks/boost_zone.gd` and `slow_zone.gd`
4. Place zones along test track at strategic points
5. Ship controller responds:
   - Boost: multiply speed by 1.5x, decay back to base over 2-3 seconds
   - Slow: reduce speed to 0.6x while in zone, recover on exit
6. Visual feedback:
   - Boost: blue/white particle burst, FOV spike, motion lines
   - Slow: screen tint, particle debris, speed lines disappear

**Deliverable**: Racing through the track with clear fast/slow sections that change the feel.

---

### Step 6: Environment & Atmosphere
**Goal**: Make the space setting feel real enough to evaluate.

**Tasks**:
1. Create `WorldEnvironment` node:
   - Procedural sky or `PanoramaSky` with star texture
   - Ambient light (low, blue-tinted)
   - `DirectionalLight3D` (distant sun)
   - Glow post-processing enabled
   - Fog for depth (very subtle, long range)
2. Scatter simple asteroid meshes (sphere/rock shapes) around track
3. Add distant backdrop geometry (planet, nebula planes)
4. Engine particles, boost particles, speed lines (GPUParticles3D)

**Deliverable**: A space environment that feels atmospheric enough to judge the racing experience.

---

### Step 7: Basic HUD
**Goal**: Minimum information overlay for testing.

**Tasks**:
1. Create `scenes/ui/hud.tscn` (CanvasLayer):
   - Speed readout (numeric + bar)
   - Track progress indicator (% or minimap dot)
   - FPS counter (debug, toggle-able)
2. Create `scripts/ui/hud.gd`
3. Style: minimal, semi-transparent, futuristic font

**Deliverable**: Clean overlay showing speed and progress.

---

### Step 8: Integration & Tuning
**Goal**: Wire everything together and tune until it feels right.

**Tasks**:
1. Create `scenes/main.tscn` — master scene combining all elements
2. Create `scripts/core/game_manager.gd`:
   - Simple state: READY → RACING → FINISHED
   - Start countdown (3-2-1-GO visual)
   - Track completion detection
   - Basic finish screen with time
3. **Tuning pass** (this is where the game lives or dies):
   - Ship speed (base, boost, slow multipliers)
   - Steering sensitivity and dead zone
   - Guide force strength and recovery threshold
   - Camera lag, offset, FOV range
   - Track point spacing and curvature
4. Test on both desktop (mouse) and mobile (touch) if possible

**Deliverable**: Complete playable prototype ready for go/no-go evaluation.

---

## Estimated Build Order & Dependencies

```
Step 1: Track ──────────┐
                        ├── Step 2: Ship (needs track)
Step 3: Input ──────────┤
                        ├── Step 4: Camera (needs ship + track)
                        │
Step 5: Speed Zones ────┤ (needs track + ship)
Step 6: Environment ────┤ (independent, parallel)
Step 7: HUD ────────────┤ (needs game manager)
                        │
                        └── Step 8: Integration & Tuning
```

Steps 1, 3, and 6 can be built in parallel. Steps 2 and 4 are sequential. Step 8 is the critical tuning phase.

---

## Key Technical Decisions

### CharacterBody3D vs RigidBody3D for Ship
**Recommendation: CharacterBody3D**
- More direct control over movement (no fighting physics engine)
- Easier to implement the guided-flight model
- Can still detect collisions via `move_and_slide()`
- RigidBody would give more realistic bounce/crash but makes steering harder to tune

### Track Geometry Generation
**Recommendation: CSGPolygon3D in Path mode (prototype), then custom mesh later**
- CSGPolygon3D can extrude a shape along a Path3D — instant visual track
- Performance isn't great for CSG at scale, but fine for a prototype
- Replace with procedural `ArrayMesh` in Phase 2 if needed

### Guide Force Model
**Recommendation: Spring-damper system**
```
guide_force = -spring_constant * offset_from_centre - damping * lateral_velocity
```
- Feels natural (like a rubber band, not a wall)
- Tuneable: low spring = freedom, high spring = on-rails
- Add hard recovery at max distance threshold

---

## File Structure After Phase 1

```
Space Racer/
├── project.godot
├── GAME_DESIGN_SPEC.md
├── BUILD_PLAN.md
├── scenes/
│   ├── main.tscn
│   ├── tracks/
│   │   ├── test_track.tscn
│   │   ├── boost_zone.tscn
│   │   └── slow_zone.tscn
│   ├── ships/
│   │   └── player_ship.tscn
│   ├── ui/
│   │   └── hud.tscn
│   └── effects/
│       └── (particle scenes)
├── scripts/
│   ├── core/
│   │   ├── game_manager.gd
│   │   ├── touch_input.gd
│   │   └── camera_rig.gd
│   ├── ships/
│   │   └── ship_controller.gd
│   ├── tracks/
│   │   ├── track_manager.gd
│   │   ├── boost_zone.gd
│   │   └── slow_zone.gd
│   └── ui/
│       └── hud.gd
├── assets/
│   ├── models/
│   ├── textures/
│   ├── audio/
│   └── fonts/
└── resources/
    └── (materials, themes)
```

---

## Next Steps After Go/No-Go Approval
1. AI opponent ships (basic path-following with speed variation)
2. Collision and crash system
3. Sound design (engine hum, boost whoosh, ambient space)
4. Gemini art pipeline for ship textures and skyboxes
5. Multiple tracks
6. Career/narrative system
