# kids-clock
# Kids Clock - Setup Instructions

## Fresh Pi Setup
1. Flash Raspberry Pi OS (32-bit) with Raspberry Pi Imager
2. Set hostname: clockpi, enable SSH, set WiFi credentials
3. Boot Pi and SSH in: `ssh linbaird@clockpi.local`
4. Run: `bash <(curl -s https://raw.githubusercontent.com/linbaird/kids-clock/main/install/setup.sh)`

## What the script does
- Installs dependencies (unclutter, evtest)
- Clones the repo to ~/kids-clock
- Hides the wf-panel taskbar (height=0)
- Configures labwc autostart for Wayland kiosk mode
- Sets up sudoers rule for screen control
- Sets up cron jobs for screen sleep and auto git pull

## Manual commands
- Start clock manually: `WAYLAND_DISPLAY=wayland-0 XDG_RUNTIME_DIR=/run/user/1000 chromium --ozone-platform=wayland --kiosk file:///home/linbaird/kids-clock/kids-clock.html &`
- Pull latest: `cd ~/kids-clock && git pull`
- Screen off: `echo "off" | sudo tee /sys/class/drm/card0-HDMI-A-1/status`
- Screen on: `echo "on" | sudo tee /sys/class/drm/card0-HDMI-A-1/status`

## Known issues
- Chromium must be launched with --ozone-platform=wayland (Wayland session, not X11)
- Touch wake has ~1 min delay via cron - working on instant solution
- GPU errors in terminal are harmless