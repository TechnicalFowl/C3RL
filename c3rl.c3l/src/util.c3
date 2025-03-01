module c3rl;

import std::math;

def IVec2 = int[<2>]; 

fn uint IVec2.hash(self) => ((uint) self[0]) * 2654435761u + ((uint) self[1]);

fn IVec2 ivec2_sign(IVec2 v)
{
    return { math::sign(v[0]), math::sign(v[1]) };
}

fn int ivec2_distance(IVec2 a, IVec2 b)
{
    return math::abs(a[0] - b[0]) + math::abs(a[1] - b[1]);
}

struct BitBoard
{
    usz width;
    usz height;
    ulong* data;
}

<*
@require w > 0, "Width must be greater than zero"
@require h > 0, "Height must be greater than zero"
*>
fn void BitBoard.new_init(&self, usz w, usz h)
{
    self.width = w;
    self.height = h;
    self.data = mem::new_array(ulong, ((w * h) - 1) / 64 + 1);
}

fn void BitBoard.free(&self)
{
    mem::free(self.data);
}

fn void BitBoard.clear(&self)
{
    mem::set(self.data, 0, (((self.width * self.height) - 1) / 64 + 1) * 8);
}

<*
@require w > 0, "Width must be greater than zero"
@require h > 0, "Height must be greater than zero"
*>
fn void BitBoard.resize(&self, usz w, usz h)
{
    mem::free(self.data);
    self.width = w;
    self.height = h;
    self.data = mem::new_array(ulong, ((w * h) - 1) / 64 + 1);
}

<*
@require pos[0] >= 0, pos[0] < self.width, "Invalid position x"
@require pos[1] >= 0, pos[1] < self.height, "Invalid position y"
*>
fn bool BitBoard.get(&self, IVec2 pos)
{
    usz idx = pos[1] * self.width + pos[0];
    usz index = idx / 64;
    usz bit = idx % 64;
    return (self.data[index] & (1ul << bit)) != 0;
}

<*
@require pos[0] >= 0, pos[0] < self.width, "Invalid position x"
@require pos[1] >= 0, pos[1] < self.height, "Invalid position y"
*>
fn void BitBoard.set(&self, IVec2 pos, bool value)
{
    usz idx = pos[1] * self.width + pos[0];
    usz index = idx / 64;
    usz bit = idx % 64;
    if (value)
    {
        self.data[index] |= 1ul << bit;
    }
    else
    {
        self.data[index] &= ~(1ul << bit);
    }
}

module c3rl::internal @private;

extern fn bool isDebuggerPresent() @extern("IsDebuggerPresent") @if(env::WIN32);

fn void waitForDebugger()
{
$if env::WIN32:
    while (!isDebuggerPresent())
    {
        // Wait for the debugger to attach
    }
$else
    int wait_for_debugger = 1;
    while (@volatile_load(wait_for_debugger))
    {
        // Wait for the debugger to attach
    }
$endif
}
