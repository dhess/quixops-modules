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

  cfg = config.networking.anycast;
  enable = cfg.v4s != [] || cfg.v6s != [];

in

{
  options.networking.anycast = {

    v4s = mkOption {
      type = types.listOf (types.submodule {
        options = {

          ifnum = mkOption {
            type = types.unsigned;
            default = 0;
            description = ''
              All anycast addresses are assigned to a Linux
              <literal>dummy</literal> virtual interface. By default,
              this is <literal>dummy0</literal>, but you can specify a
              different index by setting it here.
            '';
          };

          addrOpts = mkOption {
            type = pkgs.lib.types.addrOptsV4;
            example = { address = "10.0.0.1"; prefixLength = 32; };
            description = ''
              The IPv4 anycast address (no CIDR suffix) and prefix.
            '';
          };

        };
      });
      default = [];
      example = [ { ifnum = 0; addrOpts = { address = "10.8.8.8"; prefixLength = 32; }; } ];
      description = ''
        A list of IPv4 anycast addresses and their
        <literal>dummy</literal> interface index.
      '';
    };

    v6s = mkOption {
      type = types.listOf (types.submodule {
        options = {

          ifnum = mkOption {
            type = types.unsigned;
            default = 0;
            description = ''
              All anycast addresses are assigned to a Linux
              <literal>dummy</literal> virtual interface. By default,
              this is <literal>dummy0</literal>, but you can specify a
              different index by setting it here.
            '';
          };

          addrOpts = mkOption {
            type = pkgs.lib.types.addrOptsV6;
            example = { address = "2001:db8::1"; prefixLength = 128; };
            description = ''
              The IPv6 anycast address (no CIDR suffix) and prefix.
            '';
          };

        };
      });
      default = [];
      example = [ { ifnum = 0; addrOpts = { address = "2001:db8::1"; prefixLength = 128; }; } ];
      description = ''
        A list of IPv6 anycast addresses and their
        <literal>dummy</literal> interface index.
      '';
    };

  };

  config = mkIf enable {

    # Note: prefer dummy devices to loopback devices, as it's
    # conceivable there are all kinds of weird workarounds and special
    # cases for loopback devices.

    # XXX dhess - TODO: actually use ifnum here, rather than just
    # assigning to dummy0.
    
    boot.kernelModules = [ "dummy" ];
    networking.interfaces.dummy0.ipv4.addresses =
      map (ip: with ip.addrOpts; { inherit address prefixLength; }) cfg.v4s;
    networking.interfaces.dummy0.ipv6.addresses =
      map (ip: with ip.addrOpts; { inherit address prefixLength; }) cfg.v6s;
    
  };

}
