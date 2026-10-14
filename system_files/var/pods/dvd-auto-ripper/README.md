# DVD Auto Ripper (Podman starter)

A rootful Podman starter for automatically detecting DVD-Video discs, saving technical disc information, and encoding the longest title to MKV using FFmpeg VA-API H.264 when the host GPU/driver supports it.

## Important limitations

- This is a starter, not yet validated against your particular optical drive, OS, and Intel driver.
- Intel HD Graphics 4000 is old. VA-API H.264 encoding is the intended path; current HandBrake Quick Sync support is not officially targeted at this generation.
- `dvd_rip` defaults to the longest title according to the upstream dvd_info project.
- DVD-Video CSS/encryption support depends on the libraries available in the image and local law. This image does not add a separate CSS-decryption package. Test with a disc you are authorized to back up.
- The folder is initially named from the DVD volume label, which often is not the commercial movie title. Rename the folder/file to `Movie Title (Year)` for Kodi's scraper, e.g. `Movie Title (2020)/Movie Title (2020).mkv`. Kodi is better suited to fetching and maintaining posters/metadata than duplicating a scraper inside the ripping container.
- This script saves `disc-info.json` and `rip-info.json`; it does not download cover art.
- The upstream `dvd_rip` shell script is patched during image build to add VA-API frame upload and a QP setting. This patch should be tested with your FFmpeg build before unattended use.

## 1. Check the host devices

```bash
ls -l /dev/sr0 /dev/dri
vainfo --display drm --device /dev/dri/renderD128
```

The host should have the Intel `i915` kernel driver loaded and a working legacy VA-API driver for HD Graphics 4000. If `vainfo` cannot initialize on the host, fix that before testing the container.

## 2. Adjust paths

Edit `compose.yaml` and change `/srv/media/Movies` to the actual Movies folder Kodi scans. Keep `./work` on a filesystem with sufficient temporary space.

## 3. Build and start with rootful Podman

```bash
mkdir -p work
sudo podman compose -f compose.yaml up -d --build
sudo podman logs -f dvd-ripper
```

Depending on your installation, the compose command may be `podman-compose` instead of `podman compose`.

## 4. Inspect logs and metadata

```bash
sudo podman logs -f dvd-ripper
cat /srv/media/Movies/<volume-label>/disc-info.json
```

Per-job logs are stored under `./work/logs/`.

## Configuration

- `DVD_DEVICE`: optical device, default `/dev/sr0`
- `OUTPUT_DIR`: output media path inside container, default `/media`
- `WORK_DIR`: logs and temporary files, default `/work`
- `VIDEO_ENCODER`: defaults to `h264_vaapi`; set to `libx264` to use CPU encoding
- `VAAPI_DEVICE`: defaults to `/dev/dri/renderD128`
- `VAAPI_QP`: hardware-encoder quality value; default `22`
- `POLL_SECONDS`: polling interval, default `5`

## Current behavior

1. Polls `dvd_drive_status` until media is present.
2. Probes with `dvd_info`; non-DVD media is ignored until ejected.
3. Saves disc information and uses the volume label as a provisional folder name.
4. Calls the upstream `dvd_rip` script, selecting the longest title by default.
5. Validates the output and renames the partial MKV only on success.
6. Waits for the disc to be removed before checking again.
