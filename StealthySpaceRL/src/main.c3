module stealthyspacerl;
import std::io;

import roguelike;

fn int main(String[] args)
{
	roguelike::RLSettings settings;
	settings.width = 80;
	settings.height = 45;
	settings.name = "StealthySpaceRL";
	settings.font = "resources/cp437_16x16.png";
	settings.hfont = "resources/cp437_8x16.png";
	settings.font_size = 16;

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
