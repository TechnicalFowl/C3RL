module c3rl_ex1;

import c3rl;

struct Ex1 (RLGame)
{
	int foo; // structs can't be empty
}

// This is the settings for the game. We're using the default font, 16x16 characters, and a 80x45 terminal.
fn RLSettings Ex1.settings(&self) @dynamic
{
	return c3rl::make_settings(
		asset_path: "../../assets",
		default_font_name: "cp437",
		default_font_size: 16,
		terminal_width: 80,
		terminal_height: 45,
		window_title: "C3RL Example 1",
    );
}

// Tick is called every frame.
fn void Ex1.tick(&self) @dynamic
{
	c3rl::terminal.clear(colors::BLACK);
	c3rl::terminal.write(1, 1, "Hello World", colors::WHITE);
}

fn void main()
{
	Ex1 game;
	c3rl::launch(&game);
}
