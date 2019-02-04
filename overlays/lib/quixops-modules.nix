self: super:

let

  # Provide access to the whole package, if needed.
  path = ../../.;


  # A list of all the NixOS modules exported by this package.
  modulesPath = ../../modules/module-list.nix;


  # Create the text of a znc config file, so that it can be securely
  # deployed to a NixOS host without putting it in the Nix store.
  mkZncConfig = (import ../../modules/services/znc/conf.nix);

  # A list of all the NixOS test modules exported by this package.
  #
  # NOTE: do NOT use these in production. They will do bad
  # things, like writing secrets to your Nix store. Use them ONLY
  # for testing. You have been warned!
  testModulesPath = ../../test-modules/module-list.nix;

in
{
  lib = (super.lib or {}) // {
    quixops-modules = (super.lib.quixops-modules or {}) // {
      inherit path modulesPath;
      inherit mkZncConfig;

      testing = (super.lib.quixops-modules.testing or {}) // {
        inherit testModulesPath;
      };      
    };
  };
}
