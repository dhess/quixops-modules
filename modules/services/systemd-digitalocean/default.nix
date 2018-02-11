{ config, lib, pkgs, ... }:

with lib;

let

  localLib = import ../../../lib.nix;

  cfg = config.services.systemd-digitalocean;

  systemd-digitalocean = (import "${localLib.fetchNixPkgs}"{ config = {}; }).fetchFromGitHub {
    owner = "edef1c";
    repo = "systemd-digitalocean";
    rev = "0082db1a389d32c54233213c4dd9eaa2283aabce";
    sha256 = "0gfxldqblk1jjxbqad647ah8z1spv8q3ahaw3rifbpzky89vxmby";
  };

  systemd-digitalocean-module = "${systemd-digitalocean}/module.nix";

in

{
  options.services.systemd-digitalocean = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable the systemd DigitalOcean networking module.
      '';
    };
  };

  config = mkIf cfg.enable (import systemd-digitalocean-module { inherit pkgs config; });
}
