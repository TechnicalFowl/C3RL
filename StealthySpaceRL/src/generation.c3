module roguelike;

import std::collections::map;

struct Archetype
{
    char icon;
}

struct MapDescription
{
    int width;
    int height;
    String map_data;

    HashMap(<char, Archetype>) archetype_map;
}