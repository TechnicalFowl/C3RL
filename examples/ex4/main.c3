module c3rl_ex4;

import std::collections::list;
import std::math::random;

import raylib5::rl;

import c3rl;

struct Ex4 (RLGame)
{
    random::Pcg32Random rng;
}

struct Player (Entity)
{
    inline EntityCommon entity;
}

// @Todo: There should be an easy way to avoid this boilerplate?...
fn void Player.free(&self) @dynamic => self.entity.free();
fn Zone* Player.get_zone(&self) @dynamic => self.entity.get_zone();
fn String Player.get_name(&self) @dynamic => self.entity.get_name();
fn IVec2 Player.get_position(&self) @dynamic => self.entity.get_position();
fn void Player.set_position(&self, IVec2 pos) @dynamic => self.entity.set_position(pos);
fn char Player.get_glyph(&self) @dynamic => self.entity.get_glyph();
fn rl::Color Player.get_color(&self) @dynamic => self.entity.get_color();
fn double Player.get_idle_time(&self) @dynamic => self.entity.get_idle_time();
fn void Player.give_idle_time(&self, double time) @dynamic => self.entity.give_idle_time(time);

fn void Player.new_init(&self, Zone* z, String n, IVec2 p)
{
    self.entity.new_init(z, n, p, '@', colors::WHITE);
}

fn Action Player.next_action(&self, double max_time) @dynamic
{
    if (rl::isKeyPressed(rl::KEY_W))
    {
        return c3rl::do_move({0, -1});
    }
    if (rl::isKeyPressed(rl::KEY_S))
    {
        return c3rl::do_move({0, 1});
    }
    if (rl::isKeyPressed(rl::KEY_A))
    {
        return c3rl::do_move({-1, 0});
    }
    if (rl::isKeyPressed(rl::KEY_D))
    {
        return c3rl::do_move({1, 0});
    }
    return null;
}

fn void Ex4.zone_generator(&self, Zone* zone)
{
    for (int y = 0; y < zone.height; ++y)
    {
        for (int x = 0; x < zone.width; ++x)
        {
            if (x == 10 && y == 10) continue;
            if (x == 0 || x == zone.width - 1 || y == 0 || y == zone.height - 1 || random::next_in_range(&self.rng, 0, 5) == 0)
            {
                zone.set_terrain(x, y, '#', colors::WHITE, colors::BLACK, false);
            }
            else
            {
                zone.set_terrain(x, y, ' ', colors::WHITE, colors::BLACK, true);
            }
        }
    }

    Player* pl = mem::new(Player);
    pl.new_init(zone, "Player", {10, 10});
    zone.add_player(pl);
}

fn ZoneDescription Ex4.make_zone(&self)
{
    ZoneDescription zone;
    zone.new_init("main", 80, 45);
    zone.player_spawn = {10, 10};
    zone.generator = (ZoneGenerator) &Ex4.zone_generator;
    zone.generator_data = self;
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
        initial_zone: self.make_zone()
    );
}

// Tick is called every frame.
fn void Ex4.tick(&self) @dynamic
{
}

fn void main()
{
    Ex4 game;
    random::seed_entropy(&game.rng);

    c3rl::launch(&game);
}
