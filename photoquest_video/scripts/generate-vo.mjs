// Generate voice-over + word-level .srt per scene with edge-tts (free, Microsoft neural voices).
// Usage: node scripts/generate-vo.mjs [--voice id-ID-ArdiNeural]
import { execFileSync } from "node:child_process";
import { mkdirSync, readFileSync } from "node:fs";

const voiceArg = process.argv.indexOf("--voice");
const voice = voiceArg > -1 ? process.argv[voiceArg + 1] : "id-ID-GadisNeural";
const script = JSON.parse(readFileSync("src/script.json", "utf8"));

mkdirSync("public/vo", { recursive: true });

for (const { id, text } of script) {
  console.log(`[vo] ${id}`);
  // tts.py = edge-tts with word-level subtitles (needed for TikTok-style captions)
  execFileSync(
    "python",
    ["scripts/tts.py", voice, "+5%", text, `public/vo/${id}.mp3`, `public/vo/${id}.srt`],
    { stdio: "inherit" },
  );
}
