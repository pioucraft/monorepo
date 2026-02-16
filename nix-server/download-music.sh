#!/bin/sh
set -e

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <youtube-music-url>"
    exit 1
fi

URL="$1"
MUSIC_DIR="/home/nix/git/monorepo/data/music"
mkdir -p $MUSIC_DIR && chown -R nix $MUSIC_DIR


nixos-container run wireguard -- /bin/sh -c "yt-dlp -x --audio-format mp3 --audio-quality 0 \
    --embed-metadata --embed-thumbnail \
    --parse-metadata 'playlist_index:%(track_number)s' \
    --convert-thumbnails jpg \
    --ppa \"EmbedThumbnail+ffmpeg_o:-c:v mjpeg -vf \\\"crop='if(gt(ih,iw),iw,ih)':'if(gt(iw,ih),ih,iw)'\\\"\" \
    --cookies /home/nix/git/monorepo/nix-server/www.youtube.com_cookies.txt \
    -o '$MUSIC_DIR/%(album)s/%(artist)s %(album)s %(playlist_index)s - %(title)s.%(ext)s' \
    '$URL'"
chown -R nix $MUSIC_DIR

