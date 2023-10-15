# Wherehouse

## Process

### Listing

1. Turtle receives a request to get a list of all items in the store
2. The turtle runs through each chest, saving the contents in memory
3. It returns home
4. It sends a large packet back to the server regarding the items in the store

### Ordering

1. Turtle receives a request with a table of items, key being the item ID and value being how many
2. Turtle goes through each chest, trying to fulfill the order
3. It keeps a list of items that it already has, in order to know how many it has left to collect
4. Once it hits the end of the store row, it returns home
5. It reports how much it fulfilled the order to the server
6. It dumps the items into the chest below, which flow into a hopper and minecart

### External

1. Listing and ordering are events that are sent to the server