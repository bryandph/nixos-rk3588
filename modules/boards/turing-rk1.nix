# =========================================================================
#      Turing RK1 — Mainline Kernel Configuration
# =========================================================================
#
# The RK1 is a compute module (SO-DIMM form factor) with a full RK3588.
# Uses mainline kernel (linuxPackages_latest) for stability — no vendor
# kernel fiq-debugger quirks, no PCIe hang with mainline driver timeouts.
#
# UART layout:
#   - UART2 (0xfeb50000): Rockchip debug UART, test pads only (not BMC)
#   - UART9 (0xfebc0000): Routed via SO-DIMM to Turing Pi 2 BMC at 115200
#
# U-Boot console: UART9 at 115200 (CONFIG_DEBUG_UART_BASE=0xFEBC0000)
# BMC (bmcd): hardcoded 115200 8N1
{
  pkgs,
  lib,
  ...
}: {
  imports = [
    ./base.nix
    ./dtb-install.nix
  ];

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;

    # mkForce to override sd-image-aarch64.nix defaults (ttyS0, ttyAMA0, tty0)
    kernelParams = lib.mkForce [
      "root=UUID=0bf70c3b-50f8-4f22-8254-2eaf50f1f7b7"
      "rootfstype=ext4"
      "rootwait"

      "earlycon=uart8250,mmio32,0xfebc0000,115200" # earlycon on UART9 hardware address
      "console=ttyS9,115200" # UART9 — SO-DIMM to Turing Pi 2 BMC
      "loglevel=7"
      "net.ifnames=0" # keep classic eth0 naming for GMAC

      # cgroup v1 compat for k3s
      "cgroup_enable=cpuset"
      "cgroup_memory=1"
      "cgroup_enable=memory"
      "swapaccount=1"
    ];
  };

  hardware = {
    deviceTree = {
      name = "rockchip/rk3588-turing-rk1.dtb";
      # Filter to only RK3588 DTBs — mainline kernel builds DTBs for ALL
      # aarch64 boards (~3000 files) which overflows the firmware partition.
      filter = "*rk3588*";
      overlays = [];
    };
  };
}
