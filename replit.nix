{ pkgs }: {
  deps = [
    pkgs.unixtools.netstat
    pkgs.deno
    pkgs.lua
    pkgs.sumneko-lua-language-server
  ];
}
