# BGP

This is an simplified implementation of BGP. It allows wired and wireless computers ("nodes") to connect to each other and exchange information about their network.

## Installation

```sh
mngr install bgp
```

## Usage

```sh
mngr run bgp

# or

bgp
```

## Protocol

Each BGP node will send a propagation message to all nodes after the configured timeout. The propatation message contains only a trace, which is a list of node IDs (computer IDs). As the message propagates through the network, each node learns how to reach other nodes.
