{ system
, pkgs
, lib
, modules
, makeTest
, ... }:

let

in makeTest rec {
  name = "suricata";

  meta = with lib.quixopsMaintainers; {
    maintainers = [ dhess ];
  };

  machine = { config, pkgs, ... }: {

    imports = [
      ./common/users.nix
    ] ++ modules;
    quixops.defaults.overlays.enable = true;

  };

  testScript = { nodes, ... }:
  let
    pkgs = nodes.machine.pkgs;
  in ''
    $machine->waitForUnit("multi-user.target");

    subtest "check-features", sub {
      # Just check a few key features, make sure they're enabled.
      my $out = $machine->succeed("${pkgs.suricata}/bin/suricata --build-info");
      $out =~ /AF_PACKET support:\s+yes\n/ or die "Missing AF_PACKET support.";
      $out =~ /hiredis async with libevent:\s+yes\n/ or die "Missing hiredis or libevent support.";
      $out =~ /Hyperscan support:\s+yes\n/ or die "Missing Hyperscan support.";
      $out =~ /Libnet support:\s+yes\n/ or die "Missing libnet support.";
      $out =~ /Rust support .* yes\n/ or die "Missing Rust support.";
    };
  '';
}
