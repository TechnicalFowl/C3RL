module c3rl_ex5;

import std::collections::list;
import std::math::random;

import raylib5::rl;

import c3rl;

struct Ex5 (RLGame)
{
    random::Pcg32Random rng;
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
fn int[<2>] Player.get_position(&self) @dynamic => self.entity.get_position();
fn void Player.set_position(&self, int[<2>] pos) @dynamic => self.entity.set_position(pos);
fn char Player.get_glyph(&self) @dynamic => self.entity.get_glyph();
fn rl::Color Player.get_color(&self) @dynamic => self.entity.get_color();
fn double Player.get_idle_time(&self) @dynamic => self.entity.get_idle_time();
fn void Player.give_idle_time(&self, double time) @dynamic => self.entity.give_idle_time(time);

fn void Player.new_init(&self, Zone* z, String n, int[<2>] p)
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
            int[<2>] next_move = self.nav.next_point() - self.entity.position;
            assert(math::abs(next_move[0]) + math::abs(next_move[1]) == 1, "Invalid move from navigator");
            return c3rl::do_move(next_move);
        }
    }
    return null;
}

fn void Ex5.zone_generator(&self, Zone* zone)
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

fn ZoneDescription Ex5.make_zone(&self)
{
    ZoneDescription zone;
    zone.new_init("main", 80, 45);
    zone.player_spawn = {10, 10};
    zone.generator = (ZoneGenerator) &Ex5.zone_generator;
    zone.generator_data = self;
    return zone;
}

// This is the settings for the game. We're using the default font, 16x16 characters, and a 80x45 terminal.
fn RLSettings Ex5.settings(&self) @dynamic
{
    return c3rl::make_settings(
        asset_path: "../../assets",
        default_font_name: "cp437",
        default_font_size: 16,
        terminal_width: 80,
        terminal_height: 45,
        window_title: "C3RL Example 5",
        initial_zone: self.make_zone()
    );
}

// Tick is called every frame.
fn void Ex5.tick(&self) @dynamic
{
    Player* pl = (Player*) c3rl::zone.player;
    int[<2>] player_pos = pl.get_position();
    int[<2>] zone_min = player_pos - {c3rl::terminal.width / 2, c3rl::terminal.height / 2};
    if (!pl.nav.is_idle())
    {
        foreach(point: pl.nav.path)
        {
            int[<2>] term_pos = point - zone_min;
            if (term_pos[0] >= 0 && term_pos[0] < c3rl::terminal.width && term_pos[1] >= 0 && term_pos[1] < c3rl::terminal.height)
            {
                c3rl::terminal.set_background(...term_pos, colors::DARK_GREEN, 5);
            }
        }
        
        if (rl::isMouseButtonPressed(rl::MouseButton.LEFT))
        {
            pl.nav.abort();
        }
    }
    else
    {
        int[<2>] mouse = { rl::getMouseX() / 16, rl::getMouseY() / 16 };
        int[<2>] mouse_in_zone = c3rl::zone.get_mouse_position();
        if (mouse[0] >= 0 && mouse[0] < c3rl::terminal.width && mouse[1] >= 0 && mouse[1] < c3rl::terminal.height)
        {
            if (mouse_in_zone[0] < 0 || mouse_in_zone[0] >= c3rl::zone.width || mouse_in_zone[1] < 0 || mouse_in_zone[1] >= c3rl::zone.height)
            {
                c3rl::terminal.set_tile(...mouse, 'x', colors::RED, 10);
            }
            else
            {
                ZoneCell* cell = c3rl::zone.get_cell(...mouse_in_zone);
                if (cell.terrain.passable)
                {
                    if (pl.nav.is_idle())
                    {
                        List(<int[<2>]>) path;
                        path.temp_init();
                        if (c3rl::zone.path(player_pos, mouse_in_zone, &path, false))
                        {
                            foreach(point: path)
                            {
                                int[<2>] term_pos = point - zone_min;
                                if (term_pos[0] >= 0 && term_pos[0] < c3rl::terminal.width && term_pos[1] >= 0 && term_pos[1] < c3rl::terminal.height)
                                {
                                    c3rl::terminal.set_background(...term_pos, colors::DARK_RED, 5);
                                }
                            }
                            c3rl::terminal.set_tile(...mouse, 'x', colors::GREEN, 10);
                        }
                        else
                        {
                            c3rl::terminal.set_tile(...mouse, 'x', colors::RED, 10);
                        }

                        if (rl::isMouseButtonPressed(rl::MouseButton.LEFT))
                        {
                            pl.nav.path_to(c3rl::zone, player_pos, mouse_in_zone);
                        }
                    }
                }
                else
                {
                    c3rl::terminal.set_tile(...mouse, 'x', colors::RED, 10);
                }
            }
        }
    }
}

fn void main()
{
    Ex5 game;
    random::seed_entropy(&game.rng);

    c3rl::launch(&game);
}
