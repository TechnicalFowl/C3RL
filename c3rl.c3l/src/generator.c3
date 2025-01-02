module c3rl;

import std::io;
import std::math::random;

struct CellularAutomata
{
    int iterations;
    float initial_fill;

    int r1_cuttoff;
    int r2_cuttoff;
}

fn void CellularAutomata.new_init(&self, int iterations=5, float initial_fill=0.45, int r1=5, int r2=2)
{
    self.iterations = iterations;
    self.initial_fill = initial_fill;
    self.r1_cuttoff = r1;
    self.r2_cuttoff = r2;
}

fn void CellularAutomata.apply(&self, BitBoard* in, BitBoard* out, int r1, int r2)
{
    usz w = in.width;
    usz h = in.height;

    io::printfn("Applying CA with r1=%d, r2=%d", r1, r2);

    for (int y = 1; y < h - 1; ++y)
    {
        for (int x = 1; x < w - 1; ++x)
        {
            int r1_count = 0;

            for SEARCH: (int dy = -1; dy <= 1; ++dy)
            {
                for (int dx = -1; dx <= 1; ++dx)
                {
                    if (in.get({x + dx, y + dy}))
                    {
                        if (++r1_count >= r1) break SEARCH;
                    }
                }
            }

            if (r1_count >= r1)
            {
                out.set({x, y}, true);
                continue;
            }

            if R2_SEARCH: (r2 < 25 && r1_count < r2 && x > 1 && x < w - 2 && y > 1 && y < h - 2)
            {
                int r2_count = r1_count;

                for (int dx = -2; dx <= 2; ++dx)
                {
                    int nx = x + dx;
                    if (in.get({nx, y - 2}))
                    {
                        if (++r2_count > r2) break R2_SEARCH;
                    }
                    if (in.get({nx, y + 2}))
                    {
                        if (++r2_count > r2) break R2_SEARCH;
                    }
                }

                for (int dy = -1; dy <= 1; ++dy)
                {
                    int ny = y + dy;
                    if (in.get({x - 2, ny}))
                    {
                        if (++r2_count > r2) break R2_SEARCH;
                    }
                    if (in.get({x + 2, ny}))
                    {
                        if (++r2_count > r2) break R2_SEARCH;
                    }
                }

                if (r2_count <= r2)
                {
                    out.set({x, y}, true);
                    continue;
                }
            }
            
            out.set({x, y}, false);
        }
    }
}

fn BitBoard CellularAutomata.get_shape(&self, Zone* zone, Random rng)
{
    int w = zone.width;
    int h = zone.height;

    BitBoard board1;
    board1.new_init(w, h);
    BitBoard board2;
    board2.new_init(w, h);
    defer board2.free();

    for (int y = 0; y < h; ++y)
    {
        for (int x = 0; x < w; ++x)
        {
            if (x == 0 || x == w - 1 || y == 0 || y == h - 1)
            {
                board1.set({x, y}, true);
            }
            else
            {
                board1.set({x, y}, random::next_float(rng) < self.initial_fill);
            }
        }
    }

    for (int i = 0; i < self.iterations; ++i)
    {
        self.apply(&board1, &board2, self.r1_cuttoff, i < self.iterations - 1 ? self.r2_cuttoff : 25);
        @swap(board1, board2);
    }

    return board1;
}

fn void CellularAutomata.generate(&self, Zone* zone, Random rng)
{
    BitBoard board = self.get_shape(zone, rng);
    defer board.free();

    for (int y = 0; y < zone.height; ++y)
    {
        for (int x = 0; x < zone.width; ++x)
        {
            if (x == 0 || x == zone.width - 1 || y == 0 || y == zone.height -1 || board.get({x, y}))
            {
                zone.set_terrain(x, y, '#', colors::DARK_GREY.randomize(rng, 0.1), colors::BLACK, false);
            }
            else
            {
                zone.set_terrain(x, y, '.', colors::DARKEST_GREY.randomize(rng, 0.2), colors::BLACK, true);
            }
        }
    }
}