{ config, lib, ... }:

with lib;

let

  localLib = import ../../../lib.nix;
  cfg = config.quixops.defaults.overlays;
  enabled = cfg.enable;

in
{

  options.quixops.defaults.overlays = {

    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable the QuixOps <literal>nixpkgs</literal> overlays. Many
        of the QuixOps modules require the QuixOps overlays to be
        enabled, so while the default is <literal>false</literal> to
        prevent unexpected surprises, you probably want to set this to
        <literal>true</literal>, if you plan to use any QuixOps
        modules in your configuration.

        QuixOps modules that require the overlays to be enabled will
        check the value of this option, and fail to build if it is not
        set to <literal>true</literal>.
      '';
    };

  };

  config = mkIf enabled {

    nixpkgs.overlays = [
      (import localLib.fetchNixPkgsQuixoftic)
    ];

  };

}
