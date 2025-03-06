#!/bin/bash

# ==============================================================================
# Script: video_to_mp3_converter.sh
# ==============================================================================
# Description:
# This script recursively searches through the specified directory (or current
# directory if none is specified) and its subdirectories to convert all video
# files (mp4, mkv, avi, mov, webm) to MP3 audio files. After conversion, if more
# than one MP3 file exists in a folder, it merges them into a single MP3 file with
# chapter markers corresponding to the original files. The final merged file is
# saved in the same folder.
#
# Usage:
#    ./video_to_mp3_converter.sh [optional_path] [--no-merge]
#
#    optional_path: Path to directory to process (default is current directory).
#    --no-merge: If provided, merging will be skipped.
#
# Dependencies:
# - ffmpeg (and ffprobe)
#
# License:
# This script is released under the MIT License.
# ==============================================================================

# Determine parameters.
SKIP_MERGE=0
if [ "$1" = "--no-merge" ]; then
    SKIP_MERGE=1
    source_dir="."
elif [ -n "$1" ]; then
    source_dir="$1"
    if [ ! -d "$source_dir" ]; then
        echo "Error: '$source_dir' is not a valid directory."
        exit 1
    fi
else
    source_dir="."
fi

if [ "$2" = "--no-merge" ]; then
    SKIP_MERGE=1
fi

echo "Script started. Processing source directory: $source_dir"
if [ "$SKIP_MERGE" -eq 1 ]; then
    echo "Merging is disabled."
fi

# Function to convert all video files to MP3 in a specific folder.
convert_to_mp3_in_folder() {
    echo "Converting video files to MP3 in folder: $1"
    folder="$1"
    
    while IFS= read -r file; do
        echo "Converting file: $file"
        # Define output MP3 file (same basename, .mp3 extension).
        dest_file="${file%.*}.mp3"
        # Skip conversion if output file already exists.
        if [ -f "$dest_file" ]; then
            echo "Skipping conversion, output file already exists: $dest_file"
            continue
        fi
        # Convert video to MP3 using ffmpeg with best quality, reduced noise,
        # progress stats, and automatic multithreading.
        ffmpeg -nostdin -hide_banner -loglevel warning -stats -y -threads 0 \
            -i "$file" -vn -c:a libmp3lame -qscale:a 0 "$dest_file"
    done < <(find "$folder" -maxdepth 1 -type f \( -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.avi" -o -iname "*.mov" -o -iname "*.webm" \))
}

# Function to merge MP3 files in a folder into one MP3 file with chapters.
merge_mp3s_in_folder() {
    folder="$1"
    file_list="$folder/files.txt"
    chapters_file="$folder/chapters.txt"
    total_time=0
    mp3_count=0

    # Clear (or create) the file list and chapters file.
    > "$file_list"
    > "$chapters_file"

    while IFS= read -r file; do
        mp3_count=$((mp3_count + 1))
        # Escape single quotes in the filename.
        escaped_file=$(echo "$file" | sed "s/'/'\\\\''/g")
        echo "file '$escaped_file'" >> "$file_list"
        
        # Get duration (in seconds) and convert to milliseconds.
        duration=$(ffprobe -i "$file" -show_entries format=duration -v quiet -of csv="p=0")
        duration_ms=$(echo "$duration * 1000" | bc | cut -d. -f1)
        
        # Append chapter metadata.
        {
            echo ""
            echo "[CHAPTER]"
            echo "TIMEBASE=1/1000"
            echo "START=$total_time"
            total_time=$((total_time + duration_ms))
            echo "END=$total_time"
            echo "title=$(basename "$file" .mp3)"
        } >> "$chapters_file"
    done < <(find "$folder" -maxdepth 1 -type f -iname "*.mp3" | sort)

    # If there is one or zero MP3 files, skip merging and chapter addition.
    if [ "$mp3_count" -le 1 ]; then
        echo "Skipping merge and chapter addition for folder: $folder (found $mp3_count MP3 file)."
        rm -f "$file_list" "$chapters_file"
        return
    fi

    # Determine folder name.
    if [ "$folder" = "." ]; then
        folder_name=$(basename "$(pwd)")
    else
        folder_name=$(basename "$folder")
    fi

    # Place the merged output file in the same folder.
    merged_audio="$folder/${folder_name}.mp3"

    echo "Merging $mp3_count MP3 files and adding chapters in folder: $folder"
    
    ffmpeg -nostdin -hide_banner -loglevel warning -stats -y -threads 0 \
           -f concat -safe 0 -i "$file_list" -i "$chapters_file" \
           -map_metadata 1 -id3v2_version 3 -write_id3v2 1 "$merged_audio"

    if [ $? -ne 0 ]; then
        echo "Error merging MP3 files in folder: $folder"
        rm -f "$file_list" "$chapters_file"
        return
    fi

    echo "Final merged output: $merged_audio"
    rm -f "$file_list" "$chapters_file"
    
    # Delete individual MP3 files (except the merged output).
    for file in "$folder"/*.mp3; do
        if [[ "$file" != "$merged_audio" && "$file" != "./$merged_audio" ]]; then
            echo "Deleting $file"
            rm "$file"
        fi
    done
}

echo "Script started. Processing source directory: $source_dir"

# Loop through all subfolders in the source directory.
find "$source_dir" -type d | while IFS= read -r folder; do
    echo "Processing folder: ${folder}"
    convert_to_mp3_in_folder "$folder"
    
    if [ "$SKIP_MERGE" -eq 0 ]; then
        merge_mp3s_in_folder "$folder"
    else
        echo "Skipping merging for folder: $folder"
    fi
done

echo "Conversion and merging complete!"
