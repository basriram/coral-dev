# Coral Dev Board — mainline Linux 6.12 Yocto layer

Yocto layer and notes for running mainline Linux 6.12 on the Google Coral Dev
Board (i.MX8MQ, Phanbell), including the Edge TPU, Coral Camera (OV5645), and
USB gadget support.

## Contents

| Path | Description |
|---|---|
| `meta-coral/` | Yocto layer (`coral-dev` machine, kernel/u-boot recipes, camera/PCIe patches, USB gadget, Edge TPU) |
| `config/local.conf` | Example `local.conf` used for the build |
| `config/bblayers.conf` | Example `bblayers.conf` |
| `config/go2rtc.yaml` | go2rtc config for the Coral Camera (GStreamer `exec:` pipeline) |
| `config/go2rtc.service` | systemd unit: camera setup + go2rtc at boot |
| `config/coral-camera-setup.sh` | `media-ctl`/`v4l2-ctl` setup for the OV5645 |
| `tftp/netboot.txt` | U-Boot netboot script source (`mkimage -T script`) |
| `edgetpu_cpp_wrapper_patched.py` | SWIG wrapper patched for Python 3.8 (`imp` removal) |
| `patches/gasket-no_llseek.patch` | gasket-driver fix for Linux 6.12 (`no_llseek` removed) |

## Status

- Mainline `6.12.34-fslc` boots on the board; Edge TPU works via PCIe1
  (`1ac1:089a`, `/dev/apex_0`) with the out-of-tree `gasket`/`apex` modules.
- Edge TPU Python smoke test passes with Python 3.8 + NumPy 1.24.4.
- Coral Camera (OV5645) capture works: set every media pad to
  `UYVY8_1X16/1280x960`, then `v4l2-ctl` captures 2,457,600-byte UYVY frames
  and GStreamer produces JPEG. See the Camera + go2rtc section below.
- go2rtc v1.9.15 streams the camera over RTSP
  (`rtsp://<board>:8554/coral`) and MJPEG
  (`http://<board>:1984/api/stream.mjpeg?src=coral`) using an `exec:`
  GStreamer pipeline. `gst-launch-1.0 -q` is required to keep stdout clean.
- A systemd unit (`go2rtc.service`) applies the camera formats and starts
  go2rtc at boot; verified after reboot.
- USB gadget support (PR 42) is integrated.

## Camera + go2rtc

Set the media pipeline formats (re-apply after each boot):

```sh
media-ctl -d /dev/media0 -V '"ov5645 1-003c":0 [fmt:UYVY8_1X16/1280x960]'
media-ctl -d /dev/media0 -V '"imx8mq-mipi-csi2 30a70000.csi":0 [fmt:UYVY8_1X16/1280x960]'
media-ctl -d /dev/media0 -V '"imx8mq-mipi-csi2 30a70000.csi":1 [fmt:UYVY8_1X16/1280x960]'
media-ctl -d /dev/media0 -V '"csi":0 [fmt:UYVY8_1X16/1280x960]'
media-ctl -d /dev/media0 -V '"csi":1 [fmt:UYVY8_1X16/1280x960]'
v4l2-ctl -d /dev/video0 --set-fmt-video=width=1280,height=960,pixelformat=UYVY
```

`/etc/go2rtc.yaml` (also `config/go2rtc.yaml`):

```yaml
api:
  listen: ":1984"
rtsp:
  listen: ":8554"
streams:
  coral: "exec:gst-launch-1.0 -q v4l2src device=/dev/video0 ! video/x-raw,format=UYVY,width=1280,height=960,framerate=15/1 ! videoconvert ! jpegenc ! multipartmux boundary=frame ! filesink location=/dev/stdout"
```

Install go2rtc and the systemd unit:

```sh
tftp -g -r go2rtc_linux_arm64 <tftp-host>
cp go2rtc_linux_arm64 /usr/local/bin/go2rtc
chmod 0755 /usr/local/bin/go2rtc

cp config/coral-camera-setup.sh /usr/local/bin/coral-camera-setup.sh
chmod 0755 /usr/local/bin/coral-camera-setup.sh
cp config/go2rtc.service /etc/systemd/system/go2rtc.service
systemctl daemon-reload
systemctl enable --now go2rtc.service
```

`go2rtc.service` runs `coral-camera-setup.sh` as `ExecStartPre`, so the
camera formats are applied automatically after each boot. Verified after
reboot: `systemctl is-active go2rtc.service` → `active`,
`systemctl is-enabled` → `enabled`.

Test RTSP:

```sh
gst-launch-1.0 -v rtspsrc location=rtsp://localhost:8554/coral protocols=tcp ! fakesink
```

The stream is also available at `rtsp://<board>:8554/coral`, the MJPEG API at
`http://<board>:1984/api/stream.mjpeg?src=coral`, and the WebUI at
`http://<board>:1984`.

## Building

This repository is a Yocto layer, not a standalone build. Place `meta-coral/`
in a Yocto workspace with `meta-openembedded`, `meta-freescale`,
`meta-freescale-3rdparty`, `meta-freescale-distro`, and `meta-clang`, then:

```bash
. sources/openembedded-core/oe-init-build-env build
bitbake core-image-base
```

`config/local.conf` and `config/bblayers.conf` are examples from the build VM;
adjust `DL_DIR`, `BBLAYERS`, and host paths.

## Notes

- Build artifacts, kernel images, rootfs images, TFTP binaries, and the Python
  3.8 runtime tarball are intentionally not included.
- `switch.sh` is intentionally excluded.
- The `gasket`/`apex` modules must be rebuilt against the running kernel
  (`make -C <kernel-build> M=$PWD ARCH=arm64 CROSS_COMPILE=... modules` from
  the gasket driver's `src/` directory).
