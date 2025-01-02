module c3rl_ex5;

import std::collections::list;
import std::io;
import std::math::random;

import raylib5::rl;

import c3rl;

struct Ex7 (RLGame)
{
    random::Pcg32Random rng;
    
    int sidebar_width;
}

struct Player (Entity)
{
    inline EntityCommon entity;

    Navigator nav;
    float nav_delay;
}

// @Todo: There should be an easy way to avoid this boilerplate?...
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
    self.nav.new_init();
    self.nav_delay = 0.2f;
}

fn void Player.free(&self) @dynamic
{
    self.entity.free();
    self.nav.free();
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

fn void Ex7.zone_generator(&self, Zone* zone)
{
    for (int y = 0; y < zone.height; ++y)
    {
        for (int x = 0; x < zone.width; ++x)
        {
            if (x == 10 && y == 10) continue;
            if (x == 0 || x == zone.width - 1 || y == 0 || y == zone.height - 1 || random::next_in_range(&self.rng, 0, 5) == 0)
            {
                zone.set_terrain(x, y, '#', colors::random_color(&self.rng), colors::BLACK, false);
            }
            else
            {
                zone.set_terrain(x, y, ' ', colors::WHITE, colors::BLACK, true);
            }
        }
    }

    Player* pl = mem::new(Player);
    pl.new_init(zone, "Player", {40, 10});
    zone.add_player(pl);
}

fn ZoneDescription Ex7.make_zone(&self)
{
    ZoneDescription zone;
    zone.new_init("main", 80, 45);
    zone.generator = (ZoneGenerator) &Ex7.zone_generator;
    zone.generator_data = self;
    return zone;
}

// This is the settings for the game. We're using the default font, 16x16 characters, and a 80x45 terminal.
fn RLSettings Ex7.settings(&self) @dynamic
{
    return c3rl::make_settings(
        asset_path: "../../assets",
        default_font_name: "cp437",
        default_font_size: 16,
        terminal_width: 80,
        terminal_height: 45,
        window_title: "C3RL Example 7",
        initial_zone: self.make_zone()
    );
}

fn ZoneRenderSettings Ex7.pre_render(&self) @dynamic
{
    return { { self.sidebar_width / 2, 0} };
}

// Render is called every frame.
fn void Ex7.render(&self) @dynamic
{
    Player* pl = (Player*) c3rl::zone.player;
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

    if (!pl.nav.is_idle())
    {
        switch (random::next_in_range(&self.rng, 0, 120))
        {
            case 0: c3rl::log("Ouch! You stubbed your toe.", colors::RED);
            case 1: c3rl::log("You hear a faint whisper.");
            case 2: c3rl::log("You feel a chill down your spine.");
            case 3: c3rl::log("You feel a sense of dread.");
            default: break;
        }
    }
    
    int term_width = c3rl::terminal.width;
    int term_height = c3rl::terminal.height;
    int map_width = c3rl::terminal.width - self.sidebar_width;

    gui::push_topbar("C3RL Example 7");
    gui::push_bottombar(string::tformat("Player @ %d %d", ...pl.get_position()));
    gui::push_bottombar(string::tformat("Mouse @ %d %d", ...pl.zone.get_mouse_position()));

    int log_height = term_height / 3;
    gui::begin_window("Log", {map_width, 0}, {self.sidebar_width, log_height});
    
    long start = math::max(c3rl::log_messages.len() - log_height + 2, 0l);
    for (long i = start; i < c3rl::log_messages.len(); ++i)
    {
        LogMessage msg = c3rl::log_messages[i];
        gui::text(msg.message, msg.color);
    }

    gui::end_window();
}

fn void main()
{
    Ex7 game;
    game.sidebar_width = 30;
    random::seed_entropy(&game.rng);

    c3rl::log("You descend into the dungeon...", colors::GREEN);

    c3rl::launch(&game);
}
