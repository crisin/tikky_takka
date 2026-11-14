#!/usr/bin/env bash
# Transcribe a brainstorming recording into docs/ideen/aufnahmen/.
#   tools/idee.sh "C:/Users/chris/Desktop/aufnahme.mp3"
#
# Uses the Python environment of the geländeprotokolle project, which already
# has faster-whisper installed. Set TIKKY_WHISPER_PYTHON to use another one.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
python="${TIKKY_WHISPER_PYTHON:-/d/Projekte/dev/geländeprotokolle/.venv/Scripts/python.exe}"
if [ ! -x "$python" ]; then
  echo "Python mit faster-whisper nicht gefunden: $python" >&2
  exit 1
fi
PYTHONUTF8=1 exec "$python" "$here/transkribiere.py" "$@"
