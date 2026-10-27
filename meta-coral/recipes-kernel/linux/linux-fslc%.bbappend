FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI:append:coral-dev = " file://extra.cfg file://wifi.cfg file://camera.cfg file://0001-arm64-dts-imx8mq-phanbell-add-coral-camera.patch file://0002-arm64-dts-imx8mq-phanbell-enable-pcie1.patch"
