# BGP

1. [ ] Get a list of IDs of the connected nodes
2. [ ] Broadcast the list to all the nodes
3. [ ] If a node receives a list, it should update the list of connected nodes for the origin
4. [ ] It will then relay the list to all the nodes it is connected to
5. [ ] If a node receives a message where the `origin` is the same as the node's `id`, it will ignore the message
