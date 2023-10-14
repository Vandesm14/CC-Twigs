# Net

This package contains all of the code related to networking.

## Daemons

[`daemons.lua`] handles running the network protocol daemons in the correct
manner. It is the recommended way to do so, and should be used as a reference
implementation otherwise. Be sure to run this, most likely as a background
process, on the majority of computers, such that it can form a proper network.

## Broadlink

Broadlink ([`broadlink.lua`]) is a data layer (OSI layer 2) protocol for
unreliable broadcast of data frames between hosts connected to a modem. It
provides `transmit` and `receive` functions for use by external code to handle
the transfer of data frames.

Here is the library in use:
```lua
local broadlink = require("net.broadlink")

-- Modem side, data table.
broadlink.transmit("top", { "Hello, World!" })
local source, data = broadlink.receive()
```

Bare in mind, these functions will do nothing unless its daemon is running at
the same time.


## Unilink

Unilink ([`unilink.lua`]) is a data layer (OSI layer 2) protocol for
unreliable broadcast of data frames between hosts connected to a modem. It
provides `transmit` and `receive` functions for use by external code to handle
the transfer of data frames.

Here is the library in use:
```lua
local unilink = require("net.unilink")

-- Modem side, destination computer ID, data table.
unilink.transmit("top", 4, { "Hello, World!" })
local source, data = unilink.receive()
```

Bare in mind, these functions will do nothing unless its daemon is running at
the same time.

[`daemons.lua`]: daemons.lua
[`broadlink.lua`]: broadlink.lua
[`unilink.lua`]: unilink.lua
