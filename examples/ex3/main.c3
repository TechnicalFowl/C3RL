module c3rl_ex3;

import std::collections::list;
import std::math::random;

import c3rl;

struct Ex3 (RLGame)
{
    random::Pcg32Random rng;

    int player_x;
    int player_y;

    int destination_x;
    int destination_y;

    List(<int[<2>]>) path;

    double tick_duration;
    double tick_time;
}

// This is the settings for the game. We're using the default font, 16x16 characters, and a 80x45 terminal.
fn RLSettings Ex3.settings(&self) @dynamic
{
    return c3rl::make_settings(
        asset_path: "../../assets",
        default_font_name: "cp437",
        default_font_size: 16,
        terminal_width: 80,
        terminal_height: 45,
        window_title: "C3RL Example 3",
    );
}

fn void Ex3.add_to_path(&self, int[<2>] point)
{
    self.path.push(point);
}

// Tick is called every frame.
fn void Ex3.tick(&self) @dynamic
{
    self.tick_time += 1 / 60.0;
    if (self.tick_time > self.tick_duration)
    {
        self.tick_time = 0;

        if (self.player_x == self.destination_x && self.player_y == self.destination_y || self.path.is_empty())
        {
            self.destination_x = random::next_in_range(&self.rng, 0, c3rl::terminal.width - 1);
            self.destination_y = random::next_in_range(&self.rng, 0, c3rl::terminal.height - 1);

            self.path.clear();
            c3rl::line({self.player_x, self.player_y}, {self.destination_x, self.destination_y}, (LineCallback) &Ex3.add_to_path, self);
        }
        else
        {
            int[<2>] next = self.path.pop_first()!!;
            self.player_x = next[0];
            self.player_y = next[1];
        }

        self.player_x = math::clamp(self.player_x, 0, 80);
        self.player_y = math::clamp(self.player_y, 0, 45);
    }

    c3rl::terminal.clear_to({{'.', 0}, colors::DARK_GREY, 0, colors::BLACK, 0});
    foreach(point: self.path)
    {
        c3rl::terminal.set_background(point[0], point[1], colors::DARK_RED);
    }
    c3rl::terminal.set_tile(self.player_x, self.player_y, '@', colors::YELLOW);
}

fn void main()
{
    Ex3 game;
    game.tick_duration = 0.2;
    game.player_x = 10;
    game.player_y = 10;
    random::seed_entropy(&game.rng);
    game.path.new_init();

    c3rl::launch(&game);
}
