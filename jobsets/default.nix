# Based on
# https://github.com/input-output-hk/iohk-ops/blob/df01a228e559e9a504e2d8c0d18766794d34edea/jobsets/default.nix

{ nixpkgs ? <nixpkgs>
, declInput ? {}
}:

let

  quixopsModulesUri = "https://github.com/quixoftic/quixops-modules.git";

  mkFetchGithub = value: {
    inherit value;
    type = "git";
    emailresponsible = false;
  };

  nixpkgs-src = builtins.fromJSON (builtins.readFile ../nixpkgs-src.json);

  pkgs = import nixpkgs {};

  defaultSettings = {
    enabled = 1;
    hidden = false;
    keepnr = 5;
    schedulingshares = 400;
    checkinterval = 60;
    enableemail = false;
    emailoverride = "";
    nixexprpath = "release.nix";
    nixexprinput = "quixopsModules";
    description = "QuixOps modules";
    inputs = {
      quixopsModules = mkFetchGithub "${quixopsModulesUri} master";
    };
  };

  mkAlternate = quixopsModulesBranch: nixpkgsQuixopsBranch: nixpkgsRev: {
    checkinterval = 60;
    inputs = {
      quixops_pkgs = mkFetchGithub "https://github.com/NixOS/nixpkgs-channels.git ${nixpkgsRev}";
      nixpkgs_quixoftic_override = mkFetchGithub "https://github.com/quixoftic/nixpkgs-quixoftic.git ${nixpkgsQuixopsBranch}";
      quixopsModules = mkFetchGithub "${quixopsModulesUri} ${quixopsModulesBranch}";
    };
  };

  mainJobsets = with pkgs.lib; mapAttrs (name: settings: defaultSettings // settings) (rec {
    master = {};
    nixos-unstable-small = mkAlternate "master" "master" "nixos-unstable-small";
  });

  jobsetsAttrs = mainJobsets;

  jobsetJson = pkgs.writeText "spec.json" (builtins.toJSON jobsetsAttrs);

in {
  jobsets = with pkgs.lib; pkgs.runCommand "spec.json" {} ''
    cat <<EOF
    ${builtins.toJSON declInput}
    EOF
    cp ${jobsetJson} $out
  '';
}
