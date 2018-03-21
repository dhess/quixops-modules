# Configuration common to Intel Centerton (Atom Processor S Series)
# hardware systems.

{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.quixops.hardware.intel.centerton;
  enabled = cfg.enable;
  intelConfig = import ./common.nix { inherit config lib pkgs; };

in
{
  options.quixops.hardware.intel.centerton = {
    enable = mkEnableOption "Enable Intel Centerton hardware configuration.";
  };

  config = mkIf enabled ({
    boot.initrd.availableKernelModules = [ "xhci_pci" "usbhid" "usb_storage" "sd_mod" ];
    boot.initrd.kernelModules = [ "ahci" ];
  } // intelConfig);
}
