 A concurrent video downloader that downloads private and embedded Vimeo videos.
 
## Usage

```sh
python vimeo-private-video-dl.py "JSON_Playlist_URL" "output_file_name"
```
you need to pass output name with video extension example .ts, .mkv, .mp4

```To get the Vimeo JSON playlist, open your browser and press F12. Switch to the Network tab, then load the video page. In the filter box, search for “playlist”. Right click on that request then copy value and then click on Copy URL.```

## Screenshot


## prerequisites

+ Python
+ FFmpeg

## Installation

+ Install the requirements: ```pip install -r requirements.txt```

## Windows Guide

In order to use this tool, you need to download FFmpeg tool link: [https://www.gyan.dev/ffmpeg/builds/](https://www.gyan.dev/ffmpeg/builds/ffmpeg-git-essentials.7z). After downloading, extract the archive, then open the extracted folder and navigate to the /bin/ directory. Copy the files ffmpeg.exe, ffprobe.exe, and ffplay.exe into your Python script folder, and then run the python script.

## Linux Guide

Install ffmpeg using  ```apt install ffmpeg```

## VideoHelp Forum

VideoHelp Forum Thread: https://forum.videohelp.com/threads/419581-Vimeo-Private-Embed-Video-Downloader

