module c3rl;

import std::collections::list;
import std::io;

import raylib5::rl;

import c3rl::gui @public;
import c3rl::internal @public;

Font* root_font;
Font* root_sprite_font;
Font* root_hfont;
bool is_textmode;

bool taking_screenshot = false;
String screenshot_filename;
RLSettings settings;

VirtualTerminal* map_term;
VirtualTerminal* ui_term;

Zone* current_zone;

struct RLSettings
{
    String asset_path; // The asset path for the game's assets
    String default_font_name; // The default font name to use
    int default_font_size; // The default font size to use
    int terminal_width; // The starting width of the screen/terminal, in default_font_size characters
    int terminal_height; // The starting width of the screen/terminal, in default_font_size characters
    String window_title; // The title of the window
    
    ZoneDescription initial_zone; // The initial zone to start the game in
}

fn RLSettings make_settings(
    String asset_path="",
    String default_font_name="cp437",
    int default_font_size=16,
    int terminal_width=80,
    int terminal_height=45,
    String window_title="C3RL Game",
    ZoneDescription initial_zone = {}
)
{
    return {
        asset_path,
        default_font_name,
        default_font_size,
        terminal_width,
        terminal_height,
        window_title,
        initial_zone
    };
}

interface RLGame
{
    fn RLSettings settings();
    fn void update(double time) @optional; // Called after a player action
    fn void render(); // Called every frame, happends after the zone is rendered

    fn Entity get_player();
}

interface ResizeEvent
{
    fn void on_resize(int new_width, int new_height);
}

<*
@param [&in] game
*>
fn void launch(RLGame game)
{
    //internal::waitForDebugger();

    rl::traceLog(rl::TraceLogLevel.INFO, "C3RL: Initializing...");
    
    settings = game.settings();

    rl::initWindow(settings.terminal_width * settings.default_font_size, settings.terminal_height * settings.default_font_size, settings.window_title);
    rl::setTargetFPS(60);
    rl::setExitKey(0);
    rl::setWindowState(rl::FLAG_WINDOW_RESIZABLE);

    set_font_directory(settings.asset_path);

    Font*! font = get_font(settings.default_font_name, {settings.default_font_size, settings.default_font_size});
    if (catch font)
    {
        rl::traceLog(rl::TraceLogLevel.ERROR, "C3RL: Failed to load font %s/%s_%dx%d", settings.asset_path, settings.default_font_name, settings.default_font_size, settings.default_font_size);
        return;
    }
    root_font = font;
    Font*! hfont = get_font(settings.default_font_name, {settings.default_font_size / 2, settings.default_font_size});
    if (catch hfont)
    {
        rl::traceLog(rl::TraceLogLevel.ERROR, "C3RL: Failed to load half-size font %s/%s_%dx%d", settings.asset_path, settings.default_font_name, settings.default_font_size / 2, settings.default_font_size);
        return;
    }
    root_hfont = hfont;
    root_sprite_font = root_font;

    map_term = mem::new(VirtualTerminal);
    map_term.new_init(settings.terminal_width, settings.terminal_height, root_font);
    ui_term = mem::new(VirtualTerminal);
    ui_term.new_init(settings.terminal_width * 2, settings.terminal_height, root_hfont);

    if (settings.initial_zone.width != 0)
    {
        rl::traceLog(rl::TraceLogLevel.INFO, "C3RL: Loading Zone...");
        current_zone = mem::new(Zone);
        current_zone.new_init(settings.initial_zone);
    }

    
    @call_event(PostLoadEvent, on_post_load, game);

    rl::traceLog(rl::TraceLogLevel.INFO, "C3RL: Starting game loop...");

    gui::gui_data.new_init();

    @pool()
    {
        allocator::TempAllocator* temp = allocator::temp();
        while (!rl::windowShouldClose())
        {
            temp.reset(0);
            
            if (rl::isWindowResized())
            {
                int new_width = rl::getScreenWidth();
                int new_height = rl::getScreenHeight();
                @call_event(ResizeEvent, on_resize, map_term, new_width / root_font.width, new_height / root_font.height);
                @call_event(ResizeEvent, on_resize, ui_term, new_width / root_hfont.width, new_height / root_font.height);
                @call_event(ResizeEvent, on_resize, game, new_width, new_height);
            }

            rl::beginDrawing();
            rl::clearBackground(colors::BLACK);
            
            update_inputs();

            map_term.clear(colors::BLACK);
            ui_term.clear(colors::BLACK);

            gui::gui_data.start_frame();

            if (current_zone)
            {
                current_zone.update(game);
                current_zone.render_zone(map_term);
            }

            game.render();
            gui::gui_data.render();

            map_term.render(1, {});
            ui_term.render(1, {});

            rl::endDrawing();

            if (taking_screenshot)
            {
                rl::takeScreenshot(screenshot_filename.zstr_tcopy());
                taking_screenshot = false;
            }
        }
    };
    
    rl::traceLog(rl::TraceLogLevel.INFO, "C3RL: Shutting down...");
}

fn void request_screenshot(String filename)
{
    taking_screenshot = true;
    screenshot_filename = filename;
}
