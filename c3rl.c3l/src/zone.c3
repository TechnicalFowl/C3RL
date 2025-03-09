module c3rl;

import std::collections::list;
import std::collections::map;
import std::collections::priorityqueue;
import std::io;
import std::math;

import raylib5::rl;

const uint TERRAIN_FLAG_PASSABLE = 1 << 0;

struct TerrainInfo
{
    String name;
    uint flags;
    Appearance look;
    String description;
}

fn bool TerrainInfo.is_passable(&self) => (self.flags & TERRAIN_FLAG_PASSABLE) != 0;

const uint OBJECT_FLAG_PASSABLE = 1 << 0;

interface ObjectBehavior
{

}

struct ObjectInfo
{
    String name;
    uint flags;
    Appearance look;
    String description;
    ObjectBehavior behavior;
}

fn bool ObjectInfo.is_passable(&self) => (self.flags & OBJECT_FLAG_PASSABLE) != 0;

fault ZoneFault
{
    OUT_OF_BOUNDS,
}

struct ZoneCell
{
    game::Terrain terrain;
    game::Object object;
    //List(<ItemStack>) items;
    List(<Entity>) entities;
}

fn bool ZoneCell.is_passable(&self) => self.terrain.info.is_passable() && self.object.info.is_passable();

def ZoneGenerator = fn void(void* data, Zone* zone);
struct ZoneDescription
{
    String name;
    int width;
    int height;

    ZoneGenerator generator;
    void* generator_data;
}

<*
@require width > 0: "Zone width must be greater than 0"
@require height > 0: "Zone height must be greater than 0"
*>
fn void ZoneDescription.new_init(&self, String name, int width, int height)
{
    self.name = name;
    self.width = width;
    self.height = height;
}

struct ZoneRenderSettings
{
    int map_zoom;
    IVec2 center;
    IVec2 screen_center;
    IVec2 pixel_offset;
    VisibilityTracker* camera_visibility;
}

struct Zone
{
    String name;
    IVec2 size;
    ZoneCell* cells;

    List(<Entity>) all_entities;

    ZoneRenderSettings render;

    IVec2 last_render_min;
    IVec2 last_mouse_pos;
    double mouse_hover_time;
}

<*
@require desc.width > 0: "Zone width must be greater than 0"
@require desc.height > 0: "Zone height must be greater than 0"
*>
fn void Zone.new_init(&self, ZoneDescription desc)
{
    self.name = desc.name;
    self.size = {desc.width, desc.height};
    self.cells = mem::new_array(ZoneCell, (usz) self.size.x * self.size.y);

    for (int i = 0; i < self.size.x * self.size.y; ++i)
    {
        ZoneCell* cell = &self.cells[i];
        cell.terrain = Terrain.from_ordinal(0);
        cell.object = Object.from_ordinal(0);
        cell.entities.new_init();
    }

    if (desc.generator)
    {
        desc.generator(desc.generator_data, self);
    }

    foreach (ent: self.all_entities)
    {
        @call_event(PostLoadEvent, on_post_load, ent);
    }

    self.render.map_zoom = 1;
}

