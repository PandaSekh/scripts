#!/bin/bash
#
# compressor.sh - Compress video files using FFmpeg with H.265 encoding.
#
# Author: Alessio Franceschi
# License: MIT
#
# Description:
# This script loops through all common video formats in the current directory,
# converts them to H.265 (HEVC) with AAC audio, and replaces the original file
# with the compressed version. It ensures a balance between quality and file size.
#
# Usage:
# 1. Place the script in /usr/local/bin/ (or ~/bin/ for personal use).
# 2. Make it executable: chmod +x /usr/local/bin/compressor
# 3. Run it in any folder containing videos: compressor
#
# Dependencies:
# - FFmpeg (install with `brew install ffmpeg` on macOS)
#
# Supported formats: mp4, mkv, webm, avi, mov, flv, wmv, m4v, ts, webp
#

# Loop through all video files in the current directory
for f in *.{mp4,mkv,webm,avi,mov,flv,wmv,m4v,ts,webp}; do
    [ -f "$f" ] || continue  # Skip if file doesn't exist (handles empty matches)

    echo "Processing: $f"

    # Convert video to H.265 (HEVC) and replace original file.
    ffmpeg -y -i "$f" -c:v libx265 -crf 25 -preset medium -c:a aac -b:a 128k "${f%.*}_temp.mp4" && mv "${f%.*}_temp.mp4" "$f"

    echo "Finished: $f"
done

echo "All videos have been processed!"
