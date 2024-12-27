module roguelike::maps;

import roguelike;

struct StationController (MapController)
{
    AlertTracker alert_tracker;
}

fn void StationController.new_init(&self) @dynamic
{
}

fn void StationController.free(&self) @dynamic
{
}

fn MapDescription StationController.getDescription(&self) @dynamic
{
    MapDescription desc;
    desc.width = 100;
    desc.height = 100;
    desc.map_data = $embed("station.txt");

    desc.archetype_map.new_init();
    desc.archetype_map.set('+', Archetype{' '});

    return desc;
}

fn void StationController.update(&self, Map* map, int time) @dynamic
{

}