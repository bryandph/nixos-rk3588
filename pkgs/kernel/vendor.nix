# args of buildLinux:
#   https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/os-specific/linux/kernel/generic.nix
# Note that this method will use the deconfig in source tree,
# commbined the common configuration defined in pkgs/os-specific/linux/kernel/common-config.nix, which is suitable for a NixOS system.
# but it't not suitable for embedded systems, so we comment it out.
# ================================================================
# If you already have a generated configuration file, you can build a kernel that uses it with pkgs.linuxManualConfig
# The difference between deconfig and the generated configuration file is that the generated configuration file is more complete,
#
{
  fetchFromGitHub,
  linuxManualConfig,
  ubootTools,
  ...
}: let
  modDirVersion = "6.1.115";
in
  (linuxManualConfig {
    inherit modDirVersion;
    version = "${modDirVersion}-armbian";
    extraMeta.branch = "rk-6.1-rkr5.1";

    # https://github.com/Joshua-Riek/linux-rockchip/tree/noble
    src = fetchFromGitHub {
      owner = "armbian";
      repo = "linux-rockchip";
      #rev = "rk-6.1-rkr5.1";
      # Bumped to rk-6.1-rkr5.1 HEAD (2026-07-15) to pull current Armbian
      # RK3588 fixes — notably for the orangepi5pro's YT6801 PCIe NIC.
      # (orangepi5 itself runs mainline now and doesn't use this kernel.)
      rev = "5280f9b4336199c4025c8eed894d2b4e2268dcc6";
      hash = "sha256-oeQTdBQk5oqFopDgtiqULDAM2WG98AvQIQ6fzL+EYkU=";
    };

    kernelPatches = [
    ];

    # Steps to the generated kernel config file
    #  1. git clone --depth 1 https://github.com/hbiyik/linux.git -b rk-6.1-rkr3-panthor
    #  2. put https://github.com/hbiyik/linux/blob/rk-6.1-rkr3-panthor/debian.rockchip/config/config.common.ubuntu to arch/arm64/configs/rk35xx_vendor_defconfig
    #  3. run `nix develop .#fhsEnv` in this project to enter the fhs test environment defined here.
    #  4. `make rk35xx_vendor_defconfig` in the kernel root directory to configure the kernel.
    #  5. Then use `make menuconfig` in kernel's root directory to view and customize the kernel(like enable/disable rknpu, rkflash, ACPI(for UEFI) etc).
    #  6. copy the generated .config to ./pkgs/kernel/rk35xx_vendor_config (also be sure to update the corresponding `.nix` file accordingly) and commit it.
    #
    configfile = ./rk35xx_vendor_config;
    config = import ./rk35xx_vendor_config.nix;
  }).overrideAttrs (old: {
    # Historical note: this used to force `name = "k"` to "dodge uboot
    # length limits". That console-buffer limit doesn't bind here: the
    # kernel name only reaches the extlinux KERNEL/FDTDIR lines
    # (/boot/nixos/<hash>-<name>-Image, ~90 chars with the full name),
    # while the APPEND line already carries the far longer
    # init=/nix/store/<hash>-nixos-system-<host>-<release>/init and
    # boots fine — as do sibling boards (turing-rk1, mainline opi5)
    # using standard full-length kernel names on the same U-Boot path.
    # Keeping linuxManualConfig's default name (linux-<version>) makes
    # the derivation identifiable in build logs and binary caches.
    nativeBuildInputs = old.nativeBuildInputs ++ [ubootTools];

    # The hacky mali code tries to include a binary blob by a relative path,
    # which works only when your src dir is the same as build dir. It breaks with
    # Nix'es reproducible builds where these are cleanly separated. We patch the
    # path to point be absolute. Not sure if this is a clean solution, but it
    # seems to work.
    postPatch =
      ''
        sed -i "drivers/gpu/arm/bifrost/csf/mali_kbase_csf_firmware.c" \
          -e "s:drivers/gpu/arm/bifrost/mali_csffw.bin:$src/drivers/gpu/arm/bifrost/mali_csffw.bin:"
      ''
      + "\n"
      + old.postPatch;
  })
