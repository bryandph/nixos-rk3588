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

    # nixpkgs default 8250 driver caps NR_UARTS at 8 (ttyS0..ttyS7).
    # RK3588 has UART0-UART9; UART9 is wired to the Turing Pi BMC, so
    # ttyS9 must register or `console=ttyS9` silently fails and the
    # board reset-loops on watchdog after kernel handoff.
    kernelPatches = [
      {
        name = "rk3588-bump-8250-nr-uarts";
        patch = null;
        structuredExtraConfig = with lib.kernel; {
          SERIAL_8250_NR_UARTS = freeform "16";
          SERIAL_8250_RUNTIME_UARTS = freeform "16";
        };
      }
    ];

    # mkForce to override sd-image-aarch64.nix defaults (ttyS0, ttyAMA0, tty0).
    #
    # No `root=` is set on purpose. Root is mounted from fileSystems."/"
    # (by-label NIXOS_SD, x-initrd.mount), which is the single source of truth
    # for systemd-stage1. An explicit `root=UUID=...` here was vestigial —
    # NixOS stage-1 ignores it and mounts from the fstab — but under systemd
    # initrd it made systemd-fstab-generator emit a *second* sysroot.mount
    # (by-uuid) that conflicted with the fstab one (by-label), failing the
    # generator and dropping the board to emergency. Omitting it lets systemd
    # initrd work, same as the orangepi5 boards. (Scripted initrd is deprecated
    # and removed in NixOS 26.11.)
    kernelParams = lib.mkForce [
      "rootwait"

      # Bare `earlycon` reads chosen.stdout-path + DT clock-frequency.
      # The explicit `earlycon=uart8250,mmio32,0xfebc0000,115200` form
      # defaults uartclk=1.8432MHz so divisor=1 puts the line at 1.5Mbaud
      # against the BMC's 115200 reader (= unreadable).
      "earlycon"
      "keep_bootcon" # keep earlycon active even after ttyS9 takes over
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
