module c3rl_ex2;

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
    return c3rl::make_settings(
        asset_path: "../../assets",
        default_font_name: "cp437",
        default_font_size: 16,
        terminal_width: 80,
        terminal_height: 45,
        window_title: "C3RL Example 2",
    );
}

// Render is called every frame.
fn void Ex2.render(&self) @dynamic
{
    self.tick_time += 1 / 60.0;
    if (self.tick_time > self.tick_duration)
    {
        self.tick_time = 0;

        int direction = random::next_in_range(&self.rng, 1, 4);
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

    c3rl::terminal.clear_to({{'.', 0}, colors::DARK_GREY, 0, colors::BLACK, 0});
    c3rl::terminal.set_tile(self.player_x, self.player_y, '@', colors::YELLOW);
}

fn void main()
{
    Ex2 game;
    game.tick_duration = 0.5;
    game.player_x = 10;
    game.player_y = 10;
    random::seed_entropy(&game.rng);

    c3rl::launch(&game);
}
