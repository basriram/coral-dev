#!/bin/sh
set -e

# Load the camera modules if they are not already loaded. The interconnect
# driver must be loaded before the MIPI CSI-2 driver.
modprobe imx8mq_interconnect 2>/dev/null || true
modprobe imx8mq_mipi_csi2 2>/dev/null || true
modprobe imx7_media_csi 2>/dev/null || true
modprobe ov5645 2>/dev/null || true

# Wait for the media controller and capture device (up to 30 seconds).
i=0
while [ ! -e /dev/media0 ] || [ ! -e /dev/video0 ]; do
    i=$((i + 1))
    if [ "$i" -ge 30 ]; then
        echo "coral-camera-setup: /dev/media0 or /dev/video0 not found" >&2
        exit 1
    fi
    sleep 1
done

# The OV5645 only supports UYVY8_1X16. Every pad must match or the CSI
# pipeline fails with -EPIPE.
media-ctl -d /dev/media0 -V '"ov5645 1-003c":0 [fmt:UYVY8_1X16/1280x960]'
media-ctl -d /dev/media0 -V '"imx8mq-mipi-csi2 30a70000.csi":0 [fmt:UYVY8_1X16/1280x960]'
media-ctl -d /dev/media0 -V '"imx8mq-mipi-csi2 30a70000.csi":1 [fmt:UYVY8_1X16/1280x960]'
media-ctl -d /dev/media0 -V '"csi":0 [fmt:UYVY8_1X16/1280x960]'
media-ctl -d /dev/media0 -V '"csi":1 [fmt:UYVY8_1X16/1280x960]'
v4l2-ctl -d /dev/video0 --set-fmt-video=width=1280,height=960,pixelformat=UYVY

echo "coral-camera-setup: camera formats set to UYVY8_1X16/1280x960"
