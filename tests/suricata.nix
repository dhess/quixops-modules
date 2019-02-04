{ system ? "x86_64-linux"
, pkgs
, makeTest
, ...
}:

let

in makeTest rec {
  name = "suricata";

  meta = with pkgs.lib.maintainers; {
    maintainers = [ dhess-pers ];
  };

  machine = { config, ... }: {
    nixpkgs.localSystem.system = system;
    imports = [
      ./common/users.nix
    ] ++ (import pkgs.lib.quixops-modules.modulesPath);

  };

  testScript = { nodes, ... }:
  ''
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
