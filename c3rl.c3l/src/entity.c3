module c3rl;

import std::collections::list;
import std::collections::map;
import std::io;

import raylib5::rl;

interface PostLoadEvent
{
    fn void on_post_load() @optional;
}

interface OnDeadEvent
{
    fn void on_dead() @optional;
}

macro @call_event($Type, #func, any e, ...)
{
    $Type h = ($Type) e;
    if (&h.#func) h.#func($vasplat);
}

interface Action
{
    fn double duration();
    fn void apply(Entity ent);
}

struct WaitAction (Action)
{
    double time;
}
fn double WaitAction.duration(&self) @dynamic => self.time;
fn void WaitAction.apply(&self, Entity ent) @dynamic
{
    ent.give_idle_time(self.time);
}

fn WaitAction* do_wait(double time)
{
    WaitAction* wait = mem::temp_alloc(WaitAction);
    wait.time = time;
    return wait;
}

struct MoveAction (Action)
{
    IVec2 move;
}
fn double MoveAction.duration(&self) @dynamic => 1.0;

fn void MoveAction.apply(&self, Entity entity) @dynamic
{
    IVec2 new_pos = entity.get_position() + self.move;

    ZoneCell*! cell = entity.get_zone().get_cell(...new_pos);
    if (cell.is_passable() ?? false)
    {
        entity.set_position(new_pos);
    }
}

fn MoveAction* do_move(IVec2 move)
{
    MoveAction* move_action = mem::temp_alloc(MoveAction);
    move_action.move = move;
    return move_action;
}

interface Entity
{
    fn void free();

    fn Zone* get_zone();
    fn String get_name();
    fn IVec2 get_position();
    fn void set_position(IVec2 pos);
    fn bool is_dead();

    fn Appearance get_look();

    fn double get_idle_time();
    fn void give_idle_time(double time);

    fn Action next_action(double max_time);

    fn void on_update(double delta_time);
    fn void on_render(VirtualTerminal* terminal, IVec2 term_pos);
}

fn void entity_set_position(Entity self, IVec2 new_pos)
{
    Zone* zone = self.get_zone();
    ZoneCell* cell = zone.get_cell(...self.get_position())!!;
    cell.entities.remove_item(self);
    ZoneCell* new_cell = zone.get_cell(...new_pos)!!;
    new_cell.entities.push(self);
}

struct Navigator
{
    List(<IVec2>) path;
}

fn void Navigator.new_init(&self)
{
    self.path.new_init();
}
fn void Navigator.free(&self)
{
    self.path.free();
}

fn bool Navigator.is_idle(&self) => self.path.is_empty();

fn void Navigator.path_to(&self, Zone* zone, IVec2 start, IVec2 end)
{
    self.path.clear();
    zone.path(start, end, &self.path, diagonal_moves: false, reverse: true);
}

fn IVec2 Navigator.next_point(&self)
{
    assert(!self.path.is_empty(), "No path to follow");
    return self.path.pop()!!;
}

fn void Navigator.abort(&self)
{
    self.path.clear();
}

interface EntityVisibility
{
    fn VisibilityTracker* get_visibility();
}

struct VisibilityTracker
{
    Zone* zone;
    BitBoard visible;
    BitBoard explored;
}

fn void VisibilityTracker.new_init(&self, Zone* z)
{
    self.zone = z;
    self.visible.new_init(...z.size);
    self.explored.new_init(...z.size);
}

fn void VisibilityTracker.free(&self)
{
    self.visible.free();
    self.explored.free();
}

struct VisibilityTrackerCB
{
    VisibilityTracker* vis;
    int step;
    int range;
}

fn bool VisibilityTrackerCB.line_cb(&self, IVec2 pos) @private
{
    self.vis.set_visible(pos, true);
    self.vis.set_explored(pos, true);
    return self.step++ < self.range && self.vis.zone.get_cell(...pos).is_passable() ?? false;
}

fn void VisibilityTracker.sweep_line(&self, IVec2 from, IVec2 to)
{
    self.set_visible(from, true);
    self.set_explored(from, true);
    VisibilityTrackerCB cb_data = { self, 0, from.distance(to) };
    c3rl::line(from, to, (LineCallback) &VisibilityTrackerCB.line_cb, &cb_data);
}

fn void VisibilityTracker.sweep(&self, IVec2 pos, int range)
{
    self.visible.clear();
    self.set_visible(pos, true);
    self.set_explored(pos, true);
    
    VisibilityTrackerCB cb_data = { self, 0, range };

    // Box sweep
    for (int i = -range; i <= range; ++i)
    {
        cb_data.step = 0;
        c3rl::line(pos, pos + {i, -range}, (LineCallback) &VisibilityTrackerCB.line_cb, &cb_data);
        cb_data.step = 0;
        c3rl::line(pos, pos + {i, range}, (LineCallback) &VisibilityTrackerCB.line_cb, &cb_data);
        cb_data.step = 0;
        c3rl::line(pos, pos + {-range, i}, (LineCallback) &VisibilityTrackerCB.line_cb, &cb_data);
        cb_data.step = 0;
        c3rl::line(pos, pos + {range, i}, (LineCallback) &VisibilityTrackerCB.line_cb, &cb_data);
    }
}

fn void VisibilityTracker.clear(&self)
{
    self.visible.clear();
    self.explored.clear();
}

fn bool VisibilityTracker.is_visible(&self, IVec2 pos)
{
    return self.visible.get(pos);
}

fn bool VisibilityTracker.is_explored(&self, IVec2 pos)
{
    return self.explored.get(pos);
}

fn void VisibilityTracker.set_visible(&self, IVec2 pos, bool visible)
{
    self.visible.set(pos, visible);
}

fn void VisibilityTracker.set_explored(&self, IVec2 pos, bool visible)
{
    self.explored.set(pos, visible);
}
