import requests
import subprocess
import os
import shutil
from urllib.parse import urlparse, urljoin
from concurrent.futures import ThreadPoolExecutor, as_completed
import time
import base64
import sys
import argparse
import platform

def resolve_segment_url(playlist_url, root_base_url, track_base_url, segment_url):
    """
    Resolves relative segment URLs against the playlist URL, root base_url, and track base_url.
    """
    if segment_url.startswith("http://") or segment_url.startswith("https://"):
        return segment_url
    
    base = playlist_url
    if root_base_url:
        base = urljoin(base, root_base_url)
        if not base.endswith('/'):
            base += '/'
            
    if track_base_url:
        base = urljoin(base, track_base_url)
        if not base.endswith('/'):
            base += '/'
            
    return urljoin(base, segment_url)

def select_highest_quality(data, track_type):
    tracks = data.get(track_type, [])
    if not tracks:
        return None
    if track_type == "video":
        return max(tracks, key=lambda x: x.get("height", 0))
    elif track_type == "audio":
        return max(tracks, key=lambda x: x.get("bitrate", 0))
    return tracks[0]

def run_command_realtime(video_track, audio_track, final_output, verbose=False):
    print("FFmpeg processing file")
    sys.stdout.flush()
    
    if audio_track and os.path.exists(audio_track):
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
            if verbose:
                print(f"[VERBOSE] Running command: {' '.join(cmd)}")
            result = subprocess.run(cmd, capture_output=True, text=True, encoding='utf-8', errors='ignore')
        else:
            cmd = f'ffmpeg -y -i "{video_track}" -i "{audio_track}" -c copy "{final_output}"'
            if verbose:
                print(f"[VERBOSE] Running command: {cmd}")
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    else:
        if platform.system() == "Windows":
            video_short = os.path.abspath(video_track)
            output_short = os.path.abspath(final_output)
            cmd = [
                "ffmpeg", "-y",
                "-i", video_short,
                "-c", "copy",
                output_short
            ]
            if verbose:
                print(f"[VERBOSE] Running command: {' '.join(cmd)}")
            result = subprocess.run(cmd, capture_output=True, text=True, encoding='utf-8', errors='ignore')
        else:
            cmd = f'ffmpeg -y -i "{video_track}" -c copy "{final_output}"'
            if verbose:
                print(f"[VERBOSE] Running command: {cmd}")
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True)

    if verbose or result.returncode != 0:
        if result.stdout:
            print(f"[VERBOSE] FFmpeg stdout:\n{result.stdout}")
        if result.stderr:
            print(f"[VERBOSE] FFmpeg stderr:\n{result.stderr}")

    if result.returncode != 0:
        print(f"FFmpeg error: {result.stderr}")
        print(f"Command was: {' '.join(result.args) if isinstance(result.args, list) else cmd}")
    else:
        print("FFmpeg mux complete")

def save_init_segment(init_segment_b64, output_dir, prefix):
    init_data = base64.b64decode(init_segment_b64)
    init_path = os.path.join(output_dir, f"{prefix}_init_segment.mp4")
    with open(init_path, 'wb') as f:
        f.write(init_data)
    return init_path

def download_segment(segment_url, filename, headers, verbose=False):
    try:
        resp = requests.get(segment_url, headers=headers, stream=True, timeout=20)
        if resp.status_code == 200:
            with open(filename, 'wb') as f:
                for chunk in resp.iter_content(8192):
                    f.write(chunk)
            size_mb = os.path.getsize(filename) / 1024 / 1024
            return True, size_mb, None
        else:
            err_msg = f"HTTP {resp.status_code} ({resp.reason})"
            if verbose:
                print(f"\n[VERBOSE ERROR] Segment download failed: {segment_url} -> {err_msg}")
            return False, 0, err_msg
    except Exception as e:
        err_msg = f"Exception {type(e).__name__}: {e}"
        if verbose:
            print(f"\n[VERBOSE ERROR] Exception downloading segment: {segment_url} -> {err_msg}")
        return False, 0, err_msg

def cleanup_temp_files(output_dir, prefix):
    for file in os.listdir(output_dir):
        if file.startswith(prefix) and ('_init_segment' in file or '_seg_' in file):
            try:
                os.remove(os.path.join(output_dir, file))
            except OSError:
                pass

def binary_merge_all(init_path, segments_dir, prefix, output_path):
    segments = sorted([f for f in os.listdir(segments_dir) if f.startswith(prefix + '_seg_')])
    
    with open(output_path, 'wb') as final_file:
        if init_path and os.path.exists(init_path):
            with open(init_path, 'rb') as init_f:
                final_file.write(init_f.read())
        
        for seg_file in segments:
            seg_path = os.path.join(segments_dir, seg_file)
            with open(seg_path, 'rb') as seg_f:
                final_file.write(seg_f.read())

