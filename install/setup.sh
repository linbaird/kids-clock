#!/bin/bash
# Kids Clock - Pi Setup Script
# Run once on a fresh Raspberry Pi OS install
# Usage: bash install/setup.sh

set -e
echo "🕐 Kids Clock Setup Starting..."

# ── Variables ──────────────────────────────────────────
USER_HOME="/home/$(whoami)"
CLOCK_DIR="$USER_HOME/kids-clock"

# ── 1. System update ───────────────────────────────────
echo "📦 Updating system..."
sudo apt-get update -q
sudo apt-get install -y unclutter evtest

# ── 2. Clone repo if not already there ─────────────────
if [ ! -d "$CLOCK_DIR" ]; then
  echo "📥 Cloning kids-clock repo..."
  git clone https://github.com/linbaird/kids-clock.git "$CLOCK_DIR"
else
  echo "📁 Repo already exists, pulling latest..."
  cd "$CLOCK_DIR" && git pull
fi

# ── 3. Hide the panel ──────────────────────────────────
echo "🔧 Configuring panel..."
mkdir -p "$USER_HOME/.config/wf-panel-pi"
cat > "$USER_HOME/.config/wf-panel-pi/wf-panel-pi.ini" << 'EOF'
[panel]
height=0
EOF

# ── 4. Labwc autostart ─────────────────────────────────
echo "🚀 Configuring kiosk autostart..."
mkdir -p "$USER_HOME/.config/labwc"
cat > "$USER_HOME/.config/labwc/autostart" << 'EOF'
# Hide cursor
unclutter -idle 0.5 -root &

# Touch wake listener
sudo python3 /home/linbaird/kids-clock/touch_wake.py &

# Launch clock in kiosk mode
WAYLAND_DISPLAY=wayland-0 XDG_RUNTIME_DIR=/run/user/1000 chromium \
  --ozone-platform=wayland \
  --noerrdialogs \
  --disable-infobars \
  --no-first-run \
  --disable-session-crashed-bubble \
  --kiosk \
  file:///home/linbaird/kids-clock/kids-clock.html &
EOF

# ── 5. Sudoers rule for screen control ─────────────────
echo "🔒 Configuring sudoers..."
echo "$(whoami) ALL=(ALL) NOPASSWD: /usr/bin/tee /sys/class/drm/card0-HDMI-A-1/status" | \
  sudo tee /etc/sudoers.d/screen-control

# ── 6. Cron jobs ───────────────────────────────────────
echo "⏰ Setting up cron jobs..."
(crontab -l 2>/dev/null; echo "* * * * * python3 /home/linbaird/kids-clock/screen.py") | crontab -

# ── 7. Auto git pull every 15 mins ─────────────────────
(crontab -l 2>/dev/null; echo "*/15 * * * * cd /home/linbaird/kids-clock && git pull") | crontab -

echo "✅ Setup complete! Rebooting in 5 seconds..."
sleep 5
sudo reboot