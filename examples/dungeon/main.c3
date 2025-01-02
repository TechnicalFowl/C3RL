module c3rl_ex5;

import std::collections::list;
import std::io;
import std::math::random;

import raylib5::rl;

import c3rl;

struct DungeonGame (RLGame)
{
    random::Pcg32Random rng;
    
    int sidebar_width;
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

fn void DungeonGame.zone_generator(&self, Zone* zone)
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
                zone.set_terrain(x, y, '.', colors::DARKEST_GREY, colors::BLACK, true);
            }
        }
    }

    Player* pl = mem::new(Player);
    pl.new_init(zone, "Player", {40, 10});
    zone.add_player(pl);
}

fn ZoneDescription DungeonGame.make_zone(&self)
{
    ZoneDescription zone;
    zone.new_init("main", 100, 100);
    zone.generator = (ZoneGenerator) &DungeonGame.zone_generator;
    zone.generator_data = self;
    return zone;
}

// This is the settings for the game. We're using the default font, 16x16 characters, and a 80x45 terminal.
fn RLSettings DungeonGame.settings(&self) @dynamic
{
    return c3rl::make_settings(
        asset_path: "../../assets",
        default_font_name: "cp437",
        default_font_size: 16,
        terminal_width: 80,
        terminal_height: 45,
        window_title: "C3RL - DungeonGame",
        initial_zone: self.make_zone()
    );
}

fn ZoneRenderSettings DungeonGame.pre_render(&self) @dynamic
{
    return { { self.sidebar_width / 2, 0} };
}

// Render is called every frame.
fn void DungeonGame.render(&self) @dynamic
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
        switch (random::next_in_range(&self.rng, 0, 1000))
        {
            case 0:
                c3rl::log("Ouch! You stubbed your toe.", colors::RED);
                pl.nav.abort();
            case 1: c3rl::log("You hear a faint whisper.");
            case 2: c3rl::log("You feel a chill down your spine.");
            case 3: c3rl::log("You feel a sense of dread.");
            default: break;
        }
    }
    
    int term_width = c3rl::terminal.width;
    int term_height = c3rl::terminal.height;
    int map_width = c3rl::terminal.width - self.sidebar_width;
    
    int log_height = term_height / 3;
    gui::begin_window("Log", {map_width, 0}, {self.sidebar_width, log_height});
    
    long start = math::max(c3rl::log_messages.len() - log_height + 2, 0l);
    for (long i = start; i < c3rl::log_messages.len(); ++i)
    {
        LogMessage msg = c3rl::log_messages[i];
        gui::text(msg.message, msg.color);
    }

    gui::end_window();

    gui::begin_window("Inventory", {map_width, log_height}, {self.sidebar_width, term_height - log_height});
    gui::text("You have nothing of value.", colors::WHITE);
    gui::end_window();
}

fn void main()
{
    DungeonGame game;
    game.sidebar_width = 30;
    random::seed_entropy(&game.rng);

    c3rl::log("You descend into the dungeon...", colors::RED);

    c3rl::launch(&game);
}
