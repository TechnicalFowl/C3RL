module stealthyspacerl;
import std::io;

import roguelike;
import roguelike::maps;

struct TestGameState (GameState)
{
	ulong current_tick;
	ulong elapsed_time;
}

fn void TestGameState.new_init(&self) @dynamic
{
}

fn void TestGameState.free(&self) @dynamic
{
}

fn Map* TestGameState.getMap(&self) @dynamic
{
	roguelike::MapController ctrl = mem::new(maps::StationController);
	return roguelike::createMap(ctrl);
}

fn void TestGameState.update(&self, Map* map) @dynamic
{
	self.current_tick++;
}

fn int main(String[] args)
{
	roguelike::RLSettings settings;
	settings.width = 80;
	settings.height = 45;
	settings.name = "StealthySpaceRL";
	settings.font = "../assets/cp437_16x16.png";
	settings.hfont = "../assets/cp437_8x16.png";
	settings.font_size = 16;
	TestGameState* test_game_state = mem::new(TestGameState);
	test_game_state.new_init();
	settings.initial_state = test_game_state;

	@pool()
	{
		roguelike::init(settings);
		while (roguelike::update())
		{
			roguelike::render();
		}
	};
	return 0;
}
