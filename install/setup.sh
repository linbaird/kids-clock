#!/bin/bash
# Kids Clock - Pi Setup Script (X11 edition)
# Run once on a fresh Raspberry Pi OS (32-bit Trixie) install.
# Usage: bash install/setup.sh
#
# IMPORTANT HISTORY: Chromium 149 cannot create windows on Pi 3
# (no window on Wayland, white window on X11) — see
# https://github.com/RPi-Distro/chromium/issues/60
# Fixed in Chromium >= 150. This script full-upgrades to get it,
# and switches the session to X11, which is the tested, working path.

set -e
echo "🕐 Kids Clock Setup Starting..."

USER_HOME="/home/$(whoami)"
CLOCK_DIR="$USER_HOME/kids-clock"

# ── 1. System update (REQUIRED: brings Chromium to >= 150) ──
echo "📦 Updating system (this fetches the fixed Chromium build)..."
sudo apt-get update -q
sudo apt-get full-upgrade -y
sudo apt-get install -y unclutter evtest

# ── 2. Switch session to X11 (Chromium kiosk is proven here) ──
echo "🖥  Switching session to X11/Openbox..."
sudo raspi-config nonint do_wayland W1

# ── 3. Clone or update repo ─────────────────────────────
if [ ! -d "$CLOCK_DIR" ]; then
  echo "📥 Cloning kids-clock repo..."
  git clone https://github.com/linbaird/kids-clock.git "$CLOCK_DIR"
else
  echo "📁 Repo already exists, pulling latest..."
  cd "$CLOCK_DIR" && git pull --ff-only
fi
chmod +x "$CLOCK_DIR/kiosk.sh"

# ── 4. X11 session autostart → kiosk.sh ─────────────────
echo "🚀 Configuring kiosk autostart..."
mkdir -p "$USER_HOME/.config/lxsession/LXDE-pi"
cat > "$USER_HOME/.config/lxsession/LXDE-pi/autostart" << EOF
@xset s off
@xset -dpms
@xset s noblank
@$CLOCK_DIR/kiosk.sh
EOF

# ── 5. Sudoers rule for screen control (used by screen.py) ──
# TODO: replace broad tee rule with a dedicated wrapper script
echo "🔒 Configuring sudoers..."
echo "$(whoami) ALL=(ALL) NOPASSWD: /usr/bin/tee /sys/class/drm/card0-HDMI-A-1/status" | \
  sudo tee /etc/sudoers.d/screen-control

# ── 6. Cron: auto git pull (ff-only so a dirty tree can't wedge it) ──
echo "⏰ Setting up cron..."
( crontab -l 2>/dev/null | grep -v kids-clock ;
  echo "*/15 * * * * cd $CLOCK_DIR && git pull --ff-only >> /tmp/gitpull.log 2>&1" ) | crontab -

# screen.py deliberately NOT scheduled yet — re-enable once kiosk
# is verified stable:
#   echo "* * * * * python3 $CLOCK_DIR/screen.py"

echo "✅ Setup complete! Rebooting in 5 seconds..."
sleep 5
sudo reboot