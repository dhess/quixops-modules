{ name, config, lib }:

with lib;

rec {
  options = {

    name = mkOption {
      type = types.string;
      default = "${name}";
      example = "eno1";
      description = ''
        The name of the network device.
      '';
    };

    rxRingEntries = mkOption {
      type = types.int;
      default = 512;
      example = 256;
      description = ''
        Set the number of ring entries for the device's Rx ring.
      '';
    };

    usecBetweenRxInterrupts = mkOption {
      type = types.int;
      default = 100;
      example = 200;
      description = ''
        Set the number of microseconds between device Rx interrupts.
      '';
    };

  };

}
