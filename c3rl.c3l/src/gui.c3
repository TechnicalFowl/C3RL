module c3rl::gui;

import std::collections::list;
import std::collections::map;

import raylib5::rl;

import c3rl::colors;

enum GuiSetting
{
    PRIORITY,
}
fn uint GuiSetting.hash(self) => self.ordinal;

enum GuiColor
{
    TOP_BAR_BG,
    TOP_BAR_TEXT,
    BOTTOM_BAR_BG,
    BOTTOM_BAR_TEXT,
    WINDOW_BG,
    WINDOW_TEXT,
    WINDOW_BORDER,
}
fn uint GuiColor.hash(self) => self.ordinal;

fn void set_setting(GuiSetting setting, int value)
{
    gui_data.settings.set(setting, value);
}

fn int get_setting(GuiSetting setting)
{
    if (try int value = gui_data.settings.get(setting))
    {
        return value;
    }
    return 0;
}

fn void push_setting(GuiSetting setting, int value)
{
    gui_data.setting_stack.push({ setting, get_setting(setting) });
    set_setting(setting, value);
}

fn void pop_setting(int count=1)
{
    while (count-- > 0)
    {
        if (gui_data.setting_stack.is_empty()) break;
        GuiSettingStore store = gui_data.setting_stack.pop()!!;
        set_setting(store.setting, store.value);
    }
}

fn void set_color(GuiColor color, rl::Color value)
{
    gui_data.colors.set(color, value);
}

fn rl::Color get_color(GuiColor color)
{
    if (try rl::Color value = gui_data.colors.get(color))
    {
        return value;
    }
    return colors::MAGENTA;
}

fn void push_color(GuiColor color, rl::Color value)
{
    gui_data.color_stack.push({ color, get_color(color) });
    set_color(color, value);
}

fn void pop_color(int count=1)
{
    while (count-- > 0)
    {
        if (gui_data.color_stack.is_empty()) break;
        GuiColorStore store = gui_data.color_stack.pop()!!;
        set_color(store.setting, store.color);
    }
}

fn void push_topbar(String text)
{
    if (gui_data.topbar.len == 0)
    {
        gui_data.topbar = text.tcopy();
    }
    else
    {
        gui_data.topbar = string::join_new({gui_data.topbar, text}, " ", allocator::temp());
    }
}

fn void push_bottombar(String text)
{
    if (gui_data.statusbar.len == 0)
    {
        gui_data.statusbar = text.tcopy();
    }
    else
    {
        gui_data.statusbar = string::join_new({gui_data.statusbar, text}, " ", allocator::temp());
    }
}

fn void begin_window(String title, IVec2 pos, IVec2 size, bool border=true)
{
    GuiWindow* window;
    if (try GuiWindow* w = gui_data.windows.get(title))
    {
        window = w;
    }
    else
    {
        window = mem::new(GuiWindow);
        gui_data.windows.set(title, window);
    }
    window.title = title;
    window.pos = pos;
    window.size = size;
    window.border = border;
    window.last_frame = gui_data.frame_index;
    window.cursor = {pos[0] * 2, pos[1] };
    window.last_end = window.cursor;
    window.newline_start = window.cursor[0];

    int prio = get_setting(GuiSetting.PRIORITY);
    c3rl::terminal.fill_background(...pos, ...size, get_color(GuiColor.WINDOW_BG), prio);
    if (border)
    {
        c3rl::terminal.box_text(pos[0] * 2, pos[1], size[0] * 2, size[1], double_lines: false, fg: get_color(GuiColor.WINDOW_BORDER), priority: prio);
        c3rl::terminal.fill_text(pos[0] * 2 + 5, pos[1], (int) title.len + 2, 1, ' ', colors::WHITE, prio);
        c3rl::terminal.set_text(pos[0] * 2 + 4, pos[1], 180, get_color(GuiColor.WINDOW_BORDER), prio);
        c3rl::terminal.write(pos[0] * 2 + 6, pos[1], title, get_color(GuiColor.WINDOW_BORDER), prio);
        c3rl::terminal.set_text(pos[0] * 2 + 7 + (int) title.len, pos[1], 195, get_color(GuiColor.WINDOW_BORDER), prio);
        window.cursor = window.cursor + {1, 1};
        window.newline_start++;
    }

    gui_data.window_stack.push(window);
}

fn void same_line(int x = 1)
{
    if (gui_data.window_stack.is_empty()) unreachable("No window to write to");
    GuiWindow* window = gui_data.window_stack.last()!!;
    window.cursor = window.last_end + {x, 0};
}

