{ config, pkgs, lib, ... }:

with lib;

let

  cfg = config.quixops.defaults.ssh;
  enabled = cfg.enable;

in
{
  options.quixops.defaults.ssh = {

    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable the Quixops SSH configuration defaults.
      '';
    };

  };

  config = mkIf enabled {

    services.openssh.enable = true;
    services.openssh.passwordAuthentication = false;
    services.openssh.permitRootLogin = lib.mkForce "prohibit-password";

  };
}
