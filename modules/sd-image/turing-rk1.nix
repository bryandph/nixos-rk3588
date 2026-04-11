{
  lib,
  config,
  pkgs,
  rk3588,
  ...
}: let
  rootPartitionUUID = "0bf70c3b-50f8-4f22-8254-2eaf50f1f7b7";
  uboot = pkgs.callPackage ../../pkgs/u-boot-turing-rk1 {};
in {
  imports = [
    "${rk3588.nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
  ];

  boot = {
    loader = {
      grub.enable = lib.mkForce false;
      generic-extlinux-compatible.enable = lib.mkForce true;
    };
  };

  sdImage = {
    inherit rootPartitionUUID;
    # BMC requires raw .img — no compression saves a decompress step on flash
    compressImage = false;

    # install firmware into a separate partition: /boot/firmware
    populateFirmwareCommands = ''
      ${config.boot.loader.generic-extlinux-compatible.populateCmd} -c ${config.system.build.toplevel} -d ./firmware
    '';
    # Gap in front of the /boot/firmware partition, in mebibytes (1024×1024 bytes).
    # Can be increased to make more space for boards requiring to dd u-boot SPL before actual partitions.
    firmwarePartitionOffset = 32;
    firmwarePartitionName = "BOOT";
    firmwareSize = 200; # MiB

    populateRootCommands = ''
      mkdir -p ./files/boot
      mkdir -p ./files/boot/firmware
    '';

    # Mainline u-boot produces a single combined binary (TPL+SPL+ATF+U-Boot).
    # Write at sector 64 (byte offset 32 KiB) per Rockchip boot ROM spec.
    postBuildCommands = ''
      dd if=${uboot}/u-boot-rockchip.bin of=$img seek=64 conv=notrunc
    '';
  };
}
