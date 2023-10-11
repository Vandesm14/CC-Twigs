import softlink from "./softlink_api";

/*
Pinging:
1. Send ping message every 15s to all modems
2. Trace prop of the message includes the current computer ID (`[<sender ID>]`)

Receiving BGP Ping:
1. Receive a BGP ping
2. Drop pings based on:
  - If we have seen it already, or if the source (`trace[0]`) is undefined
3. Relay the ping to all modems if:
  - The trace does not include the current computer ID
4. Run through each ID in the trace and update the route only if:
  - The destinatin is not us
  - The via (`trace[-1]`) is not undefined

Receiving an IP message:
1. Drop the message based on:
  - If the trace contains our ID
  - If the trace is less than 2 (`[origin, via]`)
  - If the trace does not end with our ID
2. If the destination is our ID, "take" the message (relay to other programs or something)
3. Else, find a route to the destination
4. Find the shortest route using the routing table
5. If no route can be found, drop the message
6. Else, find the via (next hop) and the modem side to send message
7. Push the via to the trace
8. Find the modem
9. If no modem can be found, drop the message
10. Else, transmit the message

Updating a BGP route:
1. Find the previous route in the table for the destination
2. If there is a previous message, update the route
3. If not, insert one

Pruning Old Routes:
1. Filter routes that exceed the heartbeat interval
*/