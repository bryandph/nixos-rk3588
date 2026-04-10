# Mainline U-Boot for Turing RK1 (RK3588).
#
# The defconfig (turing-rk1-rk3588_defconfig) is upstream since u-boot v2024.07,
# so no Armbian patches are required — unlike the OPi5Pro which needs one.
#
# Produces u-boot-rockchip.bin (combined TPL+SPL+ATF+U-Boot, single dd)
# and u-boot-rockchip-spi.bin (for SPI NOR flash, if ever needed).
{
  buildUBoot,
  armTrustedFirmwareRK3588,
  rkbin,
  ...
}:
buildUBoot {
  defconfig = "turing-rk1-rk3588_defconfig";
  extraMeta.platforms = ["aarch64-linux"];
  BL31 = "${armTrustedFirmwareRK3588}/bl31.elf";
  ROCKCHIP_TPL = rkbin.TPL_RK3588;
  filesToInstall = [
    "u-boot-rockchip.bin"
    "u-boot-rockchip-spi.bin"
  ];
}
