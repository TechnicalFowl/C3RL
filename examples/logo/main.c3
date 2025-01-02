module c3rl_ex5;

import std::collections::list;
import std::io;
import std::math::random;

import raylib5::rl;

import c3rl;

struct ExLogo (RLGame)
{
    random::Pcg32Random rng;
}

struct Player (Entity)
{
    inline EntityCommon entity;

    Navigator nav;
    float nav_delay;

    VisibilityTracker vis;
}

// @Todo: There should be an easy way to avoid this boilerplate?...
fn Zone* Player.get_zone(&self) @dynamic => self.entity.get_zone();
fn String Player.get_name(&self) @dynamic => self.entity.get_name();
fn IVec2 Player.get_position(&self) @dynamic => self.entity.get_position();
fn void Player.set_position(&self, IVec2 pos) @dynamic
{
    self.entity.set_position(pos);
    self.vis.sweep(pos, 10);
}
fn char Player.get_glyph(&self) @dynamic => self.entity.get_glyph();
fn rl::Color Player.get_color(&self) @dynamic => self.entity.get_color();
fn double Player.get_idle_time(&self) @dynamic => self.entity.get_idle_time();
fn void Player.give_idle_time(&self, double time) @dynamic => self.entity.give_idle_time(time);

// Implement EntityVisibility
fn VisibilityTracker* Player.get_visibility(&self) @dynamic => &self.vis;
fn void Player.on_post_load(&self) @dynamic => self.vis.sweep(self.get_position(), 10);

fn void Player.new_init(&self, Zone* z, String n, IVec2 p)
{
    self.entity.new_init(z, n, p, '@', colors::WHITE);
    self.nav.new_init();
    self.nav_delay = 0.2f;

    self.vis.new_init(z);
}

fn void Player.free(&self) @dynamic
{
    self.entity.free();
    self.nav.free();
    self.vis.free();
}

fn Action Player.next_action(&self, double max_time) @dynamic
{
    if (self.nav.is_idle())
    {
        if (rl::isKeyPressed(rl::KEY_W)) return c3rl::do_move({0, -1});
        if (rl::isKeyPressed(rl::KEY_S)) return c3rl::do_move({0, 1});
        if (rl::isKeyPressed(rl::KEY_A)) return c3rl::do_move({-1, 0});
        if (rl::isKeyPressed(rl::KEY_D)) return c3rl::do_move({1, 0});
    }
    else
    {
        self.nav_delay -= rl::getFrameTime();
        if (self.nav_delay <= 0)
        {
            self.nav_delay = 0.2f;
            IVec2 next_move = self.nav.next_point() - self.entity.position;
            assert(math::abs(next_move[0]) + math::abs(next_move[1]) == 1, "Invalid move from navigator");
            return c3rl::do_move(next_move);
        }
    }
    return null;
}

fn void ExLogo.zone_generator(&self, Zone* zone)
{
    CellularAutomata gen;
    gen.new_init(5, 0.45, 5, 2);

    gen.generate(zone, &self.rng);

    ulong[*] letters = {
        0b0000000000000000000000000000000000000000000000000000000000000000,
        0b0000000111100000111100001111110000111100000000000000000000000000,
        0b0000001100110001100110000110011000011000000000000000000000000000,
        0b0000011000000000000110000110011000011000000000000000000000000000,
        0b0000011000000000011100000111110000011000000000000000000000000000,
        0b0000011000000000000110000111100000011000100000000000000000000000,
        0b0000001100110001100110000110110000011001100000000000000000000000,
        0b0000000111100000111100001110011000111111100000000000000000000000,
        0b0000000000000000000000000000000000000000000000000000000000000000,
    };
    BitBoard temp = {
        64, 9,
        &letters
    };

    ulong[*] mask = {
        0b1111110000000000000000000000000000000000000111111111111111111111,
        0b1111000000000000000000000000000000000000000000111111111111111111,
        0b1100000000000000000000000000000000000000000000001111111111111111,
        0b1100000000000000000000000000000000000000000000001111111111111111,
        0b1100000000000000000000000000000000000000000000001111111111111111,
        0b1100000000000000000000000000000000000000000000001111111111111111,
        0b1100000000000000000000000000000000000000000000001111111111111111,
        0b1111000000000000000000000000000000000000000000111111111111111111,
        0b1111111000000000000000000000000000000000000111111111111111111111,
    };
    BitBoard temp2 = {
        64, 9,
        &mask
    };

    for (int x = 18; x < 18 + 64; ++x)
    {
        for (int y = 41; y < 50; ++y)
        {
            if (!temp2.get({63 - (x - 18), y - 41}))
            {
                if (temp.get({63 - (x - 18), y - 41}))
                {
                    zone.set_terrain(x, y, '#', x < 40 ? colors::CORNFLOWER_BLUE : colors::INDIAN_RED, colors::BLACK, false);
                }
                else
                {
                    zone.set_terrain(x, y, '.', colors::DARKEST_GREY.randomize(&self.rng, 0.2), colors::BLACK, true);
                }
            }
        }
    }

    Player* pl = mem::new(Player);
    pl.new_init(zone, "Player", zone.find_nearest_empty({25, 50}));

    for (int x = 18; x < 18 + 64; ++x)
    {
        for (int y = 41; y < 50; ++y)
        {
            if (!temp2.get({63 - (x - 18), y - 41}))
            {
                pl.vis.set_explored({x, y}, true);
            }
        }
    }

    zone.add_player(pl);
}

fn ZoneDescription ExLogo.make_zone(&self)
{
    ZoneDescription zone;
    zone.new_init("main", 100, 100);
    zone.generator = (ZoneGenerator) &ExLogo.zone_generator;
    zone.generator_data = self;
    return zone;
}

// This is the settings for the game. We're using the default font, 16x16 characters, and a 80x45 terminal.
fn RLSettings ExLogo.settings(&self) @dynamic
{
    return c3rl::make_settings(
        asset_path: "../../assets",
        default_font_name: "cp437",
        default_font_size: 16,
        terminal_width: 80,
        terminal_height: 45,
        window_title: "C3RL",
        initial_zone: self.make_zone()
    );
}

// Render is called every frame.
fn void ExLogo.render(&self) @dynamic
{
    Player* pl = (Player*) c3rl::zone.player;
    
    for (int x = 18; x < 18 + 50; ++x)
    {
        for (int y = 41; y < 50; ++y)
        {
            pl.vis.set_visible({x, y}, true);
        }
    }
    
    if (rl::isMouseButtonPressed(rl::MouseButton.LEFT) && !gui::want_mouse_input())
    {
        if (pl.nav.is_idle())
        {
            IVec2 pos = math::clamp(c3rl::zone.get_mouse_position(), int[<*>] {0, 0}, int[<*>] {c3rl::zone.width - 1, c3rl::zone.height - 1});
            pl.nav.path_to(c3rl::zone, pl.get_position(), pos);
        }
        else
        {
            pl.nav.abort();
        }
    }
}

fn void main()
{
    ExLogo game;
    random::seed_entropy(&game.rng);

    c3rl::launch(&game);
}
