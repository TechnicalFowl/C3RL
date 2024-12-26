module roguelike;

import std::collections::list;
import std::io;
import std::math;
import raylib5::rl;

struct RLSettings
{
    int width;
    int height;
    String name;

    String font;
    String hfont;
    int font_size;

    GameState initial_state;
}

interface GameState
{
    fn void free();

    fn Map* getMap();
    fn void update(Map* map);
}

struct TextBufferTile
{
    char tile;
    char[2] text;
    rl::Color fg;
    rl::Color bg;
}

struct TextBuffer
{
    int width;
    int height;
    TextBufferTile* tiles;
}

interface Action
{
    fn int getTimeCost();
}

struct WaitAction (Action)
{
    int time;
}
fn int WaitAction.getTimeCost(&self) @dynamic => self.time;
fn Action makeWaitAction(int time)
{
    WaitAction* a = mem::new(WaitAction);
    a.time = time;
    return a;
}

struct MoveAction (Action)
{
    int time;
    int[<2>] dir;
}
fn int MoveAction.getTimeCost(&self) @dynamic => self.time;
fn Action makeMoveAction(int time, int[<2>] dir)
{
    MoveAction* a = mem::new(MoveAction);
    a.time = time;
    a.dir = dir;
    return a;
}

struct Appearance
{
    char icon;
    rl::Color color;
}

interface Actor
{
    fn int[<2>] position();
    fn Appearance getAppearance();
    fn Action update(Map* map, int max_time);
    fn void apply(Map* map, Action action);
}

struct Player (Actor)
{
    int[<2>] pos;
}

fn void Player.new_init(&self, int[<2>] p)
{
    self.pos = p;
}

fn int[<2>] Player.position(&self) @dynamic => self.pos;

fn bool Player.hasInput(&self)
{
    const rl::KeyboardKey[*] INPUT_KEYS = { rl::KEY_UP, rl::KEY_DOWN, rl::KEY_LEFT, rl::KEY_RIGHT };
    foreach (key: INPUT_KEYS)
    {
        if (rl::isKeyPressed(key))
        {
            return true;
        }
    }
    return false;
}

fn Appearance Player.getAppearance(&self) @dynamic => { '@', rl::WHITE };

fn Action Player.update(&self, Map* map, int max_time) @dynamic
{
    if (rl::isKeyPressed(rl::KEY_UP) && max_time >= 100)
    {
        return makeMoveAction(100, { 0, -1 });
    }
    else if (rl::isKeyPressed(rl::KEY_DOWN))
    {
        return makeMoveAction(100, { 0, 1 });
    }
    else if (rl::isKeyPressed(rl::KEY_LEFT))
    {
        return makeMoveAction(100, { -1, 0 });
    }
    else if (rl::isKeyPressed(rl::KEY_RIGHT))
    {
        return makeMoveAction(100, { 1, 0 });
    }
    return makeWaitAction(0);
}

fn void Player.apply(&self, Map* map, Action action) @dynamic
{
    switch (action.type)
    {
        case WaitAction.typeid:
        {
            break;
        }
        case MoveAction.typeid:
        {
            MoveAction* move = (MoveAction*) action;
            int[<2>] new_pos = { self.pos[0] + move.dir[0], self.pos[1] + move.dir[1] };
            if (new_pos[0] >= 0 && new_pos[0] < map.width && new_pos[1] >= 0 && new_pos[1] < map.height)
            {
                self.pos = new_pos;
            }
            break;
        }
    }
}

interface Object
{
    fn Appearance getAppearance();
    fn void update(Map* map);
}

struct Tile
{
    char bg_tile;
    rl::Color bg_color;
    bool passable;
    List(<Object>) objects;
}

struct Map
{
    int width;
    int height;
    Tile* tiles;
    
    Player* player;
    List(<Actor>) actors;

    ulong elapsed_time;
}

fn void Map.new_init(&self, int w, int h)
{
    self.width = w;
    self.height = h;
    self.tiles = mem::new_array(Tile, (usz) w * h);
    for (usz i = 0; i < (usz) w * h; i++)
    {
        self.tiles[i].bg_tile = 0;
        self.tiles[i].bg_color = rl::BLACK;
        self.tiles[i].passable = true;
    }
}

fn void Map.free(&self)
{
    for (usz i = 0; i < (usz) self.width * self.height; i++)
    {
        self.tiles[i].objects.free();
    }
    mem::free(self.tiles);
    self.actors.free();
}

