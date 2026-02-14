#!/bin/sh
set -e

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <youtube-music-url>"
    exit 1
fi

URL="$1"
MUSIC_DIR="/home/nix/git/monorepo/data/music"
NIX_GROUP="$(id -gn nix 2>/dev/null || true)"

if [ -n "$NIX_GROUP" ]; then
    if ! install -d -m 0755 -o nix -g "$NIX_GROUP" "$MUSIC_DIR"; then
        echo "Failed to create $MUSIC_DIR with nix ownership"
        exit 1
    fi
else
    if ! install -d -m 0755 -o nix "$MUSIC_DIR"; then
        echo "Failed to create $MUSIC_DIR with nix ownership"
        exit 1
    fi
fi

machinectl shell wireguard /bin/sh -c "yt-dlp -x --audio-format mp3 --audio-quality 0 \
    --embed-metadata --embed-thumbnail \
    --parse-metadata 'playlist_index:%(track_number)s' \
    --parse-metadata 'release_year:%(meta_date)s' \
    --convert-thumbnails jpg \
    --ppa \"EmbedThumbnail+ffmpeg_o:-c:v mjpeg -vf \\\"crop='if(gt(ih,iw),iw,ih)':'if(gt(iw,ih),ih,iw)'\\\"\" \
    -o '$MUSIC_DIR/%(artist)s %(album)s %(playlist_index)s - %(title)s.%(ext)s' \
    '$URL'"
