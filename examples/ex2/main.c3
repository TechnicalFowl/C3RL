module c3rl_ex1;

import std::math::random;

import c3rl;

struct Ex2 (RLGame)
{
	random::Pcg32Random rng;

    int player_x;
    int player_y;

    double tick_duration;
    double tick_time;
}

// This is the settings for the game. We're using the default font, 16x16 characters, and a 80x45 terminal.
fn RLSettings Ex2.settings(&self) @dynamic
{
	return {
		"../../assets", // asset_path
		"cp437", // default_font_name
		16, // default_font_size
		80, // terminal_width
		45, // terminal_height
		"C3RL Example 2", // window_title
	};
}

// Tick is called every frame.
fn void Ex2.tick(&self) @dynamic
{
    self.tick_time += 1 / 60.0;
    if (self.tick_time > self.tick_duration)
    {
        self.tick_time = 0;

        int direction = self.rng.next_int() % 4 + 1;
        switch (direction)
        {
            case 1: self.player_x += 1; break;
            case 2: self.player_x -= 1; break;
            case 3: self.player_y += 1; break;
            case 4: self.player_y -= 1; break;
        }

        self.player_x = math::clamp(self.player_x, 0, 80);
        self.player_y = math::clamp(self.player_y, 0, 45);
    }

	c3rl::terminal.clear_to({{'.', 0}, colors::WHITE, 0, colors::BLACK, 0});
    c3rl::terminal.set_tile(self.player_x, self.player_y, '@', colors::YELLOW);
}

fn void main()
{
	Ex2 game;
    game.tick_duration = 0.5;
    game.player_x = 10;
    game.player_y = 10;

	c3rl::launch(&game);
}
