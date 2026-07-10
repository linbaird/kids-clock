#!/usr/bin/env python3
import json, subprocess, time, os
from datetime import datetime

WAKE_LOCK     = '/tmp/screen_wake_lock'
WAKE_DURATION = 300  # 5 minutes in seconds
DRM_STATUS    = '/sys/class/drm/card0-HDMI-A-1/status'

with open('/home/linbaird/kids-clock/config.json') as f:
    config = json.load(f)

now      = datetime.now()
now_mins = now.hour * 60 + now.minute

# Find current zone
current = None
for zone in config['schedule']:
    start = zone['startH'] * 60 + zone['startM']
    end   = zone['endH']   * 60 + zone['endM']
    if start <= now_mins < end:
        current = zone
        break

is_night = current and current.get('isNight', False)

# Check wake lock
wake_active = False
if os.path.exists(WAKE_LOCK):
    with open(WAKE_LOCK) as f:
        try:
            touched_at = float(f.read().strip())
            if time.time() - touched_at < WAKE_DURATION:
                wake_active = True
        except:
            pass

# Control screen
if is_night and not wake_active:
    subprocess.run(['sudo', 'tee', DRM_STATUS],
                   input=b'off', stdout=subprocess.DEVNULL)
else:
    subprocess.run(['sudo', 'tee', DRM_STATUS],
                   input=b'on', stdout=subprocess.DEVNULL)