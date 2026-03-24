# SPACE RACER — Game Design Specification

## Vision
A 3D space racing game inspired by Star Wars pod-racing and early PlayStation racers (Wipeout, Star Wars Episode I: Racer). Players control a speeding spacecraft with a single finger, navigating winding, rollercoaster-like tracks through spectacular space environments. A narrative layer — trials, sponsorships, treasure, and ship upgrades — gives the racing purpose and progression.

---

## 1. Core Racing Experience (Go/No-Go Prototype)

### 1.1 The Feel
The ship is always moving forward at high speed. The track winds through 3D space like a rollercoaster — banking left, climbing, diving, corkscrewing. The player's job is to keep the ship on the optimal racing line while reacting to speed boosts and hazards.

The camera sits behind and slightly above the ship, with subtle lag and roll to sell the sense of speed and momentum. Motion blur and particle trails reinforce velocity.

### 1.2 Controls — Drag to Steer
- **Touch/click and hold** anywhere on screen to engage steering
- **Drag relative to initial touch point** to steer: left/right for lateral movement, up/down for vertical
- **Release** to auto-centre (ship drifts back to neutral position)
- Sensitivity scales with speed — faster = tighter, more responsive steering needed
- Dead zone in centre prevents twitchy micro-corrections
- Visual indicator shows current steering input (subtle reticle or ship lean)

### 1.3 Track Design — Free Flight, Guided
The track is defined by a 3D spline/path through space. The ship can fly freely in 3D around this path, but:
- A **guide force** gently pulls the ship back toward the track centre (like a gravity well)
- The force increases the further you drift from the path
- Fly too far off and a **recovery system** snaps you back (with a time penalty)
- Track boundaries are suggested by environmental geometry (asteroids, station walls, energy gates) rather than hard invisible walls where possible

### 1.4 Speed System (Prototype Scope)
- **Base speed**: Constant forward velocity along the track spline
- **Boost pads**: Glowing zones on/near the track that increase speed temporarily
- **Slow zones**: Asteroid debris fields, energy barriers, or tight turns that reduce speed
- **Drafting** (stretch goal): Speed bonus when close behind another racer
- Speed is communicated through FOV widening, motion blur intensity, and particle density

### 1.5 Camera System
- Third-person chase camera, offset behind and above
- Camera follows track spline orientation (banks with turns, tilts with climbs)
- Slight delay/smoothing so the ship leads the camera into turns
- FOV increases with speed for visceral impact
- Subtle screen shake at very high speeds

---

## 2. Track Architecture