fn void text(String text, rl::Color color=colors::BLANK)
{
    if (color == colors::BLANK) color = get_color(GuiColor.WINDOW_TEXT);
    if (gui_data.window_stack.is_empty()) unreachable("No window to write to");
    GuiWindow* window = gui_data.window_stack.last()!!;
    IVec2 clip_size = window.get_text_clip_size();
    if (clip_size[0] <= 0 || clip_size[1] <= 0) return;
    int prio = get_setting(GuiSetting.PRIORITY);
    String clip_text = text.len > clip_size[0] ? text[..clip_size[0]] : text;
    c3rl::terminal.write(...window.cursor, clip_text, color, prio);
    window.last_end = window.cursor + {clip_text.len, 0};
    window.cursor = { window.newline_start, window.cursor[1] + 1 };
}

fn void end_window()
{
    if (catch gui_data.window_stack.pop()) unreachable("No window to end");
}

fn bool is_in_window(IVec2 pos)
{
    gui_data.windows.@each(; String key, GuiWindow* window)
    {
        if (window.last_frame >= gui_data.frame_index - 1 &&
            pos[0] >= window.pos[0] && pos[0] < window.pos[0] + window.size[0] && pos[1] >= window.pos[1] && pos[1] < window.pos[1] + window.size[1])
        {
            return true;
        }
    };
    return false;
}

module c3rl::gui @private;

import std::collections::list;
import std::collections::map;

import raylib5::rl;

import c3rl::colors;

struct GuiWindow
{
    String title;
    IVec2 pos;
    IVec2 size;
    bool border;

    ulong last_frame;

    IVec2 cursor;
    IVec2 last_end;
    int newline_start;
}

fn IVec2 GuiWindow.get_clip_size(&self)
{
    return {
        self.size[0] - (self.cursor[0] / 2 - self.pos[0]),
        self.size[1] - (self.cursor[1] - self.pos[1]),
    };
}

fn IVec2 GuiWindow.get_text_clip_size(&self)
{
    return {
        self.size[0] * 2 - (self.border ? 1 : 0) - (self.cursor[0] - self.pos[0] * 2),
        self.size[1] - (self.cursor[1] - self.pos[1]),
    };
}

struct GuiSettingStore
{
    GuiSetting setting;
    int value;
}

struct GuiColorStore
{
    GuiColor setting;
    rl::Color color;
}

struct GuiData
{
    ulong frame_index;
    List(<GuiWindow*>) window_stack;
    HashMap(<String, GuiWindow*>) windows;

    String topbar;
    String statusbar;

    HashMap(<GuiColor, rl::Color>) colors;
    List(<GuiColorStore>) color_stack;
    HashMap(<GuiSetting, int>) settings;
    List(<GuiSettingStore>) setting_stack;
}
GuiData gui_data;

fn void GuiData.new_init(&self)
{
    gui_data.window_stack.new_init();
    gui_data.windows.new_init();

    gui_data.colors.new_init();
    gui_data.color_stack.new_init();
    gui_data.settings.new_init();
    gui_data.setting_stack.new_init();

    set_setting(GuiSetting.PRIORITY, 10);

    set_color(GuiColor.TOP_BAR_BG, colors::DARKEST_GREY);
    set_color(GuiColor.TOP_BAR_TEXT, colors::WHITE);
    set_color(GuiColor.BOTTOM_BAR_BG, colors::DARKEST_GREY);
    set_color(GuiColor.BOTTOM_BAR_TEXT, colors::WHITE);
    set_color(GuiColor.WINDOW_BG, colors::DARKEST_GREY);
    set_color(GuiColor.WINDOW_TEXT, colors::WHITE);
    set_color(GuiColor.WINDOW_BORDER, colors::GREY);
}

fn void GuiData.start_frame(&self)
{
    self.frame_index++;
    self.topbar = "";
    self.statusbar = "";
}

fn void GuiData.render(&self)
{
    int prio = get_setting(GuiSetting.PRIORITY);
    int term_width = c3rl::terminal.width;
    int term_height = c3rl::terminal.height;

    if (self.topbar.len != 0)
    {
        c3rl::terminal.fill_background(0, 0, term_width, 1, get_color(GuiColor.TOP_BAR_BG), prio);
        c3rl::terminal.write(1, 0, self.topbar, get_color(GuiColor.TOP_BAR_TEXT), prio);
    }
    if (self.statusbar.len != 0)
    {
        c3rl::terminal.fill_background(0, term_height - 1, term_width, 1, get_color(GuiColor.BOTTOM_BAR_BG), prio);
        c3rl::terminal.write(1, term_height - 1, self.statusbar, get_color(GuiColor.BOTTOM_BAR_TEXT), prio);
    }
}