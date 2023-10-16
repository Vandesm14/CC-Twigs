# Scheduler

This package allows for dynamic starting and stoping of background processes all
running on a single thread.

## Getting Started

First, run [`daemons.lua`] as a process, most likely a background one. It will
receive and handle requests to start and stop schedules, as well as run the
schedules themselves. Once it has started, you can use [`cli.lua`] to send
these requests the daemon.

For example:

```shell
$ bg .mngr/scheduler/daemon

$ .mngr/scheduler/cli start net.broadlink
$ .mngr/scheduler/cli start net.follownet
$ .mngr/scheduler/cli start net.searchnet

$ .mngr/net-tools/tracenet 4
> # An example programme that uses the started schedules.

$ .mngr/scheduler/cli logs net.searchnet
> # The last ten logs for seachnet will be printed.
```

[`daemons.lua`]: daemons.lua
[`cli.lua`]: cli.lua
