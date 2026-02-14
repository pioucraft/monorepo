#!/bin/sh
set -e

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <youtube-music-url>"
    exit 1
fi

URL="$1"
MUSIC_DIR="/home/nix/git/monorepo/data/music"
mkdir -p $MUSIC_DIR && sudo chown -R nix $MUSIC_DIR


sudo nixos-container run wireguard -- /bin/sh -c "yt-dlp -x --audio-format mp3 --audio-quality 0 \
    --embed-metadata --embed-thumbnail \
    --parse-metadata 'playlist_index:%(track_number)s' \
    --parse-metadata 'release_year:%(meta_date)s' \
    --convert-thumbnails jpg \
    --ppa \"EmbedThumbnail+ffmpeg_o:-c:v mjpeg -vf \\\"crop='if(gt(ih,iw),iw,ih)':'if(gt(iw,ih),ih,iw)'\\\"\" \
    -o '$MUSIC_DIR/%(artist)s %(album)s %(playlist_index)s - %(title)s.%(ext)s' \
    '$URL'"

sudo chown -R nix $MUSIC_DIR
