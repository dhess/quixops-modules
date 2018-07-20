## Support for anycasted services. This is implemented by configuring
## a "dummy" interface and assigning one or more anycast IPs to it.
##
## For an explanation of anycast and how it's useful, see:
## https://serverfault.com/questions/14985/what-is-anycast-and-how-is-it-helpful#15019
##
## CAUTION: make sure your service can handle being anycasted before
## using this module with it. For example, it's probably a really bad
## idea to run mutable/stateful services this way.

# TODO
# - Configure a bird instance to handle routing advertisements.
# - Firewall setup.
# - Actually make use of ifnum.

{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.networking.anycastAddrs;
  enable = cfg.v4 != [] || cfg.v6 != [];

in

{
  options.networking.anycastAddrs = mkOption {
    type = pkgs.lib.types.anycastAddrs;
    default = { v4 = []; v6 = []; };
    example = {
      v4 = [ { ifnum = 0; addrOpts = { address = "10.0.0.1"; prefixLength = 32; }; } ];
      v6 = [ { ifnum = 0; addrOpts = { address = "2001:db8::1"; prefixLength = 128; }; } ];
    };
    description = ''
      A set of IPv4 and IPv6 anycast addresses to configure.
    '';
  };

  config = mkIf enable {

    # Note: prefer dummy devices to loopback devices, as it's
    # conceivable there are all kinds of weird workarounds and special
    # cases for loopback devices.

    # XXX dhess - TODO: actually use ifnum here, rather than just
    # assigning to dummy0.
    
    boot.kernelModules = [ "dummy" ];
    networking.interfaces.dummy0.ipv4.addresses =
      map (ip: with ip.addrOpts; { inherit address prefixLength; }) cfg.v4;
    networking.interfaces.dummy0.ipv6.addresses =
      map (ip: with ip.addrOpts; { inherit address prefixLength; }) cfg.v6;
    
  };

}
