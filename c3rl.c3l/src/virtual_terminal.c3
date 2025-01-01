module c3rl;

import std::collections::list;
import std::collections::map;
import std::io;
import std::math;

import raylib5::rl;

struct VCell
{
    char[<2>] glyph;
    rl::Color fg;
    int fg_priority;
    rl::Color bg;
    int bg_priority;
}

struct VirtualTerminal
{
    uint width;
    uint height;

    VCell* buffer;

    Font* font;
    Font* hfont;
}
VirtualTerminal* terminal;

<*
@require w > 0, h > 0, "Width and height must be greater than zero"
*>
fn void VirtualTerminal.new_init(&self, int w, int h)
{
    self.width = w;
    self.height = h;
    self.buffer = mem::new_array(VCell, (usz) w * h);

    self.font = root_font;
    self.hfont = root_hfont;

    self.clear();
}

fn void VirtualTerminal.free(&self)
{
    mem::free(self.buffer);
}

<*
@require new_width > 0, new_height > 0, "Width and height must be greater than zero"
*>
fn void VirtualTerminal.on_resize(&self, int new_width, int new_height) @dynamic
{
    int new_term_width = new_width / self.font.width;
    int new_term_height = new_height / self.font.height;
    mem::free(self.buffer);
    self.buffer = mem::new_array(VCell, (usz) new_term_width * new_term_height);
    self.width = new_term_width;
    self.height = new_term_height;
}

fn void VirtualTerminal.clear(&self, rl::Color bg=colors::BLACK)
{
    self.clear_to({ { ' ', 0 }, colors::BLACK, 0, bg, 0 });
}

fn void VirtualTerminal.clear_to(&self, VCell glyph)
{
    for (int i = 0; i < self.width * self.height; i++)
    {
        self.buffer[i] = glyph;
    }
}

<*
@require x >= 0 && x < self.width
@require y >= 0 && y < self.height
*>
fn void VirtualTerminal.set_background(&self, int x, int y, rl::Color bg, int priority=0)
{
    VCell* cell = &self.buffer[self.width * y + x];
    if (priority >= cell.bg_priority)
    {
        cell.bg = bg;
        cell.bg_priority = priority;
    }
}

<*
@require x0 >= 0 && x0 + w < self.width
@require y0 >= 0 && y0 + h < self.height
@require w > 0
@require h > 0
*>
fn void VirtualTerminal.fill_background(&self, int x0, int y0, int w, int h, rl::Color bg, int priority=0)
{
    for (int y = y0; y < y0 + h; y++)
    {
        for (int x = x0; x < x0 + w; x++)
        {
            VCell* cell = &self.buffer[self.width * y + x];
            if (priority >= cell.bg_priority)
            {
                cell.bg = bg;
                cell.bg_priority = priority;
            }
        }
    }
}

<*
@require x >= 0 && x < self.width
@require y >= 0 && y < self.height
*>
fn void VirtualTerminal.set_tile(&self, int x, int y, char glyph, rl::Color fg=colors::WHITE, int priority=0)
{
    VCell* cell = &self.buffer[self.width * y + x];
    if (priority >= cell.fg_priority)
    {
        cell.glyph = { glyph, 0 };
        cell.fg = fg;
        cell.fg_priority = priority;
    }
}

<*
@require x0 >= 0 && x0 + w < self.width
@require y0 >= 0 && y0 + h < self.height
@require w > 0
@require h > 0
*>
fn void VirtualTerminal.fill_tile(&self, int x0, int y0, int w, int h, char glyph, rl::Color fg=colors::WHITE, int priority=0)
{
    for (int y = y0; y < y0 + h; y++)
    {
        for (int x = x0; x < x0 + w; x++)
        {
            VCell* cell = &self.buffer[self.width * y + x];
            if (priority >= cell.fg_priority)
            {
                cell.glyph = { glyph, 0 };
                cell.fg = fg;
                cell.fg_priority = priority;
            }
        }
    }
}

