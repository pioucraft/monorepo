#!/usr/bin/env python3
import json
import os
import time
import urllib.parse
import urllib.request
import subprocess

BOT_TOKEN = os.environ.get("TELEGRAM_BOT_TOKEN")
CHAT_ID = os.environ.get("TELEGRAM_CHAT_ID")
MUSIC_DIR = os.environ.get("TELEGRAM_MUSIC_DIR", "/home/nix/git/monorepo/data/music")

if not BOT_TOKEN:
    raise SystemExit("TELEGRAM_BOT_TOKEN is required")

API_BASE = f"https://api.telegram.org/bot{BOT_TOKEN}"


def api_get(method, params=None):
    url = f"{API_BASE}/{method}"
    if params:
        url = f"{url}?{urllib.parse.urlencode(params)}"
    with urllib.request.urlopen(url, timeout=75) as response:
        return json.loads(response.read().decode("utf-8"))


def api_post(method, data):
    payload = urllib.parse.urlencode(data).encode("utf-8")
    request = urllib.request.Request(f"{API_BASE}/{method}", data=payload)
    with urllib.request.urlopen(request, timeout=75) as response:
        return json.loads(response.read().decode("utf-8"))


def send_message(chat_id, text):
    api_post("sendMessage", {"chat_id": chat_id, "text": text})


def yt_dlp_command(url):
    return [
        "yt-dlp",
        "-x",
        "--audio-format",
        "mp3",
        "--audio-quality",
        "0",
        "--embed-metadata",
        "--embed-thumbnail",
        "--parse-metadata",
        "playlist_index:%(track_number)s",
        "--parse-metadata",
        "release_year:%(meta_date)s",
        "--convert-thumbnails",
        "jpg",
        "--ppa",
        "EmbedThumbnail+ffmpeg_o:-c:v mjpeg -vf crop='if(gt(ih,iw),iw,ih)':'if(gt(iw,ih),ih,iw)'",
        "-o",
        f"{MUSIC_DIR}/%(artist)s %(album)s %(playlist_index)s - %(title)s.%(ext)s",
        url,
    ]


def run_download(url, chat_id):
    os.makedirs(MUSIC_DIR, exist_ok=True)
    send_message(chat_id, "Starting download…")
    process = subprocess.Popen(
        yt_dlp_command(url),
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    last_update = time.monotonic()
    output_tail = []

    if process.stdout:
        for line in process.stdout:
            cleaned = line.strip()
            if cleaned:
                output_tail.append(cleaned)
                if len(output_tail) > 6:
                    output_tail.pop(0)
            if cleaned and time.monotonic() - last_update > 45:
                send_message(chat_id, f"Still downloading…\n{cleaned}")
                last_update = time.monotonic()

    process.wait()
    if process.returncode == 0:
        send_message(chat_id, "Download finished.")
        return

    tail = "\n".join(output_tail) if output_tail else "(no output)"
    send_message(chat_id, f"Download failed:\n{tail}")


def handle_message(message):
    chat_id = str(message["chat"]["id"])
    if CHAT_ID and chat_id != str(CHAT_ID):
        return

    text = (message.get("text") or "").strip()
    if not text:
        return

    command, *rest = text.split(maxsplit=1)
    command = command.split("@")[0]
    if command in ("/start", "/help"):
        send_message(chat_id, "Use /ytmusic <url> to download YouTube Music.")
        return

    if command in ("/ytmusic", "/ytdlp"):
        if not rest:
            send_message(chat_id, "Usage: /ytmusic <url>")
            return
        run_download(rest[0], chat_id)


def main():
    offset = 0
    while True:
        try:
            updates = api_get("getUpdates", {"timeout": 60, "offset": offset})
            if not updates.get("ok"):
                time.sleep(2)
                continue

            for update in updates.get("result", []):
                offset = update["update_id"] + 1
                message = update.get("message")
                if message:
                    handle_message(message)
        except Exception:
            time.sleep(5)


if __name__ == "__main__":
    main()
