 A concurrent video downloader that downloads private and embedded Vimeo videos.
 
## Usage

```sh
python vimeo-private-video-dl.py "JSON_Playlist_URL" "output_file_name"
```
you need to pass output name with video extension example .ts, .mkv, .mp4

```To get the Vimeo JSON playlist, open your browser and press F12. Switch to the Network tab then load the video page. In the filter box, type "playlist". Right-click on that request, copy the value plus then click Copy URL.```

## Screenshot

<img width="833" height="872" alt="Screenshot (19)" src="https://github.com/user-attachments/assets/e0018e3f-812d-4ed9-9bcb-a51cf2acafb3" />

## prerequisites

+ Python
+ FFmpeg

## Installation

+ Install the requirements: ```pip install -r requirements.txt```

## Windows Guide

To use this tool download FFmpeg from [https://www.gyan.dev/ffmpeg/builds/](https://www.gyan.dev/ffmpeg/builds/ffmpeg-git-essentials.7z). After downloading, extract the archive, open the extracted folder and go to the /bin/ directory. Copy ffmpeg.exe, ffprobe.exe but also ffplay.exe into your Python script folder then run the Python script.

## Linux Guide

Install ffmpeg using  ```apt install ffmpeg```

## VideoHelp Forum

VideoHelp Forum Thread: https://forum.videohelp.com/threads/419581-Vimeo-Private-Embed-Video-Downloader

