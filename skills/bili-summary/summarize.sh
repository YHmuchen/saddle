#!/usr/bin/env bash
# bili-summary: 下载音频 → Whisper转写 → 输出文本供 LLM 总结
# 用法: ./summarize.sh <视频URL> [--model tiny] [--language zh] [--no-summary]
set -euo pipefail

URL=""
MODEL="tiny"
LANGUAGE="zh"
NO_SUMMARY=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --model) MODEL="$2"; shift 2 ;;
    --language) LANGUAGE="$2"; shift 2 ;;
    --no-summary) NO_SUMMARY=true; shift ;;
    *) URL="$1"; shift ;;
  esac
done

if [ -z "$URL" ]; then
  echo "Usage: $0 <video_url> [--model tiny] [--language zh] [--no-summary]"
  exit 1
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
AUDIO="$WORKDIR/audio"
TRANSCRIPT="$WORKDIR/transcript.txt"

echo "=== bili-summary ==="
echo "URL:      $URL"
echo "Model:    $MODEL"
echo "Language: $LANGUAGE"

# Step 1: Download audio
echo "[1/2] Downloading audio..."
if ! yt-dlp -x --audio-format mp3 --audio-quality 64K \
  -o "${AUDIO}.%(ext)s" "$URL" 2>&1 | tail -3; then
  echo "ERROR: yt-dlp failed" >&2
  exit 2
fi

AUDIO_FILE="$(ls "$WORKDIR"/*.mp3 "$WORKDIR"/*.m4a "$WORKDIR"/*.webm 2>/dev/null | head -1)"
if [ ! -f "$AUDIO_FILE" ]; then
  echo "ERROR: No audio file found" >&2
  exit 3
fi

# Step 2: Transcribe
echo "[2/2] Transcribing with faster-whisper ($MODEL)..."
export AUDIO_FILE MODEL LANGUAGE TRANSCRIPT
python3 << 'PYEOF'
from faster_whisper import WhisperModel
import sys, time, os

audio = os.environ['AUDIO_FILE']
lang = os.environ['LANGUAGE']
model_name = os.environ['MODEL']
out = os.environ['TRANSCRIPT']

model = WhisperModel(model_name, device='cpu', compute_type='int8')
start = time.time()
segments, info = model.transcribe(audio, language=lang, beam_size=5)

lines = []
for seg in segments:
    lines.append(f'[{seg.start:.0f}s] {seg.text}')
    if len(lines) % 50 == 0:
        print(f'  {seg.start:.0f}s / {info.duration:.0f}s', file=sys.stderr)

with open(out, 'w', encoding='utf-8') as f:
    f.write('\n'.join(lines))
print(f'Done in {time.time()-start:.0f}s, {len(lines)} segments', file=sys.stderr)
print(f'Language: {info.language} (prob={info.language_probability:.2f})', file=sys.stderr)
PYEOF

echo ""
echo "Transcript: $TRANSCRIPT ($(wc -l < "$TRANSCRIPT") segments)"

if [ "$NO_SUMMARY" = true ]; then
  cat "$TRANSCRIPT"
else
  cp "$TRANSCRIPT" ./transcript.txt
  echo "=== Preview (first 20 lines) ==="
  head -20 "$TRANSCRIPT"
  echo "..."
  echo "Full transcript: $(pwd)/transcript.txt"
  trap - EXIT
fi
