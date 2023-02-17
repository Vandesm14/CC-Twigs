# BGP

## Database

```ts
//                     c_<id>, dest
type Database = Record<string, number>;

// Note: we are using c_<id> because Lua indexes the tables strangely, so using just numbers will result in weird behavior
```

## Propagation

1. [ ] Broadcast a BGP `propagation` message to all peers.
   1. [ ] The message contains the `id` of the original node as `origin`, the `from` of the recent handler, and a `neighbors` list containing the `id` of all neighbors of the origin.
2. [ ] When the message is received by a peer, it propagates the message and handles it
3. [ ] Process the message
   1. [ ] Update the destinations of the `from` neighbor to include the `neighbors` as destinations (append to the list)

## Sending & Routing

1. [ ] Prepare a BGP message with the `to`, `from`, and `origin` fields
2. [ ] Look up the destination of the `to` neighbor in the database
3. [ ] Find the next hop to the destination
4. [ ] Send the message to the next hop
