module app;

import core.stdc.stdio : printf;
import flecs;

struct Position {
    float x;
    float y;
}

struct Velocity {
    float dx;
    float dy;
}

struct Score {
    int points;
}

extern(C) int main() {
    printf("=== Testing flecs-d from Official DUB Registry (code.dlang.org) ===\n\n");

    World world = World.create();
    scope(exit) world.destroy();

    // 1. Singleton
    world.set(Score(100));
    printf("1. Singleton Score initialized: %d points\n", world.get!Score().points);

    // 2. Observer
    __gshared int observerTriggered = 0;
    world.observer!Position("PosWatcher")
        .event(EcsOnSet)
        .each((Entity e, ref Position p) {
            observerTriggered++;
            printf("2. [Observer] Entity '%s' Position set to (%.1f, %.1f)\n", e.name(), p.x, p.y);
        });

    // 3. Entity
    Entity spaceship = world.entity("Starship")
        .set(Position(10.0f, 20.0f))
        .set(Velocity(2.5f, 3.5f));

    // 4. System in EcsOnUpdate phase
    world.system!(Position, Velocity)("Movement")
        .kind(EcsOnUpdate)
        .each((Entity e, ref Position p, ref Velocity v) {
            p.x += v.dx;
            p.y += v.dy;
            printf("3. [System] %s updated to (%.1f, %.1f)\n", e.name(), p.x, p.y);
        });

    // 5. Progress the world
    printf("\nProgressing world:\n");
    world.progress(0.016f);

    printf("\n=== SUCCESS: flecs-d downloaded and running from DUB registry! ===\n");
    return 0;
}
