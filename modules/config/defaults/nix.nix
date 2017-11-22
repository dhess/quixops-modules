{ config, ... }:

{
  config = {
    nix.useSandbox = true;
    nixpkgs.config.allowUnfree = true;
  };
}
