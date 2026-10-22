# edge-tts with word-level boundaries (the CLI only emits sentence-level .srt).
# Usage: python tts.py <voice> <rate> <text> <out.mp3> <out.srt>
import asyncio
import sys

import edge_tts


async def main(voice, rate, text, mp3_path, srt_path):
    communicate = edge_tts.Communicate(text, voice, rate=rate, boundary="WordBoundary")
    submaker = edge_tts.SubMaker()
    with open(mp3_path, "wb") as mp3:
        async for chunk in communicate.stream():
            if chunk["type"] == "audio":
                mp3.write(chunk["data"])
            elif chunk["type"] == "WordBoundary":
                submaker.feed(chunk)
    with open(srt_path, "w", encoding="utf-8") as srt:
        srt.write(submaker.get_srt())


asyncio.run(main(*sys.argv[1:6]))