fn void Zone.free(&self)
{
    for (int i = 0; i < self.size.x * self.size.y; ++i)
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

fn double Zone.update(&self, RLGame game)
{
    @pool()
    {
        Entity player = game.get_player();
        if (player == null) return 0.0;
        Action player_action = player.next_action(100000);
        if (player_action == null) return 0.0;

        double max_time = player_action.duration();
        PriorityQueue(<EntityAction*>) actions;
        actions.new_init(math::max(self.all_entities.len() + 1u64, 16u64), allocator::temp());
        actions.push(make_entity_action(player, player_action, max_time, 0));

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

        if (&game.update) game.update(max_time);

        for (int i = (int) self.all_entities.len() - 1; i >= 0; --i)
        {
            Entity e = self.all_entities[i];
            if (e.is_dead())
            {
                @call_event(OnDeadEvent, on_dead, e);

                ZoneCell* cell = self.get_cell(...e.get_position())!!;
                cell.entities.remove_item(e);
                self.all_entities.remove_at(i);
                e.free();
                mem::free(e);
            }
            else
            {
                e.on_update(max_time);
            }
        }

        return max_time;
    };
}

fn ZoneCell*! Zone.get_cell(&self, int x, int y)
{
    if (x < 0 || x >= self.size.x || y < 0 || y >= self.size.y) return ZoneFault.OUT_OF_BOUNDS?;
    return &self.cells[y * self.size.x + x];
}

fn void Zone.set_terrain(&self, int x, int y, game::Terrain terr)
{
    ZoneCell* cell = self.get_cell(x, y)!!;
    cell.terrain = terr;
}

fn void Zone.fill_terrain(&self, IVec2 pos, IVec2 size, game::Terrain terr)
{
    for (int y = pos.y; y < pos.y + size.y; ++y)
    {
        for (int x = pos.x; x < pos.x + size.x; ++x)
        {
            self.set_terrain(x, y, terr);
        }
    }
}

fn void Zone.set_object(&self, int x, int y, game::Object obj)
{
    ZoneCell* cell = self.get_cell(x, y)!!;
    cell.object = obj;
}

<*
@param [&in] e
*>
fn void Zone.add_entity(&self, Entity e)
{
    self.all_entities.push(e);
    ZoneCell* cell = self.get_cell(...e.get_position())!!;
    cell.entities.push(e);
}

fn IVec2 Zone.get_mouse_position(&self)
{
    return self.pixel_to_cell({ rl::getMouseX(), rl::getMouseY() });
}

fn IVec2 Zone.pixel_to_cell(&self, IVec2 pos)
{
    Font* font = is_textmode ? root_font : root_sprite_font;
    int x = self.last_render_min.x + (pos.x - self.render.pixel_offset.x) / (font.width * self.render.map_zoom);
    int y = self.last_render_min.y + (pos.y - self.render.pixel_offset.y) / (font.height * self.render.map_zoom);
    return {x, y};
}

fn IVec2 Zone.find_nearest_empty(&self, IVec2 pos)
{
    int x = 0;
    int y = 0;
    int dx = 0;
    int dy = -1;
    const int RANGE = 10;
    for (int i = 0; i < RANGE * RANGE * 4; ++i)
    {
        if (self.get_cell(pos.x + x, pos.y + y).is_passable() ?? false) return pos;
        if  (x == y || ((x < 0) && (x == -y)) || ((x > 0) && (x == 1 - y)))
        {
            int t = dx;
            dx = -dy;
            dy = t;
        }
        x += dx;
        y += dy;
    }
    return pos;
}

struct ZoneVisCB
{
    Zone* zone;
    bool visible;
}

fn bool ZoneVisCB.line_cb(&self, IVec2 pos) @private
{
    ZoneCell*! cell = self.zone.get_cell(...pos);
    if (!cell.is_passable() ?? true)
    {
        self.visible = false;
        return false;
    }
    return true;
}

fn bool Zone.can_see(&self, IVec2 from, IVec2 to)
{
    ZoneVisCB cb_data = { self, true };
    line(from, to, (LineCallback) &ZoneVisCB.line_cb, &cb_data);
    return cb_data.visible;
}


<*
@param [&in] term
*>
fn void Zone.render_zone(&self, VirtualTerminal* term)
{
    IVec2 hsize = {term.width / 2, term.height / 2};
    IVec2 focus = self.render.center;

    IVec2 min = focus - hsize;
    IVec2 max = focus + hsize;

    self.last_render_min = min;
    
    Font* font = is_textmode ? root_font : root_sprite_font;

    for (int y = min[1]; y < max[1]; ++y)
    {
        if (y < 0 || y >= self.size.y) continue;
        int term_y = y - min[1];
        for (int x = min[0]; x < max[0]; ++x)
        {
            if (x < 0 || x >= self.size.x) continue;
            if (self.render.camera_visibility != null && !self.render.camera_visibility.is_explored({x, y})) continue;
            int term_x = x - min[0];
            ZoneCell* cell = &self.cells[x + y * self.size.x];
            bool is_visible = self.render.camera_visibility == null || self.render.camera_visibility.is_visible({x, y});
            
            if (cell.terrain.ordinal != 0)
            {
                TerrainInfo terr = cell.terrain.info;
                AppearanceInfo look = terr.look.info;
                bool textmode = is_textmode || look.sprite_index < 0;
                char gl = textmode ? look.glyph : (char) look.sprite_index;
                rl::Color color = textmode ? look.color : rl::WHITE;
                if (!is_visible)
                {
                    color = color.grayscale().darken(0.4f);
                }
                term.set_tile(term_x, term_y, gl, color, 0, textmode ? root_font : root_sprite_font);
            }
            if (cell.object.ordinal != 0)
            {
                ObjectInfo obj = cell.object.info;
                AppearanceInfo look = obj.look.info;
                bool textmode = is_textmode || look.sprite_index < 0;
                char gl = textmode ? look.glyph : (char) look.sprite_index;
                rl::Color color = textmode ? look.color : rl::WHITE;
                if (!is_visible)
                {
                    color = color.grayscale().darken(0.4f);
                }
                term.set_tile(term_x, term_y, gl, color, textmode ? 0 : 1, textmode ? root_font : root_sprite_font);
            }
            if (is_visible && !cell.entities.is_empty())
            {
                Entity first = cell.entities.first()!!;

                AppearanceInfo look = first.get_look().info;
                bool textmode = is_textmode || look.sprite_index < 0;
                char gl = textmode ? look.glyph : (char) look.sprite_index;
                rl::Color color = textmode ? look.color : rl::WHITE;
                term.set_tile(term_x, term_y, gl, color, textmode ? 0 : 1, textmode ? root_font : root_sprite_font);
                first.on_render(term, {term_x, term_y});
            }
        }
    }
}

fn double get_diag_heuristic(IVec2 a, IVec2 b)
{
    IVec2 dv = math::abs(a - b);
    return dv.sum() + -0.58578643762 * dv.min_element();
}

fn double get_heuristic(IVec2 a, IVec2 b)
{
    IVec2 dv = math::abs(a - b);
    return (double) dv.sum();
}

struct AStarStep
{
    IVec2 pos;
    IVec2 last;
    double cost;
    double h_cost;
}

fn bool AStarStep.less(AStarStep* a, AStarStep b) => a.h_cost < b.h_cost;

const IVec2[4] DIRECT_NEIGHBORS = { {0, -1}, {0, 1}, {-1, 0}, {1, 0} };
const IVec2[4] DIAGONAL_NEIGHBORS = { {-1, -1}, {1, -1}, {-1, 1}, {1, 1} };

<*
@param [&in] results
*>
fn bool Zone.path(&self, IVec2 from, IVec2 to, List(<IVec2>)* results, bool diagonal_moves=true, bool reverse=false)
{
    if (from.x < 0 || from.x >= self.size.x || from.y < 0 || from.y >= self.size.y) return false;
    if (to.x < 0 || to.x >= self.size.x || to.y < 0 || to.y >= self.size.y) return false;
    PriorityQueue(<AStarStep>) frontier;
    frontier.temp_init(16);
    HashMap(<IVec2, AStarStep>) came_from;
    came_from.temp_init(16);

    frontier.push({from, from, 0, 0});
    came_from.set(from, {from, from, 0, 0});

    const DEBUG_PATHFINDING = false;

    if (DEBUG_PATHFINDING) io::printfn("Pathfinding from [%d %d] to [%d %d]", ...from, ...to);

    while (!frontier.is_empty())
    {
        AStarStep current = frontier.pop()!!;
        if (DEBUG_PATHFINDING) io::printfn("Popped [%d %d] with cost %.1f", ...current.pos, current.cost);
        if (current.pos == to) break;
        
        foreach (n: DIRECT_NEIGHBORS)
        {
            AStarStep save_current = current;
            IVec2 next = current.pos + n;
            if (DEBUG_PATHFINDING) io::printfn("  Checking [%d %d] -> [%d %d]", ...current.pos, ...next);
            if (next[0] < 0 || next[0] >= self.size.x || next[1] < 0 || next[1] >= self.size.y) continue;
            ZoneCell*! cell = self.get_cell(...next);
            if (catch cell)
            {
                if (DEBUG_PATHFINDING) io::printfn("    Skipped [%d %d] because it's out of bounds", ...next);
                current = save_current;
                continue;
            }
            if (!cell.is_passable() && next != to)
            {
                if (DEBUG_PATHFINDING) io::printfn("    Skipped [%d %d] because it's impassable", ...next);
                current = save_current;
                continue;
            }
            
            double new_cost = current.cost + 1;
            double h_cost = new_cost + (diagonal_moves ? get_diag_heuristic(next, to) : get_heuristic(next, to));
            AStarStep! existing = came_from.get(next);
            if (try existing && existing.cost <= new_cost)
            {
                if (DEBUG_PATHFINDING) io::printfn("    Skipped [%d %d] because it's already pathed with cost %.1f (new_cost was %.1f)", ...next, existing.cost, new_cost);
                current = save_current;
                continue;
            }
            AStarStep next_step = {next, current.pos, new_cost, h_cost};
            if (DEBUG_PATHFINDING) io::printfn("    Adding [%d %d] to frontier pathed from [%d %d] with cost %.1f", ...next, ...current.pos, next_step.cost);
            frontier.push(next_step);
            came_from.set(next, next_step);
            current = save_current;
        }
        if (diagonal_moves)
        {
            foreach (n: DIAGONAL_NEIGHBORS)
            {
                AStarStep save_current = current;
                IVec2 next = current.pos + n;
                if (DEBUG_PATHFINDING) io::printfn("  Checking [%d %d] -> [%d %d]", ...current.pos, ...next);
                if (next[0] < 0 || next[0] >= self.size.x || next[1] < 0 || next[1] >= self.size.y) continue;
                ZoneCell*! cell = self.get_cell(...next);
                if (catch cell)
                {
                    if (DEBUG_PATHFINDING) io::printfn("    Skipped [%d %d] because it's out of bounds", ...next);
                    current = save_current;
                    continue;
                }
                if (!cell.is_passable() && next != to)
                {
                    if (DEBUG_PATHFINDING) io::printfn("    Skipped [%d %d] because it's impassable", ...next);
                    current = save_current;
                    continue;
                }
                
                double new_cost = current.cost + 1.414;
                double h_cost = new_cost + get_diag_heuristic(next, to);
                AStarStep! existing = came_from.get(next);
                if (try existing && existing.cost <= new_cost)
                {
                    if (DEBUG_PATHFINDING) io::printfn("    Skipped [%d %d] because it's already pathed with cost %.1f (new_cost was %.1f)", ...next, existing.cost, new_cost);
                    current = save_current;
                    continue;
                }
                AStarStep next_step = {next, current.pos, new_cost, h_cost};
                if (DEBUG_PATHFINDING) io::printfn("    Adding [%d %d] to frontier pathed from [%d %d] with cost %.1f", ...next, ...current.pos, next_step.cost);
                frontier.push(next_step);
                came_from.set(next, next_step);
                current = save_current;
            }
        }
    }

    if (!came_from.has_key(to)) return false;

    IVec2 step_back = to;
    if (DEBUG_PATHFINDING) io::printfn("Final path from [%d %d] to [%d %d]", ...from, ...to);
    results.clear();
    while (step_back != from)
    {
        results.push(step_back);
        AStarStep! step = came_from.get(step_back);
        if (catch step) unreachable("Pathfinding error");
        if (DEBUG_PATHFINDING) io::printfn("    [%d %d] from [%d %d]", ...step_back, ...step.last);
        step_back = step.last;
    }
    if (!reverse) results.reverse();

    if (DEBUG_PATHFINDING) io::printfn("Done pathfinding, found %d steps", results.len());
    if (DEBUG_PATHFINDING) io::printn(results);
    return true;
}

def LineCallback = fn bool(void* data, IVec2 next);
fn void line(IVec2 start, IVec2 end, LineCallback callback, void* data=null)
{
    if (start == end) return;

    IVec2 delta = math::abs(end - start);
    IVec2 step = (end - start).sign();

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

fn void spiral(IVec2 start, int range, LineCallback cb, void* cb_data=null)
{
    int x = 0;
    int y = 0;
    int dx = 0;
    int dy = -1;
    for (int i = 0; i < range * range * 4; ++i)
    {
        if (!cb(cb_data, start + {x, y})) break;
        if  (x == y || ((x < 0) && (x == -y)) || ((x > 0) && (x == 1 - y)))
        {
            int t = dx;
            dx = -dy;
            dy = t;
        }
        x += dx;
        y += dy;
    }
}