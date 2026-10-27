FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

# U-Boot 2025.01's lib/rsa/rsa-sign.c still uses the OpenSSL ENGINE API,
# which OpenSSL 4 removed. The Coral Dev Board does not use signed FIT
# images, so build the host tools without libcrypto.
SRC_URI += "file://disable-libcrypto.cfg"
SRC_URI += "file://efi-partition.cfg"

# The WIC image uses a GPT partition table; U-Boot's default
# imx8mq_phanbell_defconfig does not enable GPT parsing, so mmc 1:1
# resolves to the protective MBR instead of the boot partition.
# The .cfg files in SRC_URI are merged by the u-boot class's find_cfgs().

# U-Boot 2025.01's shipped pylibfdt interface still uses Python 2 APIs,
# which fail to link against Python 3.
SRC_URI += "file://0001-pylibfdt-use-python3-apis.patch"

# binman still imports pkg_resources, which setuptools 84 no longer ships.
SRC_URI += "file://0002-binman-drop-pkg_resources.patch"

# The imx-boot recipe assembles the i.MX8M boot container from the
# u-boot-nodtb.bin and device tree produced by this recipe. Building the
# default target also runs binman, which fails on the external DDR/HDMI/ATF
# blobs; build only the pieces imx-boot consumes.
UBOOT_MAKE_TARGET = "u-boot.bin spl/u-boot-spl.bin"

BOOT_TOOLS = "imx-boot-tools"

# The imx-boot recipe owns the boot container; u-boot's deploy must not
# try to tag a file it does not produce.
UUU_BOOTLOADER:mx8-generic-bsp = ""

do_deploy:append() {
    if [ -n "${UBOOT_CONFIG}" ]; then
        for config in ${UBOOT_MACHINE}; do
            i=$(expr $i + 1)
            for type in ${UBOOT_CONFIG}; do
                j=$(expr $j + 1)
                if [ $j -eq $i ]; then
                    install -d ${DEPLOYDIR}/${BOOT_TOOLS}
                    install -m 0644 ${B}/${config}-${type}/arch/arm/dts/${UBOOT_DTB_NAME} ${DEPLOYDIR}/${BOOT_TOOLS}
                    install -m 0644 ${B}/${config}-${type}/u-boot-nodtb.bin ${DEPLOYDIR}/${BOOT_TOOLS}/u-boot-nodtb.bin-${MACHINE}-${type}
                fi
            done
            unset j
        done
        unset i
    fi
}
