self: super:

let

  callLibs = file: import file { pkgs = self; lib = self.lib; };


  ## New types for NixOS modules.

  localTypes = callLibs ./lib/types.nix;

in
{

  lib = (super.lib or {}) // {

    maintainers = super.lib.maintainers // {
      dhess-pers = "Drew Hess <src@drewhess.com>";
    };

    ## quixops lib namespace.

    quixops = {

      ## Provide access to the whole package, if needed.

      path = ../.;


      ## A list of all the NixOS modules exported by this package.
      modulesPath = ../modules/module-list.nix;


      ## A list of all the NixOS test modules exported by this package.
      ##
      ## NOTE: do NOT use these in production. They will do bad
      ## things, like writing secrets to your Nix store. Use them ONLY
      ## for testing. You have been warned!
      testModulesPath = ../test-modules/module-list.nix;

      ## Helper functions for the modules.

      # Create the text of a znc config file, so that it can be securely
      # deployed to a NixOS host without putting it in the Nix store.
      mkZncConfig = (import ../modules/services/znc/conf.nix);

    };

    types = (super.lib.types or {}) // localTypes;

  };
}
