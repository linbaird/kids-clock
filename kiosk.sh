#!/bin/bash
# Kiosk launcher — X11/Openbox session.
#
# HISTORY: This originally ran under labwc/Wayland, where Chromium's
# ozone-wayland backend failed to reliably map a window on this
# Pi 3B+ (32-bit trixie). Session switched to X11 via raspi-config.
# Do not switch back to Wayland without thorough retesting.
#
# The clock is now served by server.py (systemd: kids-clock-server)
# so the page can read config.json live. --autoplay-policy is
# required for the alarm to make sound without a user gesture.

# Wait for the X server to be ready
until DISPLAY=:0 xset q >/dev/null 2>&1; do sleep 1; done

# Wait for server.py to be up (max ~30s, then launch anyway —
# the page has built-in fallbacks and Chromium will retry)
for i in $(seq 1 30); do
  curl -sf http://localhost:8000/api/config >/dev/null && break
  sleep 1
done
sleep 2

DISPLAY=:0 chromium \
  --user-data-dir=/home/linbaird/.config/kiosk-profile \
  --ozone-platform=x11 --disable-gpu \
  --noerrdialogs --disable-infobars --no-first-run \
  --disable-session-crashed-bubble \
  --autoplay-policy=no-user-gesture-required \
  --kiosk http://localhost:8000/kids-clock.html