# Searchnet

A protocol to find routes to a destination

## Method

1. All computers run a searchnet daemon to respond to pings
2. Computer `A` sends a ping to find Computer `C`
    1. It also adds Computer `C`'s ID to a "waiting" set
        1. This allows it to keep track of which pings it is waiting to hear back from
3. Computer `B` receives the ping and, because it is not destined for `B`, relays the packet to it's connected modems
    1. Before relaying, it adds it's ID to the trace: `[A, B]`
    2. Do not re-transmit the packet via the side it was received on
4. Computer `C` receives the ping and, because it is destined for it, sends a [follownet](TODO: add link) packet directly back to `A`
5. Computer `A` receives the packet and saves the route either in-memory or on disk. Now, whenever an application needs to connect to Computer `C`, it uses [follownet](TODO: link) and the route path.
    1. Computer `C`'s ID is removed from the "waiting" set
    2. If `A` had received multiple responses back, it would ignore them if their origin does not exist in the "waiting" set