def process_track(data, track_type, playlist_url, output_dir, max_workers=24, verbose=False):
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:145.0) Gecko/20100101 Firefox/145.0"
    }
    
    selected_track = select_highest_quality(data, track_type)
    if not selected_track:
        print(f"\n[INFO] No {track_type} track found in playlist.")
        return None

    track_id = selected_track.get("id", "unknown_id")
    prefix = f"{track_id}_{track_type}"
    
    print(f"\n{'='*50}")
    print(f"Processing {track_type.upper()}: {track_id}")
    if verbose:
        if track_type == "video":
            print(f"[VERBOSE] Track specs: {selected_track.get('width')}x{selected_track.get('height')}, bitrate: {selected_track.get('bitrate')}, fps: {selected_track.get('fps')}")
        else:
            print(f"[VERBOSE] Track specs: bitrate {selected_track.get('bitrate')}, sample rate {selected_track.get('sample_rate')}, channels {selected_track.get('channels')}")
        print(f"[VERBOSE] Track base_url: '{selected_track.get('base_url')}'")

    init_segment_b64 = selected_track.get("init_segment")
    init_path = ""
    if init_segment_b64:
        init_path = save_init_segment(init_segment_b64, output_dir, prefix)
    elif verbose:
        print(f"[VERBOSE] No init_segment for {track_type}")

    root_base_url = data.get("base_url", "")
    track_base_url = selected_track.get("base_url", "")

    all_segments = []
    for i, segment in enumerate(selected_track.get("segments", [])):
        full_url = resolve_segment_url(playlist_url, root_base_url, track_base_url, segment["url"])
        filename = os.path.join(output_dir, f"{prefix}_seg_{i:04d}.mp4")
        all_segments.append((full_url, filename))
    
    if verbose and all_segments:
        print(f"[VERBOSE] Sample segment URL: {all_segments[0][0]}")

    total = len(all_segments)
    if total == 0:
        print(f"[INFO] Track has 0 segments.")
        return None

    start_time = time.time()
    failed_errors = []

    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        futures = [executor.submit(download_segment, url, fn, headers, verbose) for url, fn in all_segments]
        
        completed = success = total_mb = 0
        for future in as_completed(futures):
            success_seg, size_mb, err_msg = future.result()
            if success_seg:
                success += 1
                total_mb += size_mb
            else:
                if err_msg:
                    failed_errors.append(err_msg)
            completed += 1
            elapsed = time.time() - start_time
            speed = (total_mb / elapsed) if elapsed > 0 else 0
            print(f" {success}/{completed}/{total} | {total_mb:.1f}MB | {speed:.1f}MB/sec", end='\r')
    
    print()  # newline after progress counter

    if failed_errors:
        print(f"\n[WARNING] {len(failed_errors)}/{total} segments failed for {track_type.upper()}. First error: {failed_errors[0]}")

    output_track = os.path.join(output_dir, f"{prefix}_FULL.mp4")
    binary_merge_all(init_path, output_dir, prefix, output_track)
    cleanup_temp_files(output_dir, prefix)
    
    return output_track

def download_video_audio_complete(playlist_url, output_filename, max_workers=24, verbose=False):
    script_dir = os.path.dirname(os.path.abspath(__file__))
    tmp_dir = os.path.join(script_dir, "tmp")
    os.makedirs(tmp_dir, exist_ok=True)
    
    print("Fetching playlist...")
    if verbose:
        print(f"[VERBOSE] Requesting playlist URL: {playlist_url}")

    headers = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:145.0) Gecko/20100101 Firefox/145.0"}
    resp = requests.get(playlist_url, headers=headers)
    
    if verbose:
        print(f"[VERBOSE] Playlist response status: {resp.status_code}")
    
    resp.raise_for_status()
    data = resp.json()
    
    if verbose:
        print(f"[VERBOSE] Root base_url: '{data.get('base_url')}'")
        video_count = len(data.get("video", []))
        audio_count = len(data.get("audio", []))
        print(f"[VERBOSE] Found {video_count} video track(s) and {audio_count} audio track(s).")

    # Download and process video/audio
    video_track = process_track(data, "video", playlist_url, tmp_dir, max_workers, verbose=verbose)
    audio_track = process_track(data, "audio", playlist_url, tmp_dir, max_workers, verbose=verbose)
    
    if not video_track and not audio_track:
        print("Error: Failed to download both video and audio tracks.")
        return

    final_output = os.path.join(script_dir, output_filename)
    
    # FFmpeg direct file paths
    run_command_realtime(video_track, audio_track, final_output, verbose=verbose)
    
    # Clean up temp files
    try:
        if video_track and os.path.exists(video_track):
            os.remove(video_track)
        if audio_track and os.path.exists(audio_track):
            os.remove(audio_track)
        if os.path.exists(tmp_dir):
            shutil.rmtree(tmp_dir)
    except OSError as e:
        print(f"Cleanup warning: {e}")

def main():
    parser = argparse.ArgumentParser(description="Download Vimeo playlist video/audio segments")
    parser.add_argument("playlist_url", help="Vimeo JSON playlist URL")
    parser.add_argument("output_filename", help="Output filename (video.mp4)")
    parser.add_argument("-v", "--verbose", action="store_true", help="Enable verbose logging output")
    
    args = parser.parse_args()
    
    download_video_audio_complete(
        playlist_url=args.playlist_url,
        output_filename=args.output_filename,
        verbose=args.verbose
    )

if __name__ == "__main__":
    main()
