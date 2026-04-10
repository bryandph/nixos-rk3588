# =========================================================================
#      Turing RK1 Specific Configuration
# =========================================================================
#
# The RK1 is a compute module (SO-DIMM form factor) with a full RK3588.
# No WiFi/BT/LEDs to configure — board has no extras beyond base.
{
  rk3588,
  ...
}: let
  inherit (rk3588) pkgsKernel;
in {
  imports = [
    ./base.nix
    ./dtb-install.nix
  ];

  boot = {
    kernelPackages = pkgsKernel.linuxPackagesFor (pkgsKernel.callPackage ../../pkgs/kernel/vendor.nix {});

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
      overlays = [
        {
          # Disable PCIe controllers — the rk-pcie platform driver hangs during
          # link training on the Turing Pi 2 backplane. The vendor kernel's
          # rk-pcie driver ignores pci=off (it's a platform driver, not PCI bus).
          name = "disable-pcie";
          dtsText = ''
            /dts-v1/;
            /plugin/;

            &pcie2x1l1 {
              status = "disabled";
            };

            &pcie3x4 {
              status = "disabled";
            };

            &pcie30phy {
              status = "disabled";
            };
          '';
        }
      ];
    };
  };
}