<*
@require x0 >= 0 && x0 + w < self.width
@require y0 >= 0 && y0 + h < self.height
@require w > 0
@require h > 0
*>
fn void VirtualTerminal.box_tile(&self, int x0, int y0, int w, int h, bool double_lines=false, rl::Color fg=colors::WHITE, int priority=0)
{
    int x_min = math::max(0, x0);
    int y_min = math::max(0, y0);
    int x_max = math::min(self.width - 1, x0 + w - 1);
    int y_max = math::min(self.height - 1, y0 + h - 1);

    for (int x = x_min + 1; x < x_max; x++)
    {
        if (!double_lines)
        {
            self.set_tile(x, y_min, 196, fg, priority);
            self.set_tile(x, y_max, 196, fg, priority);
        }
        else
        {
            self.set_tile(x, y_min, 205, fg, priority);
            self.set_tile(x, y_max, 205, fg, priority);
        }
    }

    for (int y = y_min + 1; y < y_max; y++)
    {
        if (!double_lines)
        {
            self.set_tile(x_min, y, 179, fg, priority);
            self.set_tile(x_max, y, 179, fg, priority);
        }
        else
        {
            self.set_tile(x_min, y, 186, fg, priority);
            self.set_tile(x_max, y, 186, fg, priority);
        }
    }

    if (!double_lines)
    {
        self.set_tile(x_min, y_min, 218, fg, priority);
        self.set_tile(x_max, y_min, 191, fg, priority);
        self.set_tile(x_min, y_max, 192, fg, priority);
        self.set_tile(x_max, y_max, 217, fg, priority);
    }
    else
    {
        self.set_tile(x_min, y_min, 201, fg, priority);
        self.set_tile(x_max, y_min, 187, fg, priority);
        self.set_tile(x_min, y_max, 200, fg, priority);
        self.set_tile(x_max, y_max, 188, fg, priority);
    }
}

<*
@require x >= 0 && x < self.width * 2
@require y >= 0 && y < self.height
*>
fn void VirtualTerminal.set_text(&self, int x, int y, char glyph, rl::Color fg=colors::WHITE, int priority=0)
{
    VCell* cell = &self.buffer[self.width * y + (x / 2)];
    if (priority >= cell.fg_priority)
    {
        if (x % 2 == 0)
        {
            cell.glyph[0] = glyph;
            if (cell.glyph[1] == 0) cell.glyph[1] = ' '; // Set the other half of the character if it was a full-size character
        }
        else
        {
            if (cell.glyph[1] == 0) cell.glyph[0] = ' '; // Clear out the other half of the character if it was a full-size character
            cell.glyph[1] = glyph;
        }
        cell.fg = fg;
        cell.fg_priority = priority;
    }
}

<*
@require x0 >= 0 && x0 + w < self.width * 2
@require y0 >= 0 && y0 + h < self.height
@require w > 0
@require h > 0
*>
fn void VirtualTerminal.fill_text(&self, int x0, int y0, int w, int h, char glyph, rl::Color fg=colors::WHITE, int priority=0)
{
    int x_min = math::max(0, x0);
    int y_min = math::max(0, y0);
    int x_max = math::min(self.width * 2 - 1, x0 + w - 1);
    int y_max = math::min(self.height - 1, y0 + h - 1);
    
    int x_max_full = x_max % 2 == 0 ? x_max : x_max - 1;

    for (int y = y_min; y <= y_max; y++)
    {
        int x = x_min;
        if (x % 2 == 1)
        {
            VCell* cell = &self.buffer[self.width * y + (x / 2)];
            if (priority >= cell.fg_priority)
            {
                cell.glyph = {' ', glyph };
                cell.fg = fg;
                cell.fg_priority = priority;
            }
            ++x;
        }

        for (; x <= x_max_full; x += 2)
        {
            VCell* cell = &self.buffer[self.width * y + (x / 2)];
            if (priority >= cell.fg_priority)
            {
                cell.glyph = { glyph, glyph };
                cell.fg = fg;
                cell.fg_priority = priority;
            }
        }

        if (x_max_full != x_max)
        {
            VCell* cell = &self.buffer[self.width * y + (x_max / 2)];
            if (priority >= cell.fg_priority)
            {
                cell.glyph[0] = glyph;
                cell.fg = fg;
                cell.fg_priority = priority;
            }
        }
    }
}

