#!/usr/bin/env bash
pic_dir="$HOME/Downloads"
ts="$(date +'%Y-%m-%d_%H-%M-%S')"
filename="$pic_dir/screenshot-$ts.png"
grim -g "$(slurp)" "$filename"
notify-send -t 4000 "Region screenshot taken:" "$filename"
