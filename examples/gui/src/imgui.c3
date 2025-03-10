module c3rl::ig;

import std::collections::list;
import std::collections::map;
import c3rl;
import raylib5::rl;

struct ImGuiIO
{
    c3rl::Font* font;
}

struct DrawAction
{
    int type;
    IVec2 pos;
    IVec2 size;
    rl::Color color;
    char glyph;
}

struct ImGuiDrawList
{
    List(<DrawAction>) actions;
}

fn void ImGuiDrawList.new_init(&self)
{
    self.actions.new_init();
}

struct GuiWindow
{
    uint id;
    String title;

    IVec2 pos;
    IVec2 cursor;
}

struct ImGuiContext
{
    ImGuiIO io;
    ImGuiStorage storage;
    ImGuiDrawList draw_list;

    HashMap(<uint, GuiWindow*>) windows;
    List(<GuiWindow*>) windows_order;

    List(<GuiWindow*>) windows_stack;
}
ImGuiContext* g_context;

fn void init()
{
    g_context = mem::new(ImGuiContext);
    g_context.storage.new_init();
    g_context.io.font = c3rl::root_hfont;
}

fn void newFrame()
{
    g_context.draw_liest.actions.clear();
}

fn void endFrame()
{

}

fn void render(c3rl::VirtualTerminal* terminal)
{

}

fn bool begin(String title)
{
    GuiWindow* window = findWindow(title);
    bool new_window = window == null;
    if (new_window)
    {
        window = mem::new(GuiWindow);
        window.id = hash_string(title, 0);
        window.title = title;
        g_context.windows.put(window.id, window);
        g_context.windows_order.push(window);
        window.initOrLoadSettings();
    }
}

module c3rl::ig @private;
import c3rl;
import raylib5::rl;

fn GuiWindow* findWindow(String title)
{
    uint hash = hash_string(title, 0);
    return findWindowById(hash);
}

fn GuiWindow* findWindowById(uint id)
{
    return g_context.windows.get(id) ?? null;
}

fn void GuiWindow.initOrLoadSettings(&self)
{
    self.pos = {6, 6};
}