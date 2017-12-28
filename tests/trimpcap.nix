let

  lib = import ../lib.nix;

in

{ system ? builtins.currentSystem
, pkgs ? (import lib.fetchNixPkgs) { inherit system; }
, makeTest
, ... }:

let

  pcapFile = ./testfiles/DHCPv6.pcap;

  testSize = pkgs.writeScript "testSize" ''
    #!${pkgs.stdenv.shell} -e
    [[ `(stat -c%s "$1")` -gt `(stat -c%s "$2")` ]]
  '';

in makeTest rec {
  name = "trimpcap";

  meta = with lib.quixopsMaintainers; {
    maintainers = [ dhess ];
  };

  machine = { config, pkgs, ... }: {

    imports = [
      ./common/users.nix
    ] ++ lib.quixopsModules;
    quixops.defaults.overlays.enable = true;

  };

  testScript = { nodes, ... }:
  let
    pkgs = nodes.machine.pkgs;
  in ''
    # Sanity check that the file is what we think it is. Note that
    # ngrep doesn't return proper error codes, so we have to grep its
    # grep.
    $machine->succeed("${pkgs.ngrep}/bin/ngrep -I ${pcapFile} host ff02::16 | grep ff02::16");

    subtest "pcap-is-trimmed", sub {
      $machine->succeed("cp ${pcapFile} /tmp/test.pcap");
      $machine->succeed("${pkgs.trimpcap}/bin/trimpcap --flowsize 512 /tmp/test.pcap");
      $machine->succeed("${testSize} /tmp/test.pcap /tmp/test.pcap.trimmed");
      $machine->succeed("rm /tmp/test.pcap.trimmed");
    };

    subtest "trimmed-pcap-is-valid", sub {
      $machine->succeed("cp ${pcapFile} /tmp/test.pcap");
      $machine->succeed("${pkgs.trimpcap}/bin/trimpcap --flowsize 512 /tmp/test.pcap");
      $machine->succeed("${pkgs.ngrep}/bin/ngrep -I /tmp/test.pcap.trimmed host ff02::16 | grep ff02::16");
      $machine->succeed("rm /tmp/test.pcap.trimmed");
    };

    subtest "trim-extension", sub {
      $machine->succeed("cp ${pcapFile} /tmp/test.pcap");
      $machine->succeed("${pkgs.trimpcap}/bin/trimpcap --flowsize 512 --extension .foo /tmp/test.pcap");
      $machine->succeed("[ -f /tmp/test.pcap.foo ]");
      $machine->succeed("rm /tmp/test.pcap.foo");
    };
  '';
}
