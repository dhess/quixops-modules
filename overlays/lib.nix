self: super:

let

  callLibs = file: import file { pkgs = self; lib = self.lib; };


  ## New types for NixOS modules.

  localTypes = callLibs ./lib/types.nix;

in
{

  lib = (super.lib or {}) // {

    maintainers = super.lib.maintainers // {
      dhess-qx = "Drew Hess <dhess-src@quixoftic.com>";
    };

    ## quixops lib namespace.

    quixops = {

      ## Provide access to the whole package, if needed.

      path = ../.;


      ## A list of all the NixOS modules exported by this package.
      modulesPath = ../modules/module-list.nix;


      ## Helper functions for the modules.

      # Create the text of a znc config file, so that it can be securely
      # deployed to a NixOS host without putting it in the Nix store.
      mkZncConfig = (import ../modules/services/znc/conf.nix);

    };

    types = (super.lib.types or {}) // localTypes;

  };
}
