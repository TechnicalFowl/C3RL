module c3rl;

import std::collections::list;

import raylib5::rl;

Zone* zone;

struct ZoneTerrain
{
    char glyph;
    rl::Color fg;
    rl::Color bg;
    bool passable;
}

struct ZoneCell
{
    ZoneTerrain terrain;
    List(<Entity*>) entities;
}

struct Zone
{
    String name;
    int width;
    int height;
    ZoneCell* cells;

    Ecs ecs;
}

fn void Zone.new_init(&self, ZoneDescription desc)
{
    self.name = desc.name;
}

fn void Zone.update(&self, double delta)
{
    self.ecs.update(delta);
}

fn ZoneCell* Zone.get_cell(&self, int x, int y)
{
    return &self.cells[y * self.width + x];
}

fn void Zone.set_terrain(&self, int x, int y, char glyph, rl::Color fg, rl::Color bg, bool passable)
{
    ZoneCell* cell = self.get_cell(x, y);
    cell.terrain.glyph = glyph;
    cell.terrain.fg = fg;
    cell.terrain.bg = bg;
    cell.terrain.passable = passable;
}

def ZoneGenerator = fn void(void* data, Zone* zone);
struct ZoneDescription
{
    String name;
    int width;
    int height;

    int[<2>] player_spawn;

    ZoneGenerator generator;
}

fn void ZoneDescription.new_init(&self, String name, int width, int height)
{
    self.name = name;
    self.width = width;
    self.height = height;
}

fn void load_zone(ZoneDescription desc)
{
    zone = mem::new(Zone);
}

def LineCallback = fn void(void* data, int[<2>] next);
fn void line(int[<2>] start, int[<2>] end, LineCallback callback, void* data=null)
{
    int x0 = start[0];
    int y0 = start[1];
    int x1 = end[0];
    int y1 = end[1];

    int dx = x1 - x0;
    int dy = y1 - y0;

    int sx = 1;
    int sy = 1;

    if (dx < 0)
    {
        dx = -dx;
        sx = -1;
    }

    if (dy < 0)
    {
        dy = -dy;
        sy = -1;
    }

    int err = dx - dy;

    while (true)
    {
        callback(data, {x0, y0});

        if (x0 == x1 && y0 == y1) break;

        int e2 = 2 * err;

        if (e2 > -dy)
        {
            err -= dy;
            x0 += sx;
        }

        if (e2 < dx)
        {
            err += dx;
            y0 += sy;
        }
    }
}