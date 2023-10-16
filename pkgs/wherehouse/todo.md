# Wherehouse

## Process

### Listing

1. Server receives a request to get a list of all items in the store
2. The server runs through each chest, saving the contents in memory
3. It sends a packet back to the server with the count of all items in the store

### Ordering

1. Server receives a request with a table of items, key being the item ID and value being how many
2. Server goes through each chest, trying to fulfill the order
3. It keeps a list of items that it already has, in order to know how many it has left to collect
4. It reports how much it fulfilled the order to the server (if the order was fully fulfilled, it would return the same order table)
5. It dumps the items into the a dedicated output chest, which flow into a hopper and minecart