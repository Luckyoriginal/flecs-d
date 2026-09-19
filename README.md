# Flecs D Bindings (Better-C)

High-performance, type-safe Flecs ECS bindings for the **D programming language**, designed specifically for **`-betterC`** mode.

It replicates the modern, fluent ergonomics of the **Flecs C++ API** directly in D using compile-time metaprogramming, structs, and templates with zero GC overhead and no C++ runtime dependencies.

---

## Implemented Core Features

The full core ECS feature set (outside optional add-ons) is implemented and verified:

1. **Singletons**:
   - Store and retrieve world-level unique components: `world.set!T(value)`, `world.get!T()`, `world.get_mut!T()`, `world.has!T()`, `world.remove!T()`, `world.modified!T()`.
2. **Prefabs & `IsA` Inheritance**:
   - Define prefabs: `world.prefab("Orc").set(...)`.
   - Instantiate with inheritance: `world.entity("orc_1").is_a(orcPrefab)`.
   - Override inherited components with `.set(...)` or `.override_!T()`.
   - Check component ownership: `entity.owns!T()` vs inherited `entity.has!T()`.
3. **Observers & Reactive Events**:
   - React to ECS lifecycle events: `world.observer!(Position)().event(EcsOnAdd).event(EcsOnSet).each(...)`.
   - Event types: `EcsOnAdd`, `EcsOnSet`, `EcsOnRemove`, `EcsMonitor`.
   - Supports both `.each((Entity e, ref T...) { ... })` and `.run((ref Iter it) { ... })`.
4. **Queries & Filters**:
   - Cached queries: `world.query!(Position, Velocity)()`.
   - Uncached ad-hoc queries (Filters): `world.filter!(Position, Velocity)()`.
   - Query builders: `world.query_builder!(Position)().expr("...").cache_kind(...).build()`.
5. **Component Lifecycle Hooks**:
   - Custom `ctor`, `dtor`, `copy`, `move`, `on_add`, `on_set`, `on_remove` callbacks:
     ```d
     world.hooks!Resource()
         .on_add(&onAddCallback)
         .on_remove(&onRemoveCallback)
         .build();
     ```
6. **Hierarchy & Path Lookups**:
   - Parent-child relationships: `child.child_of(parent)`, `child.parent()`.
   - Entity naming & relative path introspection: `entity.name()`, `entity.path()`.
   - Entity lookups: `world.lookup("Parent.Child")`, `world.lookup_child(parent, "Child")`.
7. **Entity Enabling & Disabling**:
   - Entities: `entity.enable()`, `entity.disable()`, `entity.is_enabled()`.
   - Components: `entity.enable!T()`, `entity.disable!T()`, `entity.is_enabled!T()`.
8. **Entity Cloning**:
   - Deep and shallow component copying: `entity.clone(copy_values = true)`.
9. **Deferral & Batch Operations**:
   - Batch entity counting: `world.count!Position()`.
   - Batch entity deletion: `world.delete_with!Position()`.
   - Safe structural modification queues: `world.defer(() { ... })`, `world.defer_begin()`, `world.defer_end()`.
10. **Systems & Pipelines**:
    - Phased systems integrated with `world.progress()`: `world.system!(Position, Velocity)("Movement").kind(EcsOnUpdate).each(...)`.
    - Interval timers and direct runners with `ref Iter`.

---

## Quick Example

```d
import core.stdc.stdio : printf;
import flecs;

struct Position { float x, y; }
struct Velocity { float dx, dy; }
struct GameConfig { int maxPlayers; }
struct EnemyTag {}

extern(C) int main(int argc, char** argv) {
    // 1. Create the ECS World
    auto world = World.create();
    scope(exit) world.destroy();

    // 2. Singletons
    world.set(GameConfig(64));
    printf("Max players: %d\n", world.get!GameConfig().maxPlayers);

    // 3. Observers
    world.observer!Position()
        .event(EcsOnSet)
        .each((Entity e, ref Position p) {
            printf("[Observer] Entity %s Position updated to (%.1f, %.1f)\n", e.name(), p.x, p.y);
        });

    // 4. Prefabs & Inheritance
    auto warriorPrefab = world.prefab("Warrior")
        .set(Position(0.0f, 0.0f))
        .set(Velocity(1.0f, 0.0f))
        .add!EnemyTag();

    auto warrior1 = world.entity("warrior_1")
        .is_a(warriorPrefab);

    // 5. Systems in EcsOnUpdate phase
    world.system!(Position, Velocity)("MovementSystem")
        .kind(EcsOnUpdate)
        .each((Entity e, ref Position p, ref Velocity v) {
            p.x += v.dx;
            p.y += v.dy;
        });

    // 6. Progress World
    world.progress(0.016f);

    // 7. Uncached Filters (one-off iteration)
    auto flt = world.filter!(Position, Velocity)();
    flt.each((Entity e, ref Position p, ref Velocity v) {
        printf("%s -> (%.1f, %.1f)\n", e.name(), p.x, p.y);
    });
    flt.destroy();

    return 0;
}
```

---

---

## Using with DUB

`flecs-d` is configured as a `sourceLibrary` with `"buildOptions": ["betterC"]`.

### 1. In your project's `dub.json`:

#### Option A: Path Dependency
```json
{
    "name": "my-game",
    "targetType": "executable",
    "buildOptions": ["betterC"],
    "dependencies": {
        "flecs-d": { "path": "../path/to/flecs-d" }
    }
}
```

#### Option B: Local Registry Registration
Register `flecs-d` once locally on your system:
```bash
dub add-local /path/to/flecs-d 0.1.0
```
Then simply declare it by version in any project:
```json
{
    "name": "my-game",
    "targetType": "executable",
    "buildOptions": ["betterC"],
    "dependencies": {
        "flecs-d": "~>0.1.0"
    }
}
```

#### Option C: Direct GitHub Git Dependency
Anyone can consume this package directly from GitHub without cloning it manually:
```json
{
    "name": "my-game",
    "targetType": "executable",
    "buildOptions": ["betterC"],
    "dependencies": {
        "flecs-d": {
            "repository": "git+https://github.com/Luckyoriginal/flecs-d.git",
            "version": "~master"
        }
    }
}
```

### 2. Run the Included DUB Example

A working DUB project is provided under [`examples/dub_example/`](file:///home/lucky/project/d/flecs-d/examples/dub_example):

```bash
cd examples/dub_example
dub run --compiler=ldc2
```

---

## Building and Running Everything

Run the automated test and build script:

```bash
./build.sh
```

This compiles and runs:
1. `bin/basics`: Basic entities, queries, and phased systems.
2. `bin/core_features`: Full end-to-end ECS test suite (Singletons, Prefabs, Observers, Hooks, Filters, Deferral, Hierarchies, Cloning).
3. `examples/dub_example`: Complete standalone DUB project building and running with `dub run --compiler=ldc2`.

---

## Project Structure

```
flecs-d/
├── source/
│   └── flecs/
│       ├── c.d               # Raw Flecs 4.x C declarations, types, layouts, and constants
│       └── package.d         # High-level C++-style Better-C API
├── examples/
│   ├── basics.d              # Introduction example (entities, queries, systems)
│   ├── core_features.d       # Full core ECS test suite exercising all 10 subsystems
│   └── dub_example/          # Standalone DUB project importing flecs-d
│       ├── dub.json
│       └── source/app.d
├── build.sh                  # One-step compilation and execution script using ldc2 & dub
├── dub.json                  # DUB package definition for flecs-d library
└── README.md
```
