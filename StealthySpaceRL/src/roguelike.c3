module roguelike;

import raylib5::rl;

struct RLSettings
{
    int width;
    int height;
    String name;

    String font;
    String hfont;
    int font_size;
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

fn void TextBuffer.set(&self, int[<2>] pos, char tile, rl::Color fg, rl::Color bg)
{
    if (pos[0] >= 0 && pos[0] < self.width && pos[1] >= 0 && pos[1] < self.height)
    {
        TextBufferTile* tile = &self.tiles[(usz) (pos[1] * self.width + pos[0])];
        tile.tile = tile;
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
}

fn bool update()
{
    g_internal.ta.reset(0);
    if (rl::windowShouldClose())
    {
        return false;
    }

    g_internal.buffer.clear();

    g_internal.buffer.write("Hello World", { 20, 10 }, rl::WHITE);

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
}

RLInternal g_internal;
