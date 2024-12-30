module c3rl;

import std::collections::list;
import std::collections::priorityqueue;
import std::io;
import std::math;

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
    List(<Entity>) entities;
}

struct Zone
{
    String name;
    int width;
    int height;
    ZoneCell* cells;

    Entity player;
    List(<Entity>) all_entities;
}

fn void Zone.new_init(&self, ZoneDescription desc)
{
    self.name = desc.name;
    self.width = desc.width;
    self.height = desc.height;
    self.cells = mem::new_array(ZoneCell, (usz) self.width * self.height);

    for (int i = 0; i < self.width * self.height; ++i)
    {
        ZoneCell* cell = &self.cells[i];
        cell.terrain = { ' ', colors::WHITE, colors::BLACK, true };
        cell.entities.new_init();
    }

    desc.generator(desc.generator_data, self);

    assert(self.player != null, "No player provided");
}

struct EntityAction
{
    Entity entity;
    Action next_action;
    double duration;
    double remaining_time;
}
fn bool less(EntityAction* a, EntityAction* b) => a.duration < b.duration;

fn EntityAction* make_entity_action(Entity e, Action act, double duration, double remaining)
{
    EntityAction* ea = mem::temp_alloc(EntityAction);
    ea.entity = e;
    ea.next_action = act;
    ea.duration = duration;
    ea.remaining_time = remaining;
    return ea;
}

fn void Zone.update(&self)
{
    @pool()
    {
        Action player_action = self.player.next_action(100000);
        if (player_action == null) return;

        double max_time = player_action.duration();
        PriorityQueue(<EntityAction*>) actions;
        actions.push(make_entity_action(self.player, player_action, max_time, 0));

        foreach (ent: self.all_entities)
        {
            Action a = ent.next_action(max_time + ent.get_idle_time());
            if (a == null) continue;
            double ad = a.duration();
            actions.push(make_entity_action(ent, a, ad, max_time - ad));
        }

        while (!actions.is_empty())
        {
            EntityAction* next = actions.pop()!!;
            next.next_action.apply(next.entity);
            if (next.remaining_time > 0)
            {
                Action continuation = next.entity.next_action(next.remaining_time);
                if (continuation == null) continue;
                double cont_duraction = continuation.duration();
                actions.push(make_entity_action(next.entity, continuation, next.duration + cont_duraction, next.remaining_time - cont_duraction));
            }
        }
    };
}

fn ZoneCell* Zone.get_cell(&self, int x, int y)
{
    assert(x >= 0 && x < self.width && y >= 0 && y < self.height, "Position [%d %d] must be greater than zero and less than [%d %d]", x, y, self.width, self.height);
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

fn void Zone.add_player(&self, Entity e)
{
    assert(e != null);
    self.player = e;
    ZoneCell* cell = self.get_cell(...e.get_position());
    cell.entities.push(e);
}

fn void Zone.add_entity(&self, Entity e)
{
    assert(e != null);
    self.all_entities.push(e);
    ZoneCell* cell = self.get_cell(...e.get_position());
    cell.entities.push(e);
}

fn void Zone.render(&self, VirtualTerminal* term)
{
    int hw = term.width / 2;
    int hh = term.height / 2;

    int focus_x = hw;
    int focus_y = hh;

    if (self.player)
    {
        focus_x = self.player.get_position()[0];
        focus_y = self.player.get_position()[1];
    }

    int min_y = focus_y - hh;
    int min_x = focus_x - hw;

    for (int y = focus_y - hh; y < focus_y + hh; ++y)
    {
        if (y < 0 || y >= self.height) continue;
        int term_y = y - min_y;
        for (int x = focus_x - hw; x < focus_x + hw; ++x)
        {
            if (x < 0 || x >= self.width) continue;
            int term_x = x - min_x;
            ZoneCell* cell = &self.cells[x + y * self.width];
            ZoneTerrain terr = cell.terrain;
            term.set_background(term_x, term_y, terr.bg);
            if (cell.entities.is_empty())
            {
                term.set_tile(term_x, term_y, terr.glyph, terr.fg);
            }
            else
            {
                Entity first = cell.entities.first()!!;
                term.set_tile(term_x, term_y, first.get_glyph(), first.get_color());
            }
        }
    }
}

def ZoneGenerator = fn void(void* data, Zone* zone);
struct ZoneDescription
{
    String name;
    int width;
    int height;

    int[<2>] player_spawn;

    ZoneGenerator generator;
    void* generator_data;
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
    zone.new_init(desc);
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