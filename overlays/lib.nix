self: super:

let

in
{

  lib = (super.lib or {}) // {

    maintainers = super.lib.maintainers // {
      dhess-qx = "Drew Hess <dhess-src@quixoftic.com>";
    };


    ## quixops lib namespace.

    quixops = {

      ## A list of all the NixOS modules exported by this package.
      modulesPath = ../modules/module-list.nix;


      ## Helper functions for the modules.

      # Create the text of a znc config file, so that it can be securely
      # deployed to a NixOS host without putting it in the Nix store.
      mkZncConfig = (import ../modules/services/znc/conf.nix);

    };

  };
}
