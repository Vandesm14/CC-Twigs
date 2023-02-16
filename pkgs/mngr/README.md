# Mngr

A simple package manager for ComputerCraft.

## Installation

You can run the command below to install `mngr`.

```sh
wget run http://mr.thedevbird.com:3000/pkgs/mngr/install.lua
```

Once installed, it will automatically set itself up.

## Usage

### Installing a package

To install a package, run the command below.

```sh
mngr install <package>
```

### Fetching info for a package

To get info for a package (installed or not), run the command below.

```sh
mngr info <package>
```

### Removing a package

To Remove a package, run the command below.

```sh
mngr remove <package>
```

### Updating a package

To update a package, run the command below.

```sh
mngr update <package>
```

### Updating all packages

To update all packages, run the command below.

```sh
mngr update
```

### Listing all packages

To list all packages, run the command below.

```sh
mngr list
```

### Auto-downloading and running a package

To auto-download and run a package, run the command below.

```sh
mngr run <package> [binary] [args...]
```

_Note: This installs the package as normal, but runs it afterward_

## Links

Mngr has a special feature called **Links**. Links are a way to alias a binary so that it mngr updates it before you run it, all without having to run `mngr run <package>` each time!

### Creating links

To get started, you can create a link with the command below.

```sh
mngr link <package> [binary]
```

_Note: The package needs to be installed before you link_

### Using links

To use a link, simply run the command as normal. Each time you run the binary, it will be loaded with the latest version of the package (Perfect for Development!).

```sh
<binary> [args...]
```

### Removing links

To remove a link, run the command below.

```sh
mngr unlink <binary>
```

### Listing links

To list all links, run the command below.

```sh
mngr links
```
