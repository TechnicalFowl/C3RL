module c3rl_ex4;

import std::collections::list;
import std::math::random;

import c3rl;

struct Ex4 (RLGame)
{
	random::Pcg32Random rng;

    double tick_duration;
    double tick_time;
}

fn void Ex4.zone_generator(&self, Zone* zone)
{
    for (int y = 0; y < zone.height; ++y)
    {
        for (int x = 0; x < zone.width; ++x)
        {
            if (x == 10 && y == 10) continue;
            if (random::next_in_range(&self.rng, 0, 5) == 0)
            {
                zone.set_terrain(x, y, '#', colors::WHITE, colors::BLACK, false);
            }
            else
            {
                zone.set_terrain(x, y, ' ', colors::WHITE, colors::BLACK, true);
            }
        }
    }

    Entity* player = zone.ecs.add_entity("player", {10, 10});
}

fn ZoneDescription make_zone()
{
    ZoneDescription zone;
    zone.new_init("main", 80, 45);
    zone.player_spawn = {10, 10};
    zone.generator = (ZoneGenerator) &Ex4.zone_generator;
    return zone;
}

// This is the settings for the game. We're using the default font, 16x16 characters, and a 80x45 terminal.
fn RLSettings Ex4.settings(&self) @dynamic
{
	return c3rl::make_settings(
		asset_path: "../../assets",
		default_font_name: "cp437",
		default_font_size: 16,
		terminal_width: 80,
		terminal_height: 45,
		window_title: "C3RL Example 4",
        initial_zone: make_zone()
    );
}

// Tick is called every frame.
fn void Ex4.tick(&self) @dynamic
{
    self.tick_time += 1 / 60.0;
    if (self.tick_time > self.tick_duration)
    {
        self.tick_time = 0;

    }

	c3rl::terminal.clear_to({{'.', 0}, colors::DARK_GREY, 0, colors::BLACK, 0});
}

fn void main()
{
	Ex4 game;
    game.tick_duration = 0.2;
    random::seed_entropy(&game.rng);

	c3rl::launch(&game);
}
