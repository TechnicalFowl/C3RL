module stealthyspacerl;
import std::io;

import roguelike;

struct TestGameState (GameState)
{
	ulong current_tick;
	ulong elapsed_time;
}

fn Map* TestGameState.getMap(&self) @dynamic
{
	Map* map = mem::new(Map);
	map.new_init(100, 100);

	Player* player = mem::new(Player);
	player.new_init({25, 25});
	map.player = player;
	return map;
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
	settings.font = "resources/cp437_16x16.png";
	settings.hfont = "resources/cp437_8x16.png";
	settings.font_size = 16;
	TestGameState* test_game_state = mem::new(TestGameState);
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
