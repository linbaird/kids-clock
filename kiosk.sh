#!/bin/bash
# Kiosk launcher — started once per session from ~/.config/labwc/autostart
# Waits for the compositor to be ready, then launches Chromium in kiosk mode.
#
# NOTE: Do not add a restart loop here. On this Pi (labwc/Wayland, Pi 3B+),
# only the FIRST Chromium launch per session reliably maps a window;
# relaunches start but never appear. If Chromium dies, reboot instead.

until wlr-randr >/dev/null 2>&1; do sleep 1; done
sleep 2

chromium \
  --user-data-dir=/home/linbaird/.config/kiosk-profile \
  --ozone-platform=wayland --disable-gpu \
  --noerrdialogs --disable-infobars --no-first-run \
  --disable-session-crashed-bubble \
  --kiosk file:///home/linbaird/kids-clock/kids-clock.html