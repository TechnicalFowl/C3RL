module c3rl;

import std::collections::list;
import std::collections::map;
import std::io;

import raylib5::rl;

interface Event
{
    
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
    int[<2>] move;
}
fn double MoveAction.duration(&self) @dynamic => 1.0;

fn void MoveAction.apply(&self, Entity entity) @dynamic
{
    int[<2>] new_pos = entity.get_position() + self.move;

    ZoneCell* cell = entity.get_zone().get_cell(...new_pos);
    if (cell.terrain.passable)
    {
        entity.set_position(new_pos);
    }
}

fn MoveAction* do_move(int[<2>] move)
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
    fn int[<2>] get_position();
    fn void set_position(int[<2>] pos);
    fn char get_glyph();
    fn rl::Color get_color();
    fn double get_idle_time();
    fn void give_idle_time(double time);

    fn Action next_action(double max_time);
}

struct EntityCommon (Entity)
{
    Zone* zone;
    String name;
    int[<2>] position;
    char glyph;
    rl::Color color;

    double idle_time;
}

fn Zone* EntityCommon.get_zone(&self) @dynamic => self.zone;
fn String EntityCommon.get_name(&self) @dynamic => self.name;
fn int[<2>] EntityCommon.get_position(&self) @dynamic => self.position;
fn void EntityCommon.set_position(&self, int[<2>] pos) @dynamic
{
    ZoneCell* cell = self.zone.get_cell(...self.position);
    Entity this_ent;
    foreach (ent: cell.entities)
    {
        if (ent.ptr == self)
        {
            this_ent = ent;
            break;
        }
    }
    cell.entities.remove_first_item(this_ent);
    self.position = pos;
    ZoneCell* new_cell = self.zone.get_cell(...self.position);
    new_cell.entities.push(this_ent);
}

fn char EntityCommon.get_glyph(&self) @dynamic => self.glyph;
fn rl::Color EntityCommon.get_color(&self) @dynamic => self.color;
fn double EntityCommon.get_idle_time(&self) @dynamic => self.idle_time;
fn void EntityCommon.give_idle_time(&self, double time) @dynamic
{
    self.idle_time += time;
}

/*
This would be cool
macro @pass($Type, #func)
{
    fn $typeof(Entity.#func()) $Type.#name(&self) @dynamic => self.entity.#func();
}
*/

fn void EntityCommon.new_init(&self, Zone* z, String n, int[<2>] p, char g, rl::Color c)
{
    self.zone = z;
    self.name = n;
    self.position = p;
    self.glyph = g;
    self.color = c;
}

fn void EntityCommon.free(&self) @dynamic
{
    self.name.free();
}

fn Action EntityCommon.next_action(&self, double max_time) @dynamic
{
    if (max_time <= 0) return null;
    WaitAction* wait = mem::temp_alloc(WaitAction);
    wait.time = max_time - self.idle_time;
    return wait;
}

struct Navigator
{
    List(<int[<2>]>) path;
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

fn void Navigator.path_to(&self, Zone* zone, int[<2>] start, int[<2>] end)
{
    self.path.clear();
    zone.path(start, end, &self.path, diagonal_moves: false, reverse: true);
}

fn int[<2>] Navigator.next_point(&self)
{
    assert(!self.path.is_empty(), "No path to follow");
    return self.path.pop()!!;
}

fn void Navigator.abort(&self)
{
    self.path.clear();
}