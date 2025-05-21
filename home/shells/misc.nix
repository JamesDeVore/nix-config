# /my-nix-config/home/tools/misc.nix
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    curl
    # Add other small utilities here
    # wget
    tree
    ripgrep
    fd
  ];
}
