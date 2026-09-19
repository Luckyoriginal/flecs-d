module core_features;

import flecs;
import core.stdc.stdio;
import core.stdc.assert_;

// Components & Tags
struct Position {
    float x;
    float y;
}

struct Velocity {
    float dx;
    float dy;
}

struct Health {
    int current;
    int max;
}

struct GameConfig {
    int width;
    int height;
    bool fullscreen;
}

struct ManagedResource {
    int id;
}

struct EnemyTag {}
struct BossTag {}

extern(C) int main() {
    setvbuf(stdout, null, _IONBF, 0);
    printf("=== Testing Flecs Full Core Features in Better-C ===\n\n");

    World world = World.create();
    scope(exit) world.destroy();

    // ------------------------------------------------------------------------
    // 1. Singletons
    // ------------------------------------------------------------------------
    printf("1. Testing Singletons...\n");
    assert(!world.has!GameConfig());
    world.set(GameConfig(1920, 1080, true));
    assert(world.has!GameConfig());

    const(GameConfig)* cfg = world.get!GameConfig();
    assert(cfg !is null);
    assert(cfg.width == 1920 && cfg.height == 1080 && cfg.fullscreen == true);

    GameConfig* mutCfg = world.get_mut!GameConfig();
    assert(mutCfg !is null);
    mutCfg.fullscreen = false;
    world.modified!GameConfig();

    assert(world.get!GameConfig().fullscreen == false);
    printf("   Singletons OK.\n\n");

    // ------------------------------------------------------------------------
    // 2. Prefabs & IsA Inheritance
    // ------------------------------------------------------------------------
    printf("2. Testing Prefabs & Inheritance...\n");
    Entity orcPrefab = world.prefab("Orc")
        .set(Position(0.0f, 0.0f))
        .set(Velocity(1.5f, 1.5f))
        .set(Health(100, 100))
        .add!EnemyTag();

    Entity orc1 = world.entity("orc_1")
        .is_a(orcPrefab);

    char* orcType = ecs_type_str(world.handle, ecs_get_type(world.handle, orc1.id));
    printf("   orc1 type: %s\n", orcType);
    printf("   orc1 has EnemyTag: %d, owns EnemyTag: %d\n", orc1.has!EnemyTag(), orc1.owns!EnemyTag());
    ecs_os_free(orcType);

    // Value components inherit the prefab values:
    assert(orc1.has!Position());
    assert(orc1.has!Velocity());
    assert(orc1.has!Health());
    assert(orc1.get!Health().current == 100);

    // Override Position on orc1
    orc1.set(Position(50.0f, 75.0f));
    assert(orc1.owns!Position());
    assert(orc1.get!Position().x == 50.0f);
    // Prefab unchanged
    assert(orcPrefab.get!Position().x == 0.0f);
    printf("   Prefabs & Inheritance OK.\n\n");

    // ------------------------------------------------------------------------
    // 3. Observers (OnAdd, OnSet, OnRemove)
    // ------------------------------------------------------------------------
    printf("3. Testing Observers...\n");
    __gshared int add_events = 0;
    __gshared int set_events = 0;
    __gshared int remove_events = 0;

    world.observer!Health("HealthAddObserver")
        .event(EcsOnAdd)
        .each((Entity e, ref Health h) {
            add_events++;
        });

    world.observer!Health("HealthSetObserver")
        .event(EcsOnSet)
        .each((Entity e, ref Health h) {
            set_events++;
        });

    world.observer!Health("HealthRemoveObserver")
        .event(EcsOnRemove)
        .each((Entity e, ref Health h) {
            remove_events++;
        });

    Entity testEnt = world.entity("ObserverTestEntity");
    testEnt.set(Health(50, 100)); // triggers OnAdd and OnSet
    assert(add_events >= 1);
    assert(set_events >= 1);

    testEnt.remove!Health();      // triggers OnRemove
    assert(remove_events >= 1);
    printf("   Observers OK (Add: %d, Set: %d, Remove: %d).\n\n", add_events, set_events, remove_events);

    // ------------------------------------------------------------------------
    // 4. Entity Enabling & Disabling
    // ------------------------------------------------------------------------
    printf("4. Testing Entity Enabling & Disabling...\n");
    Entity goblin = world.entity("Goblin").set(Position(10.0f, 10.0f));
    assert(goblin.is_enabled());

    goblin.disable();
    assert(!goblin.is_enabled());

    goblin.enable();
    assert(goblin.is_enabled());

    // Component-level enable/disable requires EcsCanToggle trait added before use
    struct ActiveState { bool active; }
    ecs_entity_t actId = world.id!ActiveState();
    ecs_add_id(world.handle, actId, EcsCanToggle);

    Entity actEnt = world.entity("ActEnt").set(ActiveState(true));
    assert(actEnt.is_enabled!ActiveState());
    actEnt.disable!ActiveState();
    assert(!actEnt.is_enabled!ActiveState());
    actEnt.enable!ActiveState();
    assert(actEnt.is_enabled!ActiveState());
    printf("   Entity & Component Enable/Disable OK.\n\n");

    // ------------------------------------------------------------------------
    // 5. Hierarchy, Paths & Lookups
    // ------------------------------------------------------------------------
    printf("5. Testing Hierarchy, Paths & Lookups...\n");
    Entity parent = world.entity("Parent");
    Entity child = world.entity("Child").child_of(parent);

    assert(child.parent().id == parent.id);

    char* pPath = parent.path();
    char* cPath = child.path();
    printf("   Parent path: %s\n", pPath);
    printf("   Child path:  %s\n", cPath);
    ecs_os_free(pPath);
    ecs_os_free(cPath);

    Entity foundChild = world.lookup_child(parent, "Child");
    assert(foundChild.id == child.id);
    printf("   Hierarchy & Lookups OK.\n\n");

    // ------------------------------------------------------------------------
    // 6. Filters (Uncached Queries)
    // ------------------------------------------------------------------------
    printf("6. Testing Filters (Uncached Queries)...\n");
    Entity hero = world.entity("Hero")
        .set(Position(1.0f, 2.0f))
        .set(Velocity(0.1f, 0.2f));

    auto flt = world.filter!(Position, Velocity)();
    __gshared int matchCount = 0;
    matchCount = 0;
    flt.each((Entity e, ref Position p, ref Velocity v) {
        matchCount++;
    });
    assert(matchCount >= 1);
    flt.destroy();
    printf("   Filters OK (Matched %d entities).\n\n", matchCount);

    // ------------------------------------------------------------------------
    // 7. Component Lifecycle Hooks
    // ------------------------------------------------------------------------
    printf("7. Testing Component Lifecycle Hooks...\n");
    __gshared int hook_on_add = 0;
    __gshared int hook_on_set = 0;
    __gshared int hook_on_remove = 0;

    extern(C) static void onAddHook(ecs_iter_t* it) {
        hook_on_add++;
    }
    extern(C) static void onSetHook(ecs_iter_t* it) {
        hook_on_set++;
    }
    extern(C) static void onRemoveHook(ecs_iter_t* it) {
        hook_on_remove++;
    }

    world.hooks!ManagedResource()
        .on_add(&onAddHook)
        .on_set(&onSetHook)
        .on_remove(&onRemoveHook)
        .build();

    Entity resEnt = world.entity("ResEntity");
    resEnt.set(ManagedResource(42));
    assert(hook_on_add == 1);
    assert(hook_on_set == 1);
    resEnt.remove!ManagedResource();
    assert(hook_on_remove == 1);
    printf("   Lifecycle Hooks OK.\n\n");

    // ------------------------------------------------------------------------
    // 8. Entity Cloning
    // ------------------------------------------------------------------------
    printf("8. Testing Entity Cloning...\n");
    Entity original = world.entity("Original")
        .set(Position(30.0f, 40.0f))
        .add!BossTag();

    Entity cloned = original.clone(true);
    assert(cloned.has!Position());
    assert(cloned.get!Position().x == 30.0f);
    assert(cloned.has!BossTag());
    assert(cloned.id != original.id);
    printf("   Cloning OK.\n\n");

    // ------------------------------------------------------------------------
    // 9. Deferral & Batch Operations
    // ------------------------------------------------------------------------
    printf("9. Testing Deferral & Batch Operations...\n");
    assert(!world.is_deferred());
    world.defer(() {
        assert(world.is_deferred());
        world.entity("Deferred1").set(Position(1, 1));
        world.entity("Deferred2").set(Position(2, 2));
    });
    assert(!world.is_deferred());

    int posCount = world.count!Position();
    assert(posCount > 0);
    printf("   Entities with Position: %d\n", posCount);

    world.delete_with!ManagedResource();
    printf("   Deferral & Batch Operations OK.\n\n");

    // ------------------------------------------------------------------------
    // 10. Systems & Pipelines
    // ------------------------------------------------------------------------
    printf("10. Testing Systems & Pipelines with runner...\n");
    __gshared int systemsRun = 0;
    world.system!(Position, Velocity)("MovementSystem")
        .kind(EcsOnUpdate)
        .each((Entity e, ref Position p, ref Velocity v) {
            p.x += v.dx;
            p.y += v.dy;
            systemsRun++;
        });

    world.progress(0.016f);
    assert(systemsRun > 0);
    printf("   Systems & Pipelines OK (Ran %d steps).\n\n", systemsRun);

    printf("=== ALL FLECS CORE FEATURES VERIFIED SUCCESSFULLY! ===\n");
    return 0;
}