struct ActorAction @private
{
    Actor* actor;
    Action action;
}

fn void Map.update(&self)
{
    assert(self.player != null, "Player is null in Map.update()");
    if (self.player.hasInput())
    {
        Action action = self.player.update(self, 1000000);

        int time = action.getTimeCost();
        if (time == 0) return;

        List(<ActorAction>) actions;
        actions.new_init();

        foreach(&actor: self.actors)
        {
            Action act = actor.update(self, time);
            if (act.type == WaitAction.typeid) continue;
            actions.push({ actor, act });
        }
        // @Todo: sort actions by time cost
        foreach(&act: actions)
        {
            act.actor.apply(self, act.action);
        }
        self.player.apply(self, action);

        self.elapsed_time += time;
    }
}

fn void Map.render(&self, TextBuffer* buffer)
{
    int[<2>] player_pos = self.player.position();
    int[<2>] min_pos = { player_pos[0] - buffer.width / 2, player_pos[1] - buffer.height / 2 };
    int[<2>] max_pos = { min_pos[0] + buffer.width - 1, min_pos[1] + buffer.height -1 };

    for (int y = math::max(0, min_pos[1]); y < math::min(self.height, max_pos[1]); y++)
    {
        for (int x = math::max(0, min_pos[0]); x < math::min(self.width, max_pos[0]); x++)
        {
            int[<2>] screen_pos = { x - min_pos[0], y - min_pos[1] };
            Tile* tile = &self.tiles[(usz) (y * self.width + x)];
            buffer.set(screen_pos, tile.bg_tile, tile.bg_color, rl::BLACK);
            foreach(&obj: tile.objects)
            {
                Appearance app = obj.getAppearance();
                buffer.set(screen_pos, app.icon, app.color, rl::BLANK);
            }
        }
    }

    foreach (&actor: self.actors)
    {
        int[<2>] pos = actor.position();
        int[<2>] screen_pos = { pos[0] - min_pos[0], pos[1] - min_pos[1] };
        if (screen_pos[0] >= 0 && screen_pos[0] < buffer.width && screen_pos[1] >= 0 && screen_pos[1] < buffer.height)
        {
            Appearance app = actor.getAppearance();
            buffer.set(screen_pos, app.icon, app.color, rl::BLANK);
        }
    }
    {
        int[<2>] pos = self.player.position();
        int[<2>] screen_pos = { pos[0] - min_pos[0], pos[1] - min_pos[1] };
        if (screen_pos[0] >= 0 && screen_pos[0] < buffer.width && screen_pos[1] >= 0 && screen_pos[1] < buffer.height)
        {
            Appearance app =  self.player.getAppearance();
            buffer.set(screen_pos, app.icon, app.color, rl::BLANK);
        }
    }
}

fn void TextBuffer.new_init(&self, int w, int h)
{
    self.width = w;
    self.height = h;
    self.tiles = mem::new_array(TextBufferTile, (usz) w * h);
}

fn void TextBuffer.clear(&self)
{
    for (usz i = 0; i < (usz) self.width * self.height; i++)
    {
        self.tiles[i].tile = 0;
        self.tiles[i].text[0] = 0;
        self.tiles[i].text[1] = 0;
        self.tiles[i].fg = rl::WHITE;
        self.tiles[i].bg = rl::BLACK;
    }
}

fn void TextBuffer.write(&self, String text, int[<2>] pos, rl::Color color)
{
    int tile_x = pos[0] / 2;
    int sub_x = pos[0] % 2;
    for (int i = 0; i < text.len; i++)
    {
        if (tile_x >= self.width || pos[1] >= self.height)
        {
            break;
        }
        TextBufferTile* tile = &self.tiles[(usz) (pos[1] * self.width + tile_x)];
        tile.text[sub_x] = text[i];
        tile.fg = color;
        if (sub_x == 1)
        {
            tile_x++;
            sub_x = 0;
        }
        else
        {
            sub_x++;
        }
    }
}

fn void TextBuffer.set(&self, int[<2>] pos, char icon, rl::Color fg, rl::Color bg)
{
    if (pos[0] >= 0 && pos[0] < self.width && pos[1] >= 0 && pos[1] < self.height)
    {
        TextBufferTile* tile = &self.tiles[(usz) (pos[1] * self.width + pos[0])];
        tile.tile = icon;
        tile.fg = fg;
        tile.bg = bg;
    }
}

