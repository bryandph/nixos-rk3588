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

    # kernelParams copy from Armbian's /boot/armbianEnv.txt & /boot/boot.cmd
    kernelParams = [
      "rootwait"

      "earlycon" # enable early console, so we can see the boot messages via serial port / HDMI
      "consoleblank=0" # disable console blanking(screen saver)
      "console=ttyS2,1500000" # serial port — maps to BMC UART bridge on Turing Pi 2 (MUST be last for stage-1 visibility)

      # docker optimizations
      "cgroup_enable=cpuset"
      "cgroup_memory=1"
      "cgroup_enable=memory"
      "swapaccount=1"
    ];
  };

  hardware = {
    deviceTree = {
      name = "rockchip/rk3588-turing-rk1.dtb";
      dtbSource = patchedDtbs;
      overlays = [];
    };
  };
}
