#!/bin/bash

DEEPRUN="/tmp/deep.txt" # helper file used for correct timing of the subprocesses
                        # when deleted manually all subprocesses exit "gracefully"

RUNGADGET=1 # if 1 run gadget-uvc when available and when /sys/kernel/config/usb_gadget/g1 is not initialized yet

PYPATH="/usr/bin" # adjust to your venv if you use one

VLG="/dev/video0" # uvc video device - default /dev/video0

VL1="/dev/video23" # first v4l2loopback device - receives frames sent by the deep-live-cam process
VL2="/dev/video24" # second v4l2loopback device - "$VL1" data is converted into v4l2/uvc gadget compatible format in here

# unknown if those v4l2loopback device parameters are required:
VLW=640 # default width
VLH=480 # default height
VLF=30  # default fps
VLB=8   # default buffers

# seconds to wait after $VL2 initialization before uvc-gadget ist started
UVSLEEP=3

if ! lsmod | grep -q "v4l2loopback"; then
  echo "loading v4l2loopback modules and preparing '$VL1' and '$VL2'"
  modprobe v4l2loopback devices="2" video_nr="${VL1//[![:digit:]]/},${VL2//[![:digit:]]/}" max_buffers="$VLB" max_width="$VLW" max_height="$VLH"
  v4l2loopback-ctl set-fps "$VLF" "$VL1"
  v4l2loopback-ctl set-fps "$VLF" "$VL2"
fi

if [ "$RUNGADGET" -eq 1 ] && [ -x "$(command -v gadget-uvc)" ] && [ ! -f "/sys/kernel/config/usb_gadget/g1/UDC" ]; then
  echo "starting gadget-uvc"
  gadget-uvc
fi

if [ -f "$DEEPRUN" ]; then
  echo "removing old helper file '$DEEPRUN'"
  rm "$DEEPRUN"
fi

"${PYPATH}/python3" "$(command -v get-deep-live-cam-stream.py)" &

echo "waiting for an active connection to deep-live-cam..."
while [ ! -f "$DEEPRUN" ]; do
  sleep 0.2
done

echo "starting ffmpeg converting '$VL1' into v4l compatible '$VL2'..."

ffmpeg -i "$VL1" -f v4l2 -vcodec rawvideo -pix_fmt yuyv422 "$VL2" &
FFPID="$!"

echo "'$VL2' needs to settle before uvc-gadget can launch - sleeping $UVSLEEP seconds"
sleep "$UVSLEEP"

echo "starting uvc-gadget - streaming '$VL2' to sub gadget device '$VLG'"
uvc-gadget -f 0 -o 1 -r 0 -s 1 -v "$VL2" -u "$VLG" &
UPID="$!"

echo "UPID $UPID"
echo "FFPID $FFPID"

while [ -f "$DEEPRUN" ]; do
  sleep 1
done

echo "killing UPID $UPID"
kill -9 "$UPID"
echo "killing FFPID $FFPID"
kill -9 "$FFPID"
