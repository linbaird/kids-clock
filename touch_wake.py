#!/usr/bin/env python3
import subprocess, struct, time, os

# Waveshare touchscreen device
TOUCH_DEVICE = '/dev/input/event2'
WAKE_LOCK    = '/tmp/screen_wake_lock'

# Read touch events and update wake lock file
with open(TOUCH_DEVICE, 'rb') as f:
    while True:
        # Each input event is 24 bytes on ARM
        data = f.read(24)
        if data:
            # Touch detected — write current timestamp to wake lock
            with open(WAKE_LOCK, 'w') as lock:
                lock.write(str(time.time()))
            # Turn screen on immediately
            subprocess.run(['vcgencmd', 'display_power', '1'])