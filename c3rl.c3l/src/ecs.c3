module c3rl;

import std::collections::map;

interface Event
{
    
}

interface Component
{
    fn void update(double delta);
}

struct Entity
{
    uint id;
    String name;
    int[<2>] position;
    HashMap(<typeid, Component*>) components;
}

fn void Entity.new_init(&self, uint i, String n, int[<2>] p)
{
    self.id = i;
    self.name = n;
    self.position = p;
    self.components.new_init();
}

fn void Entity.update(&self, double delta)
{
    self.components.@each(; typeid type, Component* comp)
    {
        comp.update(delta);
    };
}

fn void Entity.add(&self, Component* comp)
{
    self.components.set(comp.typeid, comp);
}

interface System
{
    fn void update(double delta);
}

struct Ecs
{
    uint next_entity_id;
    HashMap(<uint, Entity*>) entities;
}

fn void Ecs.new_init(&self)
{
    self.entities.new_init();
}

fn void Ecs.update(&self, double delta)
{
    self.entities.@each(; uint id, Entity* entity)
    {
        entity.update(delta);
    };
}

fn Entity* Ecs.add_entity(&self, String name, int[<2>] position)
{
    uint id = self.next_entity_id++;
    Entity* entity = mem::new(Entity);
    entity.new_init(id, name, position);
    self.entities.set(id, entity);
    return entity;
}