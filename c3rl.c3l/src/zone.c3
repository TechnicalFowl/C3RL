module c3rl;

import std::collections::list;
import std::collections::map;
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

    @call_event(PostLoadEvent, on_post_load, self.player);
    foreach (ent: self.all_entities)
    {
        @call_event(PostLoadEvent, on_post_load, ent);
    }
}

fn void Zone.free(&self)
{
    for (int i = 0; i < self.width * self.height; ++i)
    {
        self.cells[i].entities.free();
    }
    mem::free(self.cells);

    foreach (ent: self.all_entities)
    {
        ent.free();
    }
    self.all_entities.free();
}

struct EntityAction
{
    Entity entity;
    Action next_action;
    double duration;
    double remaining_time;
}
fn bool EntityAction.less(EntityAction* a, EntityAction* b) => a.duration < b.duration;

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
        actions.new_init(math::max(self.all_entities.len() + 1u64, 16u64), allocator::temp());
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

fn IVec2 Zone.get_player_position(&self)
{
    assert(self.player != null, "No player in zone");
    return self.player.get_position();
}

fn IVec2 Zone.get_mouse_position(&self)
{
    int hw = terminal.width / 2;
    int hh = terminal.height / 2;

    int focus_x = hw;
    int focus_y = hh;

    if (self.player)
    {
        focus_x = self.player.get_position()[0];
        focus_y = self.player.get_position()[1];
    }

    int min_y = focus_y - hh;
    int min_x = focus_x - hw;

    int x = min_x + rl::getMouseX() / settings.default_font_size;
    int y = min_y + rl::getMouseY() / settings.default_font_size;
    return {x, y};
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

    VisibilityTracker* vis = null;
    EntityVisibility ev = (EntityVisibility) self.player;
    if (&ev.get_visibility)
    {
        vis = ev.get_visibility();
    }

    for (int y = focus_y - hh; y < focus_y + hh; ++y)
    {
        if (y < 0 || y >= self.height) continue;
        int term_y = y - min_y;
        for (int x = focus_x - hw; x < focus_x + hw; ++x)
        {
            if (x < 0 || x >= self.width) continue;
            bool is_explored = vis == null || vis.is_explored({x, y});
            if (!is_explored) continue;
            int term_x = x - min_x;
            ZoneCell* cell = &self.cells[x + y * self.width];
            ZoneTerrain terr = cell.terrain;
            bool is_visible = vis == null || vis.is_visible({x, y});
            term.set_background(term_x, term_y, is_visible ? terr.bg : terr.bg.grayscale().darken(0.4f));
            if (cell.entities.is_empty() || !is_visible)
            {
                term.set_tile(term_x, term_y, terr.glyph, is_visible ? terr.fg : terr.fg.grayscale().darken(0.4f));
            }
            else
            {
                Entity first = cell.entities.first()!!;
                term.set_tile(term_x, term_y, first.get_glyph(), first.get_color());
            }
        }
    }
}

fn double get_diag_heuristic(IVec2 a, IVec2 b)
{
    int dx = math::abs(a[0] - b[0]);
    int dy = math::abs(a[1] - b[1]);
    return (double) (dx + dy) + (-0.58578643762) * math::min(dx, dy);
}

fn double get_heuristic(IVec2 a, IVec2 b)
{
    int dx = math::abs(a[0] - b[0]);
    int dy = math::abs(a[1] - b[1]);
    return (double) (dx + dy);
}

fn uint IVec2.hash(self) => ((uint) self[0]) * 2654435761u + ((uint) self[1]);

struct AStarStep
{
    IVec2 pos;
    IVec2 last;
    double cost;
}

fn bool AStarStep.less(AStarStep* a, AStarStep b) => a.cost < b.cost;

const IVec2[4] DIRECT_NEIGHBORS = { {0, -1}, {0, 1}, {-1, 0}, {1, 0} };
const IVec2[4] DIAGONAL_NEIGHBORS = { {-1, -1}, {1, -1}, {-1, 1}, {1, 1} };

fn bool Zone.path(&self, IVec2 from, IVec2 to, List(<IVec2>)* results, bool diagonal_moves=true, bool reverse=false)
{
    PriorityQueue(<AStarStep>) frontier;
    frontier.temp_init(16);
    HashMap(<IVec2, AStarStep>) came_from;
    came_from.temp_init(16);

    frontier.push({from, from, 0});
    came_from.set(from, {from, from, 0});

    //io::printfn("Pathfinding from [%d %d] to [%d %d]", ...from, ...to);

    while (!frontier.is_empty())
    {
        AStarStep current = frontier.pop()!!;
        if (current.pos == to) break;
        
        foreach (n: DIRECT_NEIGHBORS)
        {
            IVec2 next = current.pos + n;
            if (next[0] < 0 || next[0] >= self.width || next[1] < 0 || next[1] >= self.height) continue;
            ZoneCell* cell = self.get_cell(...next);
            if (!cell.terrain.passable) continue;
            
            double new_cost = current.cost + 1;
            double h_cost = new_cost + (diagonal_moves ? get_diag_heuristic(next, to) : get_heuristic(next, to));
            AStarStep! existing = came_from.get(next);
            if (try existing && existing.cost <= h_cost) continue;
            AStarStep next_step = {next, current.pos, h_cost};
            //io::printfn("Adding [%d %d] to frontier pathed from [%d %d] with cost %.1f", ...next, ...current.pos, next_step.cost);
            frontier.push(next_step);
            came_from.set(next, next_step);
        }
        if (diagonal_moves)
        {
            foreach (n: DIAGONAL_NEIGHBORS)
            {
                IVec2 next = current.pos + n;
                if (next[0] < 0 || next[0] >= self.width || next[1] < 0 || next[1] >= self.height) continue;
                ZoneCell* cell = self.get_cell(...next);
                if (!cell.terrain.passable) continue;
                
                double new_cost = current.cost + 1.414;
                double h_cost = new_cost + get_diag_heuristic(next, to);
                AStarStep! existing = came_from.get(next);
                if (try existing && existing.cost <= h_cost) continue;
                AStarStep next_step = {next, current.pos, h_cost};
                //io::printfn("Adding [%d %d] to frontier pathed from [%d %d] with cost %.1f", ...next, ...current.pos, next_step.cost);
                frontier.push(next_step);
                came_from.set(next, next_step);
            }
        }
    }

    if (!came_from.has_key(to)) return false;

    IVec2 step_back = to;

    results.clear();
    while (step_back != from)
    {
        results.push(step_back);
        AStarStep! step = came_from.get(step_back);
        if (catch step)
        {
            unreachable("Pathfinding error");
        }
        step_back = step.last;
    }
    if (!reverse) results.reverse();

    //io::printfn("Done pathfinding, found %d steps", results.len());
    //io::printn(results);
    return true;
}

def ZoneGenerator = fn void(void* data, Zone* zone);
struct ZoneDescription
{
    String name;
    int width;
    int height;

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

def LineCallback = fn bool(void* data, IVec2 next);
fn void line(IVec2 start, IVec2 end, LineCallback callback, void* data=null)
{
    if (start == end) return;

    IVec2 delta = math::abs(end - start);
    IVec2 step = ivec2_sign(end - start);

    int err = delta[0] - delta[1];

    do
    {
        if (2 * err > -delta[1])
        {
            err -= delta[1];
            start[0] += step[0];
        }
        else if (2 * err < delta[0])
        {
            err += delta[0];
            start[1] += step[1];
        }
    } while (callback(data, start) && start != end);
}