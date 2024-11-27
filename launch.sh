#!/bin/sh

# Set working directory and environment variables
cd "$(dirname "$0")"
export LD_LIBRARY_PATH="$(dirname "$0"):/lib64:/usr/trimui/lib:/usr/lib:/usr/trimui/lib:$LD_LIBRARY_PATH"

# Function to get the local IP address
get_local_ip() {
  LOCAL_IP=$(hostname -I | awk '{print $1}')
  if echo "$LOCAL_IP" | grep -q 'addr:'; then
    LOCAL_IP=$(echo "$LOCAL_IP" | sed 's/addr://')
  fi
  if [ -z "$LOCAL_IP" ]; then
    LOCAL_IP=$(ifconfig | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | head -n 1)
  fi
  echo "Local IP address is $LOCAL_IP" >> "$ERROR_FILE"
  echo "Local IP address is $LOCAL_IP"
}

# Set variables
FFMPEG_PATH="./ffmpeg"
STREAM_DIR="./public"
SERVER_PORT=8080
ERROR_FILE="errors.txt"
WEB_SERVER_LOG="web_server_log.txt"

# Ensure directories and files exist
mkdir -p "$STREAM_DIR"
touch "$ERROR_FILE"
touch "$WEB_SERVER_LOG"

# Function to find and kill all instances of a process
kill_all_instances() {
  PROCESS_NAME=$1
  echo "$(date) - Killing all instances of $PROCESS_NAME..." >> "$ERROR_FILE"
  PIDS=$(ps | grep $PROCESS_NAME | grep -v grep | awk '{print $1}')
  for PID in $PIDS; do
    kill -9 $PID
  done
}

# Function to kill running processes and delete old segments
kill_processes() {
  kill_all_instances "ffmpeg"
  kill_all_instances "static-web-server"
  echo "$(date) - Deleting old HLS segments..." >> "$ERROR_FILE"
  rm -f "$STREAM_DIR"/*.ts "$STREAM_DIR"/*.m3u8
}

# Function to start FFmpeg screen capture with optimized HLS settings
start_ffmpeg() {
  echo "$(date) - Starting FFmpeg process with optimized HLS settings..." >> "$ERROR_FILE"
  "$FFMPEG_PATH" -re -loglevel verbose -f fbdev -framerate 30 -i /dev/fb0 -f oss -i /dev/dsp -vf format=yuv420p -c:v libx264 -preset superfast -crf 23 -tune zerolatency -threads 2 -bufsize 2000k -g 15 -x264-params keyint=15:min-keyint=15:scenecut=0 -f hls -hls_time 0.5 -hls_list_size 20 -hls_flags delete_segments -start_number 1 -strftime 1 -hls_segment_filename "$STREAM_DIR/segment_%Y%m%d%H%M%S.ts" "$STREAM_DIR/playlist.m3u8" >> "$ERROR_FILE" 2>&1 &
}

# Function to start the static-web-server
start_web_server() {
  ./static-web-server --port $SERVER_PORT --root $STREAM_DIR >> "$WEB_SERVER_LOG" 2>&1 &
  echo "$(date) - Static Web Server started on port $SERVER_PORT" >> "$ERROR_FILE"
}

# Get the local IP address and log it
get_local_ip

# Kill existing processes and delete old segments
kill_processes

# Start static-web-server in the background
start_web_server

# Start FFmpeg in the background
start_ffmpeg
echo "$(date) - FFmpeg started in the background, streaming via HLS on port $SERVER_PORT." >> "$ERROR_FILE"

# Exit the script immediately
exit 0
