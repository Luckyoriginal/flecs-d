module examples.basics;

import core.stdc.stdio : printf;
import flecs;

// Define components as plain D structs (BetterC compatible)
struct Position {
    float x, y;
}

struct Velocity {
    float x, y;
}

struct Health {
    int current;
    int max;
}

// Tag component (zero-sized)
struct PlayerTag {}

extern(C) int main(int argc, char** argv) {
    printf("=== Flecs D Binding Example (Better-C Mode) ===\n\n");

    // 1. Initialize the Flecs World
    auto world = World.create();

    // 2. Fluent entity creation (matching the Flecs C++ API ergonomics)
    auto player = world.entity("Player")
        .add!PlayerTag()
        .set(Position(100.0f, 200.0f))
        .set(Velocity(2.0f, -1.0f))
        .set(Health(100, 100));

    auto enemy = world.entity("Goblin")
        .set(Position(50.0f, 60.0f))
        .set(Velocity(-0.5f, 0.5f))
        .set(Health(30, 30));

    printf("Created entity '%s' (id: %llu)\n", player.name(), player.id);
    printf("Created entity '%s' (id: %llu)\n", enemy.name(), enemy.id);
    printf("Player has PlayerTag: %s\n", player.has!PlayerTag() ? "true".ptr : "false".ptr);

    // 3. Parent-Child hierarchy (Relationships)
    auto sword = world.entity("Sword")
        .child_of(player)
        .set(Position(1.0f, 0.0f));

    printf("Sword parent name: '%s'\n\n", sword.parent().name());

    // 4. Component inspection
    const(Position)* initPos = player.get!Position();
    if (initPos) {
        printf("Initial Player position: (%f, %f)\n", initPos.x, initPos.y);
    }

    // 5. High-level Query with .each() callback (with Entity parameter)
    printf("\n--- Querying (Position, Velocity) with Entity ---\n");
    auto q = world.query!(Position, Velocity)();
    q.each((Entity e, ref Position p, ref Velocity v) {
        printf("Entity %s -> Position: (%f, %f), Velocity: (%f, %f)\n",
            e.name(), p.x, p.y, v.x, v.y);
    });
    q.destroy();

    // 6. Define a System with .each() that runs in EcsOnUpdate during world.progress()
    world.system!(Position, Velocity)("MovementSystem")
        .kind(EcsOnUpdate)
        .each((Entity e, ref Position p, ref Velocity v) {
            p.x += v.x;
            p.y += v.y;
            printf("[MovementSystem] %s moved to (%f, %f)\n", e.name(), p.x, p.y);
        });

    // 7. Progress the world for several frames
    printf("\n--- Progressing world (Frame 1) ---\n");
    world.progress(1.0f / 60.0f);

    printf("\n--- Progressing world (Frame 2) ---\n");
    world.progress(1.0f / 60.0f);

    // 8. Inspect updated components
    const(Position)* updatedPos = player.get!Position();
    if (updatedPos) {
        printf("\nPlayer final position after 2 ticks: (%f, %f)\n", updatedPos.x, updatedPos.y);
    }

    // 9. Destroy the world and release resources
    world.destroy();
    printf("\nWorld cleanly destroyed. Done!\n");
    return 0;
}
