#!/usr/bin/env bash
recording_dir="$HOME/Downloads"
filename="$(cat "$recording_dir/.last_recording_filename" 2>/dev/null)"
pkill wf-recorder
if [ -n "$filename" ]; then
  notify-send -t 4000 "Screen recording stopped" "$filename"
else
  notify-send -t 4000 "Screen recording stopped"
fi
