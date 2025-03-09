module c3rl_ex5;

import std::collections::list;
import std::io;
import std::math::random;

import raylib5::rl;

import c3rl;

struct Ex7 (RLGame)
{
    random::Pcg32Random rng;
    Entity player;
    int sidebar_width;
    String[10] inventory;
    int selected_item;
}

fn Entity Ex7.get_player(&self) @dynamic => self.player;

struct Player (Entity)
{
    String name;
    Zone* zone;
    IVec2 position;
    Appearance look;

    Navigator nav;
    float nav_delay;
}

// @Todo: There should be an easy way to avoid this boilerplate?...
fn Zone* Player.get_zone(&self) @dynamic => self.zone;
fn String Player.get_name(&self) @dynamic => self.name;
fn IVec2 Player.get_position(&self) @dynamic => self.position;
fn void Player.set_position(&self, IVec2 pos) @dynamic
{
    c3rl::entity_set_position(self, pos);
    self.position = pos;
}
fn Appearance Player.get_look(&self) @dynamic => self.look;
fn double Player.get_idle_time(&self) @dynamic => 0.0;
fn void Player.give_idle_time(&self, double time) @dynamic {}
fn bool Player.is_dead(&self) @dynamic => false;

fn void Player.new_init(&self, Zone* z, String n, IVec2 p)
{
    self.zone = z;
    self.name = n;
    self.position = p;
    self.look = PLAYER;
    self.nav.new_init();
    self.nav_delay = 0.2f;
}

fn void Player.free(&self) @dynamic
{
    self.nav.free();
}

fn void Player.on_update(&self, double delta_time) @dynamic
{
}

fn void Player.on_render(&self, VirtualTerminal* terminal, IVec2 term_pos) @dynamic
{
}

fn Action Player.next_action(&self, double max_time) @dynamic
{
    if (self.nav.is_idle())
    {
        if (c3rl::is_key_pressed(MOVE_UP)) return c3rl::do_move({0, -1});
        if (c3rl::is_key_pressed(MOVE_DOWN)) return c3rl::do_move({0, 1});
        if (c3rl::is_key_pressed(MOVE_RIGHT)) return c3rl::do_move({-1, 0});
        if (c3rl::is_key_pressed(MOVE_LEFT)) return c3rl::do_move({1, 0});
    }
    else
    {
        self.nav_delay -= rl::getFrameTime();
        if (self.nav_delay <= 0)
        {
            self.nav_delay = 0.2f;
            IVec2 next_move = self.nav.next_point() - self.position;
            assert(math::abs(next_move[0]) + math::abs(next_move[1]) == 1, "Invalid move from navigator");
            return c3rl::do_move(next_move);
        }
    }
    return null;
}

