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

// Render is called every frame.
fn void Ex1.render(&self) @dynamic
{
    c3rl::ui_term.clear(colors::BLACK);
    c3rl::ui_term.write(1, 1, "Hello World", colors::WHITE);
}

fn Entity Ex1.get_player(&self) @dynamic => null;

fn void main()
{
    Ex1 game;
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