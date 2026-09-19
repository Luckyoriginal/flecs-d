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

struct GameConfig {
	int maxPlayers;
	bool debugMode;
}

extern(C) int main() {
	printf("=== Flecs DUB Package Example (Better-C) ===\n\n");

	// 1. Create ECS World
	World world = World.create();
	scope(exit) world.destroy();
	
	auto parent = world.entity();

	// 2. Set Singleton
	world.set(GameConfig(32, true));
	printf("GameConfig: maxPlayers = %d, debug = %d\n",
			world.get!GameConfig().maxPlayers,
			world.get!GameConfig().debugMode);

	// 3. Create Entities
	Entity hero = world.entity("Hero")
		.set(Position(0.0f, 0.0f))
		.set(Velocity(1.5f, 2.5f))
		.child_of(parent);

	Entity enemy = world.entity("Enemy")
		.set(Position(50.0f, 50.0f))
		.set(Velocity(-1.0f, 0.5f))
		.child_of(parent);

	// 4. Create Phased System
	world.system!(Position, Velocity)("MovementSystem")
		.kind(EcsOnUpdate)
		.each((Entity e, ref Position p, ref Velocity v) {
				p.x += v.dx;
				p.y += v.dy;
				printf("  [System] %s moved to (%.1f, %.1f)\n", e.name(), p.x, p.y);
				});

	// 5. Progress Frame
	printf("\nProgressing world:\n");
	for (int i=0;i<40;i++){
		world.progress(0.016f);
	}

	printf("\n=== DUB Example Successfully Finished! ===\n");
	return 0;
}