fn void Ex7.zone_generator(&self, Zone* zone)
{
    for (int y = 0; y < zone.size.y; ++y)
    {
        for (int x = 0; x < zone.size.x; ++x)
        {
            if (x == 10 && y == 10) continue;
            if (x == 0 || x == zone.size.x - 1 || y == 0 || y == zone.size.y - 1 || random::next_in_range(&self.rng, 0, 5) == 0)
            {
                zone.set_terrain(x, y, WALL);
            }
            else
            {
                zone.set_terrain(x, y, FLOOR);
            }
        }
    }

    Player* pl = mem::new(Player);
    pl.new_init(zone, "Player", {40, 10});
    zone.add_entity(pl);
    self.player = pl;
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

// Render is called every frame.
fn void Ex7.render(&self) @dynamic
{
    Player* pl = (Player*) self.player;
    if (rl::isMouseButtonPressed(rl::MouseButton.LEFT) && !gui::want_mouse_input())
    {
        if (pl.nav.is_idle())
        {
            IVec2 pos = c3rl::current_zone.get_mouse_position();
            pl.nav.path_to(c3rl::current_zone, pl.get_position(), pos);
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
    
    int term_width = c3rl::ui_term.width;
    int term_height = c3rl::ui_term.height;
    int map_width = c3rl::ui_term.width - self.sidebar_width;

    gui::push_topbar("C3RL Example 7");
    gui::push_bottombar(string::tformat("Player @ %d %d", ...pl.get_position()));
    gui::push_bottombar(string::tformat("Mouse @ %d %d", ...pl.zone.get_mouse_position()));

    int log_height = 7;
    gui::begin_window("Log", {map_width, 0}, {self.sidebar_width, log_height});
    
    long start = math::max(c3rl::log_messages.len() - log_height + 2, 0l);
    for (long i = start; i < c3rl::log_messages.len(); ++i)
    {
        LogMessage msg = c3rl::log_messages[i];
        gui::text(msg.message, msg.color);
    }

    gui::end_window();

    gui::begin_window("Inventory", {map_width, log_height}, {self.sidebar_width, term_height - log_height});
    for (int i = 0; i < self.inventory.len; ++i)
    {
        if (self.inventory[i] == "") continue;
        if (gui::button(self.inventory[i]))
        {
            self.selected_item = i;
            gui::open_popup("Item Options");
        }
    }
    gui::end_window();

    if (rl::isKeyPressed(rl::KEY_I))
    {
        gui::open_popup("Store");
    }

    if (gui::begin_popup("Item Options", {map_width - 20, log_height + 5}, {20, 8}))
    {
        if (gui::button("Use", rl::KEY_U))
        {
            c3rl::log(string::tformat("You use the %s.", self.inventory[self.selected_item]));
            gui::close_current_popup();
        }
        if (gui::button("Drop", rl::KEY_D))
        {
            c3rl::log(string::tformat("You drop the %s.", self.inventory[self.selected_item]));
            self.inventory[self.selected_item] = "";
            gui::close_current_popup();
        }
        if (gui::button("Close") || rl::isKeyPressed(rl::KEY_ESCAPE))
        {
            gui::close_current_popup();
        }
        gui::end_popup();
    }

    if (gui::begin_popup("Store", {5, 5}, {map_width - 10, term_height - 10}))
    {
        gui::text("Welcome to the store!");
        gui::text("We have nothing for sale.");
        gui::text("");
        if (gui::button("Close") || rl::isKeyPressed(rl::KEY_ESCAPE))
        {
            gui::close_current_popup();
        }
        gui::end_popup();
    }
}

fn void main()
{
    Ex7 game;
    game.sidebar_width = 60;
    game.inventory = { "Sword", "Shield", "Potion", "", "", "", "", "", "", "" };
    random::seed_entropy(&game.rng);

    c3rl::log("You descend into the dungeon...", colors::GREEN);

    c3rl::launch(&game);
}

module c3rl::game;
import c3rl;
import raylib5::rl;

// Appearance defines the look of something on the screen
enum Appearance : (AppearanceInfo info)
{
    EMPTY = { ' ', colors::BLACK, -1 },
    PLAYER = { '@', colors::WHITE, -1 },
    WALL = { '#', colors::LIGHT_GREY, -1 },
    FLOOR = { '.', colors::DARK_GREY, -1 },
}

// Terrain defines static parts of the map that don't have logic
enum Terrain : (TerrainInfo info)
{
    EMPTY = { "", 0, Appearance.EMPTY, "" },
    WALL = { "", 0, Appearance.WALL, "" },
    FLOOR = { "", 0, Appearance.FLOOR, "" },
}

// Object defines static parts of the map that may have additional interaction logic
enum Object : (ObjectInfo info)
{
    EMPTY = { "", 0, Appearance.EMPTY, "", null },
}

// Inputs are abstract actions and are assicated to default input keys
enum Input : inline int (rl::KeyboardKey primary, rl::KeyboardKey secondary)
{
    MOVE_UP = { rl::KEY_UP, rl::KEY_KP_8 },
    MOVE_DOWN = { rl::KEY_DOWN, rl::KEY_KP_2 },
    MOVE_LEFT = { rl::KEY_LEFT, rl::KEY_KP_4 },
    MOVE_RIGHT = { rl::KEY_RIGHT, rl::KEY_KP_6 },
}