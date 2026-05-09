#!/usr/bin/env bash
# bili-summary: 下载音频 → Whisper转写 → 输出文本
# 用法: ./summarize.sh <视频URL> [whisper模型]
set -e

URL="${1:?Usage: $0 <video_url> [whisper_model]}"
MODEL="${2:-tiny}"
WORKDIR="$(mktemp -d)"
AUDIO="$WORKDIR/audio.mp3"
OUTPUT="$WORKDIR/transcript.txt"

echo "=== bili-summary ==="
echo "URL: $URL"
echo "Model: $MODEL"
echo ""

# Step 1: Download audio
echo "[1/2] Downloading audio..."
yt-dlp -x --audio-format mp3 --audio-quality 64K \
  -o "$AUDIO" "$URL" 2>&1 | tail -3

# Step 2: Transcribe
echo "[2/2] Transcribing with faster-whisper ($MODEL)..."
python3 -c "
from faster_whisper import WhisperModel
import sys, time

model = WhisperModel('$MODEL', device='cpu', compute_type='int8')
start = time.time()
segments, info = model.transcribe('$AUDIO', language='zh', beam_size=5)

lines = []
for seg in segments:
    lines.append(f'[{seg.start:.0f}s] {seg.text}')
    if len(lines) % 50 == 0:
        print(f'  {seg.start:.0f}s / {info.duration:.0f}s', file=sys.stderr)

with open('$OUTPUT', 'w', encoding='utf-8') as f:
    f.write('\n'.join(lines))
print(f'Done in {time.time()-start:.0f}s, {len(lines)} segments', file=sys.stderr)
" 2>&1

echo ""
echo "Transcript: $OUTPUT"
cat "$OUTPUT"
