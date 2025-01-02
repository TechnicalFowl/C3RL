module c3rl_ex5;

import std::collections::list;
import std::io;
import std::math::random;

import raylib5::rl;

import c3rl;

struct Ex6 (RLGame)
{
    random::Pcg32Random rng;

    bool show_visibility;
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

fn void Ex6.zone_generator(&self, Zone* zone)
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
                zone.set_terrain(x, y, '.', colors::WHITE, colors::BLACK, true);
            }
        }
    }

    Player* pl = mem::new(Player);
    pl.new_init(zone, "Player", {40, 10});
    zone.add_player(pl);
}

fn ZoneDescription Ex6.make_zone(&self)
{
    ZoneDescription zone;
    zone.new_init("main", 80, 45);
    zone.generator = (ZoneGenerator) &Ex6.zone_generator;
    zone.generator_data = self;
    return zone;
}

// This is the settings for the game. We're using the default font, 16x16 characters, and a 80x45 terminal.
fn RLSettings Ex6.settings(&self) @dynamic
{
    return c3rl::make_settings(
        asset_path: "../../assets",
        default_font_name: "cp437",
        default_font_size: 16,
        terminal_width: 80,
        terminal_height: 45,
        window_title: "C3RL Example 6",
        initial_zone: self.make_zone()
    );
}

// Render is called every frame.
fn void Ex6.render(&self) @dynamic
{
    Player* pl = (Player*) c3rl::zone.player;
    if (rl::isMouseButtonPressed(rl::MouseButton.LEFT))
    {
        if (pl.nav.is_idle())
        {
            pl.nav.path_to(c3rl::zone, pl.get_position(), c3rl::zone.get_mouse_position());
        }
        else
        {
            pl.nav.abort();
        }
    }
    if (rl::isKeyPressed(rl::KEY_SPACE))
    {
        pl.vis.clear();
        pl.vis.sweep(pl.get_position(), 10);
    }
    if (rl::isKeyPressed(rl::KEY_F1))
    {
        self.show_visibility = !self.show_visibility;
    }

    // Visibility debugging
    if (self.show_visibility)
    {
        IVec2 player_pos = pl.get_position();
        IVec2 zone_min = player_pos - {c3rl::terminal.width / 2, c3rl::terminal.height / 2};

        for (int y = 0; y < c3rl::terminal.height; ++y)
        {
            for (int x = 0; x < c3rl::terminal.width; ++x)
            {
                IVec2 term_pos = {x, y} + zone_min;
                if (term_pos[0] < 0 || term_pos[0] >= c3rl::zone.width || term_pos[1] < 0 || term_pos[1] >= c3rl::zone.height) continue;
                if (pl.vis.is_visible(term_pos))
                {
                    c3rl::terminal.set_background(x, y, colors::DARK_GREEN, 5);
                } else if (pl.vis.is_explored(term_pos))
                {
                    c3rl::terminal.set_background(x, y, colors::DARK_RED, 5);
                }
            }
        }
    }
}

fn void main()
{
    Ex6 game;
    random::seed_entropy(&game.rng);

    c3rl::launch(&game);
}
