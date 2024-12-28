module c3rl;

def LineCallback = fn void(void* data, int[<2>] next);
fn void line(int[<2>] start, int[<2>] end, LineCallback callback, void* data=null)
{
    int x0 = start[0];
    int y0 = start[1];
    int x1 = end[0];
    int y1 = end[1];

    int dx = x1 - x0;
    int dy = y1 - y0;

    int sx = 1;
    int sy = 1;

    if (dx < 0)
    {
        dx = -dx;
        sx = -1;
    }

    if (dy < 0)
    {
        dy = -dy;
        sy = -1;
    }

    int err = dx - dy;

    while (true)
    {
        callback(data, {x0, y0});

        if (x0 == x1 && y0 == y1) break;

        int e2 = 2 * err;

        if (e2 > -dy)
        {
            err -= dy;
            x0 += sx;
        }

        if (e2 < dx)
        {
            err += dx;
            y0 += sy;
        }
    }
}