### 2.1 Track as Spline
Each track is defined by a **Curve3D** (Godot's Path3D node):
- Control points define the racing line
- Track width/height defined per segment
- Environmental pieces (tunnels, open space, asteroid fields) are placed along the spline
- This allows procedural placement of boost pads, hazards, and scenery

### 2.2 Prototype Track: "The Kessel Stretch"
A single test track with variety:
1. **Start straight** — open space, gentle curves, learn controls
2. **Asteroid slalom** — weave through floating rocks, slow zones
3. **Tunnel dive** — enclosed section, tight turns, boost pads on walls
4. **Corkscrew** — dramatic spiral section, tests vertical control
5. **Speed straight** — long boost-pad gauntlet, max velocity
6. **Finish approach** — technical chicane before the line

### 2.3 Environmental Zones (Full Game)
- Nebula circuits (colourful gas clouds, low visibility sections)
- Asteroid belts (dense obstacle fields)
- Space station interiors (tight corridors, mechanical hazards)
- Planetary rings (racing along/through ring debris)
- Black hole proximity (warped visuals, gravitational pull)

---

## 3. Ship Design

### 3.1 Prototype Ship
A single placeholder ship with:
- Clear forward-facing orientation (cockpit/nose visible)
- Engine glow/particles from rear (communicates thrust)
- Banking animation when turning (roll into turns)
- Subtle pitch when climbing/diving

### 3.2 Full Game Ships (Post Go/No-Go)
Multiple ship classes with different stats:
- **Speed** — top velocity
- **Handling** — steering responsiveness
- **Durability** — resistance to collisions
- **Boost efficiency** — how much benefit from boost pads

Ship visuals will be 2D artwork (created in Gemini) applied as textures/sprites, consistent with your Dart Attack pipeline.

---

## 4. Narrative & Progression (Post Go/No-Go)

### 4.1 Career Structure
1. **Underground Trials** — Prove yourself in unsanctioned races
2. **Get Signed** — Impress a sponsor team
3. **League Racing** — Compete in official circuits
4. **Championship** — Win the galaxy's premier racing series
5. **Legendary Status** — Unlock secret tracks and legendary ships

### 4.2 Economy
- **Credits** — Won from races, used for upgrades and new ships
- **Treasure** — Hidden collectibles on tracks, trade for rare parts
- **Sponsor bonuses** — Complete sponsor challenges for extra rewards
- **Ship upgrades** — Speed, handling, durability, boost modules

### 4.3 Race Types
- **Circuit** — Multiple laps, standard race
- **Sprint** — Point-to-point, single run
- **Time Trial** — Beat the clock, ghost ship of best time
- **Elimination** — Last place eliminated each lap
- **Treasure Run** — Collect as many hidden items as possible

---

## 5. Technical Architecture (Godot 4.x)

### 5.1 Scene Tree (Prototype)
```
Main (Node3D)
├── Track (Path3D + PathFollow3D)
│   ├── TrackMesh (MeshInstance3D) — visual track geometry
│   ├── BoostZones (Area3D nodes along path)
│   └── SlowZones (Area3D nodes along path)
├── PlayerShip (CharacterBody3D / RigidBody3D)
│   ├── ShipMesh (MeshInstance3D)
│   ├── EngineParticles (GPUParticles3D)
│   ├── Camera (Camera3D with script)
│   └── CollisionShape (CollisionShape3D)
├── Environment (WorldEnvironment)
│   ├── Skybox (stars/nebula)
│   └── Lighting (DirectionalLight3D + ambient)
├── HUD (CanvasLayer)
│   ├── Speedometer
│   ├── Position/Lap
│   └── SteeringIndicator
└── GameManager (Node — state, timing, scoring)
```

### 5.2 Key Scripts
| Script | Responsibility |
|---|---|
| `ship_controller.gd` | Physics, steering input, speed management |
| `track_manager.gd` | Track spline, progress tracking, lap counting |
| `camera_rig.gd` | Chase camera, FOV scaling, smoothing |
| `touch_input.gd` | Single-finger drag detection, dead zones |
| `boost_zone.gd` | Speed boost on entry, visual feedback |
| `slow_zone.gd` | Speed reduction, particle effects |
| `hud.gd` | Speed display, position, lap counter |
| `game_manager.gd` | Race state machine (countdown → racing → finish) |

### 5.3 Performance Targets
- 60 FPS on mid-range mobile devices
- Draw calls minimised through mesh batching
- LOD system for distant track geometry
- Particle budgets per effect type

---

## 6. Art Pipeline

### 6.1 Approach
- **Ships**: 2D artwork created in Gemini, applied as billboard sprites or textured planes (as per Dart Attack workflow)
- **Track**: Procedural geometry generated from spline data, with material-based visual variation
- **Environment**: Skybox textures (Gemini), particle effects (Godot), simple geometric obstacles
- **UI**: Clean, futuristic HUD overlays

### 6.2 Placeholder Art (Prototype)
- Ship: Simple geometric mesh (arrow/wedge shape) with emissive engine glow
- Track: Extruded tube/ribbon along spline with grid texture
- Skybox: Dark with star particle field
- Boost pads: Glowing planes with animated shader

---

## 7. Go/No-Go Criteria

The prototype is approved if the following all feel good:

1. **Controls feel intuitive** — Single finger drag steering is responsive and precise
2. **Sense of speed** — The game feels fast and exciting
3. **Track navigation** — Winding 3D path feels like a rollercoaster, not disorienting
4. **Guide system works** — Free flight with gentle path-correction feels natural, not restrictive
5. **Speed variation** — Boost pads and slow zones create meaningful gameplay moments
6. **Camera sells it** — Chase camera conveys speed and track geometry without causing nausea
7. **Performance** — Smooth frame rate on target devices

---

## 8. Build Phases

### Phase 1: Core Prototype (GO/NO-GO)
Ship on track with drag steering, speed zones, chase camera. Single test track. Placeholder art. **This is what we build first.**

### Phase 2: Racing Polish
AI opponents, race state machine (countdown/finish), lap system, basic HUD, collision feedback, sound effects.

### Phase 3: Ship & Art Pipeline
Gemini artwork integration, multiple ship models, visual effects polish, skybox environments.

### Phase 4: Narrative & Progression
Career mode, sponsor system, credits/economy, ship upgrades, multiple tracks.

### Phase 5: Content & Polish
Additional tracks, race types, music, menus, leaderboards, difficulty balancing.
