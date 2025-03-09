module c3rl;

import std::collections::list;
import raylib5::rl;

struct LogMessage
{
    String message;
    rl::Color color;
}
List(<LogMessage>) log_messages;

fn void log(String message, rl::Color color = colors::WHITE)
{
    log_messages.push({message, color});
}
