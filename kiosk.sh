#!/bin/bash
# Kiosk launcher — X11/Openbox session.
#
# HISTORY: This originally ran under labwc/Wayland, where Chromium's
# ozone-wayland backend failed to reliably map a window on this
# Pi 3B+ (32-bit trixie): the process ran fine but no window ever
# appeared. The compositor was healthy (other apps mapped instantly);
# the fault was Chromium-specific. Session switched to X11 via
# raspi-config (Advanced Options > Wayland > Openbox/X11).
# Do not switch back to Wayland without thorough retesting.

# Wait for the X server to be ready
until DISPLAY=:0 xset q >/dev/null 2>&1; do sleep 1; done
sleep 2

DISPLAY=:0 chromium \
  --user-data-dir=/home/linbaird/.config/kiosk-profile \
  --ozone-platform=x11 --disable-gpu \
  --noerrdialogs --disable-infobars --no-first-run \
  --disable-session-crashed-bubble \
  --kiosk file:///home/linbaird/kids-clock/kids-clock.html