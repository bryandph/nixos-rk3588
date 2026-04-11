# =========================================================================
#      Turing RK1 Specific Configuration
# =========================================================================
#
# The RK1 is a compute module (SO-DIMM form factor) with a full RK3588.
# No WiFi/BT/LEDs to configure — board has no extras beyond base.
#
# PCIe workaround: The Turing Pi 2 backplane leaves PCIe lanes unconnected
# for most slots, causing the rk-pcie vendor driver to hang during link
# training. We patch the DTB with fdtput to disable both controllers.
# Standard DT overlays (target-path) silently fail with this vendor kernel's
# libfdt, so we modify the DTB source directly.
{
  rk3588,
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (rk3588) pkgsKernel;
  vendorKernel = pkgsKernel.callPackage ../../pkgs/kernel/vendor.nix {};

  # Patch the vendor DTB to disable PCIe controllers that hang on the
  # Turing Pi 2 backplane (no devices connected → infinite link training).
  patchedDtbs = pkgs.runCommand "patched-rk1-dtbs" {
    nativeBuildInputs = [pkgs.dtc];
  } ''
    cp -r ${vendorKernel}/dtbs $out
    chmod -R u+w $out
    fdtput -t s $out/rockchip/rk3588-turing-rk1.dtb /pcie@fe150000 status disabled
    fdtput -t s $out/rockchip/rk3588-turing-rk1.dtb /pcie@fe180000 status disabled
  '';
in {
  imports = [
    ./base.nix
    ./dtb-install.nix
  ];

  boot = {
    kernelPackages = pkgsKernel.linuxPackagesFor vendorKernel;

    # mkForce to override sd-image-aarch64.nix defaults (ttyS0, ttyAMA0, tty0)
    # that conflict with the RK1's UART layout.
    kernelParams = lib.mkForce [
      "root=UUID=0bf70c3b-50f8-4f22-8254-2eaf50f1f7b7"
      "rootfstype=ext4"
      "rootwait"

      "earlycon" # enable early console before ttyS9 driver loads
      "consoleblank=0" # disable console blanking
      "console=ttyS9,1500000" # UART9 — SO-DIMM to Turing Pi 2 BMC. 1.5Mbaud keeps kernel alive (115200 deadlocks vendor kernel)
      "loglevel=7"
      "net.ifnames=0" # keep classic eth0 naming for GMAC

      # cgroup v1 compat for k3s
      "cgroup_enable=cpuset"
      "cgroup_memory=1"
      "cgroup_enable=memory"
      "swapaccount=1"
    ];

    # Minimal initrd — only eMMC and NVMe needed
    initrd.includeDefaultModules = lib.mkForce false;
    initrd.availableKernelModules = lib.mkForce [
      "mmc_block" # eMMC / SD
      "nvme" # NVMe SSD
    ];

    # No ZFS on RK1
    supportedFilesystems = lib.mkForce ["vfat" "ext4"];
  };

  hardware = {
    deviceTree = {
      name = "rockchip/rk3588-turing-rk1.dtb";
      dtbSource = patchedDtbs;
      overlays = [];
    };
  };
}
