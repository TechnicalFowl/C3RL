module c3rl;

import std::math;

def IVec2 = int[<2>];

fn IVec2 ivec2_sign(IVec2 v)
{
    return { math::sign(v[0]), math::sign(v[1]) };
}

fn int ivec2_distance(IVec2 a, IVec2 b)
{
    return math::abs(a[0] - b[0]) + math::abs(a[1] - b[1]);
}

module c3rl::internal @private;

fn void waitForDebugger()
{
    int wait_for_debugger = 1;
    while (@volatile_load(wait_for_debugger))
    {
        // Wait for the debugger to attach
    }
}