<*
@require x0 >= 0 && x0 + w < self.width * 2
@require y0 >= 0 && y0 + h < self.height
@require w > 0
@require h > 0
*>
fn void VirtualTerminal.box_text(&self, int x0, int y0, int w, int h, bool double_lines=false, rl::Color fg=colors::WHITE, int priority=0)
{
    int x_min = math::max(0, x0);
    int y_min = math::max(0, y0);
    int x_max = math::min(self.width - 1, x0 + w - 1);
    int y_max = math::min(self.height - 1, y0 + h - 1);

    for (int x = x_min + 1; x < x_max; x++)
    {
        if (!double_lines)
        {
            self.set_text(x, y_min, 196, fg, priority);
            self.set_text(x, y_max, 196, fg, priority);
        }
        else
        {
            self.set_text(x, y_min, 205, fg, priority);
            self.set_text(x, y_max, 205, fg, priority);
        }
    }

    for (int y = y_min + 1; y < y_max; y++)
    {
        if (!double_lines)
        {
            self.set_text(x_min, y, 179, fg, priority);
            self.set_text(x_max, y, 179, fg, priority);
        }
        else
        {
            self.set_text(x_min, y, 186, fg, priority);
            self.set_text(x_max, y, 186, fg, priority);
        }
    }

    if (!double_lines)
    {
        self.set_text(x_min, y_min, 218, fg, priority);
        self.set_text(x_max, y_min, 191, fg, priority);
        self.set_text(x_min, y_max, 192, fg, priority);
        self.set_text(x_max, y_max, 217, fg, priority);
    }
    else
    {
        self.set_text(x_min, y_min, 201, fg, priority);
        self.set_text(x_max, y_min, 187, fg, priority);
        self.set_text(x_min, y_max, 200, fg, priority);
        self.set_text(x_max, y_max, 188, fg, priority);
    }
}

<*
@require x >= 0 && x < self.width * 2
@require y >= 0 && y < self.height
*>
fn void VirtualTerminal.write(&self, int x, int y, String text, rl::Color fg=colors::WHITE, int priority=0)
{
    foreach (c: text)
    {
        self.set_text(x++, y, c, fg, priority);
    }
}

fn void VirtualTerminal.drawTile(&self, int x, int y, char c, rl::Color col) @private
{
    rl::Rectangle src = {
        (float) (c % 16) * self.font.width, (float) (c / 16) * self.font.height,
        self.font.width, self.font.height
    };
    rl::Rectangle dest = {
        (float) x * self.font.width, (float) y * self.font.height,
        self.font.width, self.font.height
    };

    rl::drawTexturePro(self.font.texture, src, dest, { 0, 0 }, 0, col);
}

fn void VirtualTerminal.drawText(&self, int x, int y, char c, rl::Color col) @private
{
    rl::Rectangle src = { 
        (float) (c % 16) * self.hfont.width, (float) (c / 16) * self.hfont.height,
        self.hfont.width, self.hfont.height
    };
    rl::Rectangle dest = {
        (float) x * self.hfont.width, (float) y * self.hfont.height,
        self.hfont.width, self.hfont.height
    };

    rl::drawTexturePro(self.hfont.texture, src, dest, { 0, 0 }, 0, col);
}

fn void VirtualTerminal.render(&self)
{
    for (int y = 0; y < self.height; y++)
    {
        for (int x = 0; x < self.width; x++)
        {
            VCell* cell = &self.buffer[self.width * y + x];
            rl::drawRectangle(x * self.font.width, y * self.font.height, self.font.width, self.font.height, cell.bg);
            if (cell.glyph[0] != 0 && cell.glyph[1] == 0)
            {
                self.drawTile(x, y, cell.glyph[0], cell.fg);
            }
            else
            {
                if (cell.glyph[0] != 0)
                {
                    self.drawText(x * 2, y, cell.glyph[0], cell.fg);
                }
                if (cell.glyph[1] != 0)
                {
                    self.drawText(x * 2 + 1, y, cell.glyph[1], cell.fg);
                }
            }
        }
    }
}