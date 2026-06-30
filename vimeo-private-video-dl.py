import requests
import subprocess
import os
import shutil
from concurrent.futures import ThreadPoolExecutor, as_completed
import time
import base64
import sys
import argparse
import platform

def select_highest_quality(data: dict[str, object], track_type: str) -> dict[str, object]:
    tracks = data[track_type]
    if track_type == "video":
        return max(tracks, key=lambda x: x.get("height", 0))
    elif track_type == "audio":
        return max(tracks, key=lambda x: x.get("bitrate", 0))
    return tracks[0]

def run_command_realtime(video_track: str, audio_track: str, final_output: str) -> None:
    print("FFmpeg processing file")
    sys.stdout.flush()
    
    if platform.system() == "Windows":
        video_short = os.path.abspath(video_track)
        audio_short = os.path.abspath(audio_track)
        output_short = os.path.abspath(final_output)
        
        cmd = [
            "ffmpeg", "-y",
            "-i", video_short,
            "-i", audio_short,
            "-c", "copy",
            output_short
        ]
        result = subprocess.run(cmd, capture_output=True, text=True, encoding='utf-8', errors='ignore')
    else:

        cmd = f'ffmpeg -y -i "{video_track}" -i "{audio_track}" -c copy "{final_output}"'
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    
    if result.returncode != 0:
        print(f"FFmpeg error: {result.stderr}")
        print(f"Command was: {' '.join(result.args) if isinstance(result.args, list) else cmd}")
    else:
        print("FFmpeg mux complete")

def save_init_segment(init_segment_b64: str, output_dir: str, prefix: str) -> str:
    init_data = base64.b64decode(init_segment_b64)
    init_path = os.path.join(output_dir, f"{prefix}_init_segment.mp4")
    with open(init_path, 'wb') as f:
        f.write(init_data)
    return init_path

def download_segment(segment_url: str, filename: str, headers: dict[str, str]) -> tuple[bool, float]:
    try:
        resp = requests.get(segment_url, headers=headers, stream=True, timeout=20)
        if resp.status_code == 200:
            with open(filename, 'wb') as f:
                for chunk in resp.iter_content(8192):
                    f.write(chunk)
            size_mb = os.path.getsize(filename) / 1024 / 1024
            return True, size_mb
        return False, 0.0
    except Exception:
        return False, 0.0


def download_segment_with_retry(
    segment_url: str,
    filename: str,
    headers: dict[str, str],
    retries: int = 3,
    retry_delay: float = 1.0,
) -> tuple[bool, float]:
    attempt = 0
    while attempt <= retries:
        success, size_mb = download_segment(segment_url, filename, headers)
        if success:
            return True, size_mb
        attempt += 1
        if attempt <= retries:
            time.sleep(retry_delay)
    return False, 0.0

def cleanup_temp_files(output_dir: str, prefix: str) -> None:
    for file in os.listdir(output_dir):
        if file.startswith(prefix) and ('_init_segment' in file or '_seg_' in file):
            os.remove(os.path.join(output_dir, file))

def binary_merge_all(init_path: str, segments_dir: str, prefix: str, output_path: str) -> None:
    segments = sorted([f for f in os.listdir(segments_dir) if f.startswith(prefix + '_seg_')])
    
    with open(output_path, 'wb') as final_file:
        with open(init_path, 'rb') as init_f:
            final_file.write(init_f.read())
        
        for seg_file in segments:
            seg_path = os.path.join(segments_dir, seg_file)
            with open(seg_path, 'rb') as seg_f:
                final_file.write(seg_f.read())

def process_track(
    data: dict[str, object],
    track_type: str,
    playlist_url: str,
    output_dir: str,
    max_workers: int = 24,
) -> str:
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:145.0) Gecko/20100101 Firefox/145.0"
    }
    
    selected_track = select_highest_quality(data, track_type)
    init_segment_b64 = selected_track["init_segment"]
    track_id = selected_track["id"]
    prefix = f"{track_id}_{track_type}"
    
    print(f"\n{'='*50}")
    print(f"Processing {track_type.upper()}: {track_id}")
    
    init_path = save_init_segment(init_segment_b64, output_dir, prefix)
    base_path = playlist_url.split('/v2/')[0] + '/v2/range/prot/'
    
    all_segments: list[tuple[str, str]] = []
    for i, segment in enumerate(selected_track["segments"]):
        full_url = base_path + segment["url"]
        filename = os.path.join(output_dir, f"{prefix}_seg_{i:04d}.mp4")
        all_segments.append((full_url, filename))
    
    total = len(all_segments)
    
    start_time = time.time()
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        futures = [
            executor.submit(download_segment_with_retry, url, fn, headers)
            for url, fn in all_segments
        ]
        
        completed = 0
        success = 0
        total_mb = 0.0
        for future in as_completed(futures):
            success_seg, size_mb = future.result()
            if success_seg:
                success += 1
                total_mb += size_mb
            completed += 1
            elapsed = time.time() - start_time
            speed = (total_mb / elapsed) if elapsed > 0 else 0.0
            print(f" {success}/{completed}/{total} | {total_mb:.1f}MB | {speed:.1f}MB/sec", end='\r')
    
    print()

    if success != total:
        cleanup_temp_files(output_dir, prefix)
        raise RuntimeError(f"Failed to download all {track_type} segments ({success}/{total})")

    output_track = os.path.join(output_dir, f"{prefix}_FULL.mp4")
    binary_merge_all(init_path, output_dir, prefix, output_track)
    cleanup_temp_files(output_dir, prefix)
    
    return output_track

def download_video_audio_complete(
    playlist_url: str,
    output_filename: str,
    max_workers: int = 24,
) -> None:
    # tmp folder
    script_dir = os.path.dirname(os.path.abspath(__file__))
    tmp_dir = os.path.join(script_dir, "tmp")
    os.makedirs(tmp_dir, exist_ok=True)
    
    print("Fetching playlist...")
    headers = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:145.0) Gecko/20100101 Firefox/145.0"}
    resp = requests.get(playlist_url, headers=headers)
    resp.raise_for_status()
    data = resp.json()
    
    # Download and process video/audio
    video_track = process_track(data, "video", playlist_url, tmp_dir, max_workers)
    audio_track = process_track(data, "audio", playlist_url, tmp_dir, max_workers)
    
    final_output = os.path.join(script_dir, output_filename)
    
    #FFmpeg with direct file paths
    run_command_realtime(video_track, audio_track, final_output)
    
    # Clean up temp files
    try:
        os.remove(video_track)
        os.remove(audio_track)
        shutil.rmtree(tmp_dir)
    except OSError as e:
        print(f"Cleanup warning: {e}")

def main() -> None:
    parser = argparse.ArgumentParser(description="Download Vimeo playlist video/audio segments")
    parser.add_argument("playlist_url", help="Vimeo JSON playlist URL")
    parser.add_argument("output_filename", help="Output filename (video.mp4)")
    parser.add_argument("--workers", type=int, default=24, help="Maximum concurrent segment downloads")
    
    args = parser.parse_args()
    
    download_video_audio_complete(
        playlist_url=args.playlist_url,
        output_filename=args.output_filename,
        max_workers=args.workers,
    )

if __name__ == "__main__":
    main()
