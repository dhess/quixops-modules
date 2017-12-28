{ config, pkgs, lib, ... }:

with lib;

let

  cfg = config.quixops.defaults;
  enabled = cfg.enable;

in
{

  options.quixops.defaults = {

    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable all of the QuixOps configuration defaults.

        These defaults will configure a NixOS server according to the
        Quixoftic security requirements. Note that some of the
        defaults may not be appropriate for an interactive desktop
        system.

        This will also enable the QuixOps <literal>nixpkgs</literal>
        overlays, which provide package overlays that are required for
        various QuixOps modules to function properly.
      '';
    };

  };

  config = mkIf enabled {

    quixops.defaults = {

      environment.enable = true;
      networking.enable = true;
      nix.enable = true;
      overlays.enable = true;
      security.enable = true;
      ssh.enable = true;
      sudo.enable = true;
      system.enable = true;
      users.enable = true;

    };

  };

}
