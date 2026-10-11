# Installing apps on antiX

[Русский](README.md) | **English**

Run the scripts without `sudo`; they ask for your password when needed.
The scripts' messages are in Russian.

## Zoom — `install-zoom.sh`

```bash
bash install-zoom.sh            # install or update
bash install-zoom.sh --remove   # remove
```

Downloads the official package from zoom.us (about 200 MB) and installs it with apt.
At the end it checks that PipeWire/PulseAudio is running: without it Zoom may have no sound.
On a low-end laptop, meetings are lighter in the browser: https://app.zoom.us/wc

## Throne — `install-throne.sh`

Proxy client (formerly Nekoray): https://github.com/throneproj/Throne

```bash
bash install-throne.sh          # latest version
bash install-throne.sh 1.3.2    # specific version
bash install-throne.sh --remove # remove
```

Installs to `/opt/Throne` and adds a menu entry. On first launch, add a server and turn on
"System proxy". TUN mode needs administrator rights; if it won't turn on, use "System proxy".
