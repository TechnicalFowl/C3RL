module c3rl::internal @private;

fn void waitForDebugger()
{
    int wait_for_debugger = 1;
    while (@volatile_load(wait_for_debugger))
    {
        // Wait for the debugger to attach
    }
}