fn void init(RLSettings settings)
{
    g_internal.ta = allocator::temp();
    g_internal.settings = settings;

    g_internal.buffer.new_init(settings.width, settings.height);

    rl::initWindow(settings.width * settings.font_size, settings.height * settings.font_size, settings.name);
    rl::setTargetFPS(60);
    rl::setExitKey(0);

    g_internal.font_tex = rl::loadTexture(settings.font.zstr_tcopy());
    g_internal.hfont_tex = rl::loadTexture(settings.hfont.zstr_tcopy());

    g_internal.current_state = settings.initial_state;
    g_internal.current_map = settings.initial_state.getMap();
}

fn bool update()
{
    g_internal.ta.reset(0);
    if (rl::windowShouldClose())
    {
        return false;
    }

    g_internal.buffer.clear();
    if (g_internal.next_state != null)
    {
        g_internal.current_state.free();
        mem::free(g_internal.current_state);
        g_internal.current_state = g_internal.next_state;
        g_internal.next_state = null;
        g_internal.current_map.free();
        mem::free(g_internal.current_map);
        g_internal.current_map = g_internal.current_state.getMap();
    }
    assert(g_internal.current_state != null, "Current state is null in update()");
    assert(g_internal.current_map != null, "Current map is null in update()");
    g_internal.current_state.update(g_internal.current_map);
    g_internal.current_map.update();

    int[<2>] player_pos = g_internal.current_map.player.position();
    g_internal.buffer.write(string::tformat("T%.1f  @ <%d %d>", g_internal.current_map.elapsed_time / 100.0f, player_pos[0], player_pos[1]), { 0, 0 }, rl::WHITE);
    g_internal.current_map.render(&g_internal.buffer);

    return true;
}

fn void drawTile(int x, int y, char c, rl::Color col)
{
    rl::Rectangle src = { 
        (float) (c % 16) * g_internal.settings.font_size, (float) (c / 16) * g_internal.settings.font_size,
        g_internal.settings.font_size, g_internal.settings.font_size
    };
    rl::Rectangle dest = {
        (float) x * g_internal.settings.font_size, (float) y * g_internal.settings.font_size,
        g_internal.settings.font_size, g_internal.settings.font_size
    };

    rl::drawTexturePro(g_internal.font_tex, src, dest, { 0, 0 }, 0, col);
}

fn void drawText(int x, int y, char c, rl::Color col)
{
    rl::Rectangle src = {
        (float) (c % 16) * g_internal.settings.font_size / 2.0f, (float) (c / 16) * g_internal.settings.font_size,
        g_internal.settings.font_size / 2.0f, g_internal.settings.font_size
    };
    rl::Rectangle dest = {
        (float) x * g_internal.settings.font_size / 2.0f, (float) y * g_internal.settings.font_size,
        g_internal.settings.font_size / 2.0f, g_internal.settings.font_size
    };

    rl::drawTexturePro(g_internal.hfont_tex, src, dest, { 0, 0 }, 0, col);
}

fn void render()
{
    rl::beginDrawing();

    rl::clearBackground(rl::BLACK);

    for (int y = 0; y < g_internal.buffer.height; y++)
    {
        for (int x = 0; x < g_internal.buffer.width; x++)
        {
            TextBufferTile* tile = &g_internal.buffer.tiles[(usz) (y * g_internal.buffer.width + x)];
            rl::drawRectangle(x * g_internal.settings.font_size, y * g_internal.settings.font_size, g_internal.settings.font_size, g_internal.settings.font_size, tile.bg);
            if (tile.tile != 0)
            {
                drawTile(x, y, tile.tile, tile.fg);
            }
            if (tile.text[0] != 0)
            {
                drawText(x * 2, y, tile.text[0], tile.fg);
            }
            if (tile.text[1] != 0)
            {
                drawText(x * 2 + 1, y, tile.text[1], tile.fg);
            }
        }
    }

    rl::endDrawing();
}

fn void changeState(GameState state)
{
    g_internal.next_state = state;
}

fn TextBuffer* textbuffer() => &g_internal.buffer;

module roguelike @private;
import raylib5::rl;

struct RLInternal
{
    RLSettings settings;
    TextBuffer buffer;

    rl::Texture2D font_tex;
    rl::Texture2D hfont_tex;

    TempAllocator* ta;

    Map* current_map;
    GameState current_state;
    GameState next_state;
}

RLInternal g_internal;
