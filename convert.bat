ffmpeg -y -f rawvideo -pix_fmt gray -video_size 1024x1024 -framerate 25 -i data.raw -c:v h264 -pix_fmt yuv420p video.mov