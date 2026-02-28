#!/usr/bin/env bash
recording_dir="$HOME/Downloads"
ts="$(date +'%Y-%m-%d_%H-%M-%S')"
filename="$recording_dir/recording-$ts.mp4"
echo "$filename" > "$recording_dir/.last_recording_filename"
wf-recorder -f "$filename" &
notify-send -t 4000 "Screen recording started:" "$filename"
