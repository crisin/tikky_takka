"""Transcribe a brainstorming recording into docs/ideen/.

Usage (from the project root, Git Bash):
    tools/idee.sh "C:/Users/chris/Desktop/aufnahme.mp3"

Copies the audio next to the transcript, writes <name>.md (plain text with
timestamps) and prints the transcript path. Runs fully locally with
faster-whisper; tries the GPU first and falls back to the CPU.
"""

from __future__ import annotations

import argparse
import shutil
import sys
import time
from pathlib import Path

MODEL = "mobiuslabsgmbh/faster-whisper-large-v3-turbo"
PROJECT_ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = PROJECT_ROOT / "docs" / "ideen" / "aufnahmen"


def fmt(seconds: float) -> str:
    m, s = divmod(int(seconds), 60)
    return f"{m:02d}:{s:02d}"


def load_model():
    from faster_whisper import WhisperModel

    try:
        return WhisperModel(MODEL, device="cuda", compute_type="float16"), "GPU"
    except Exception as error:  # missing CUDA libraries, no GPU, ...
        print(f"GPU nicht nutzbar ({error}); nehme die CPU.", file=sys.stderr)
        return WhisperModel(MODEL, device="cpu", compute_type="int8"), "CPU"


def transcribe(model, audio: Path, language: str):
    segments, info = model.transcribe(
        str(audio),
        language=language,
        vad_filter=True,
        beam_size=5,
        condition_on_previous_text=True,
    )
    return list(segments), info


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("audio", type=Path)
    parser.add_argument("--sprache", default="de")
    parser.add_argument("--force", action="store_true", help="overwrite an existing transcript")
    args = parser.parse_args()

    source: Path = args.audio
    if not source.is_file():
        print(f"Datei nicht gefunden: {source}", file=sys.stderr)
        return 1

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    audio_copy = OUT_DIR / source.name
    transcript = OUT_DIR / (source.stem + ".md")
    if transcript.exists() and not args.force:
        print(f"Transkript existiert schon: {transcript} (--force zum Überschreiben)", file=sys.stderr)
        print(transcript)
        return 0
    if not audio_copy.exists():
        shutil.copy2(source, audio_copy)

    started = time.time()
    model, device = load_model()
    try:
        segments, info = transcribe(model, audio_copy, args.sprache)
    except Exception as error:
        if device != "GPU":
            raise
        # CUDA libraries can fail only once decoding starts.
        print(f"GPU-Lauf fehlgeschlagen ({error}); wiederhole auf der CPU.", file=sys.stderr)
        from faster_whisper import WhisperModel

        model, device = WhisperModel(MODEL, device="cpu", compute_type="int8"), "CPU"
        segments, info = transcribe(model, audio_copy, args.sprache)

    lines = [
        f"# Transkript: {source.stem}",
        "",
        f"- Audio: `{audio_copy.name}`",
        f"- Dauer: {fmt(info.duration)}",
        f"- Modell: {MODEL} ({device})",
        "- Automatisch transkribiert, nicht korrigiert.",
        "",
    ]
    for segment in segments:
        text = segment.text.strip()
        if text:
            lines.append(f"[{fmt(segment.start)}] {text}")
    transcript.write_text("\n".join(lines) + "\n", encoding="utf-8")

    print(
        f"{fmt(info.duration)} Audio in {time.time() - started:.0f} s auf der {device}.",
        file=sys.stderr,
    )
    print(transcript)
    return 0


if __name__ == "__main__":
    sys.exit(main())
