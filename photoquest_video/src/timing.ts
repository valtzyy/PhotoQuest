import { parseSrt } from "@remotion/captions";
import { ALL_FORMATS, Input, UrlSource } from "mediabunny";
import { CalculateMetadataFunction, staticFile } from "remotion";
import type { DemoProps, VoScene } from "./schema";

export const FPS = 30;
// Frames into a scene before its voice-over starts (lets the transition land first)
export const VO_START = 10;
export const TRANSITION = 18;

// Scene order. `hold` = extra seconds after the VO so the visuals can breathe.
export const SCENES = [
  { id: "01-hook", hold: 0.3 },
  { id: "02-masalah", hold: 0.3 },
  { id: "03-perkenalan", hold: 0.8 },
  { id: "04-explore", hold: 1.0 },
  { id: "05-peta", hold: 1.2 },
  { id: "06-cuaca", hold: 1.0 },
  { id: "07-asisten", hold: 1.2 },
  { id: "08-sensor", hold: 1.0 },
  { id: "09-lainnya", hold: 0.8 },
  { id: "10-ringkasan", hold: 1.0 },
  { id: "11-cta", hold: 2.0 },
] as const;

const getAudioDuration = async (src: string) => {
  const input = new Input({ formats: ALL_FORMATS, source: new UrlSource(src) });
  return input.computeDuration();
};

const loadScene = async (id: string, hold: number, isLast: boolean): Promise<VoScene> => {
  const [seconds, srt] = await Promise.all([
    getAudioDuration(staticFile(`vo/${id}.mp3`)),
    fetch(staticFile(`vo/${id}.srt`)).then((r) => r.text()),
  ]);
  const audioFrames = Math.ceil(seconds * FPS);
  // Captions are whitespace sensitive: every word after the first needs a leading space
  const captions = parseSrt({ input: srt }).captions.map((c, i) => ({
    ...c,
    text: i === 0 ? c.text.trim() : ` ${c.text.trim()}`,
  }));
  return {
    id,
    audioFrames,
    // VO + 0.5 s padding + hold, plus the overlap eaten by the next transition
    sceneFrames: VO_START + audioFrames + Math.ceil((0.5 + hold) * FPS) + (isLast ? 0 : TRANSITION),
    captions,
  };
};

export const calculateMetadata: CalculateMetadataFunction<DemoProps> = async ({ props }) => {
  const vo = await Promise.all(
    SCENES.map((s, i) => loadScene(s.id, s.hold, i === SCENES.length - 1)),
  );
  const total = vo.reduce((sum, s) => sum + s.sceneFrames, 0) - TRANSITION * (vo.length - 1);
  return { durationInFrames: total, props: { ...props, vo } };
};

// Absolute frame at which each scene starts in the main timeline
export const sceneStarts = (vo: VoScene[]) => {
  let at = 0;
  return vo.map((s) => {
    const start = at;
    at += s.sceneFrames - TRANSITION;
    return start;
  });
};

// Frame (relative to the scene) at which `word` is spoken, for syncing visuals to the VO
export const wordFrame = (scene: VoScene, word: string, fps: number) => {
  const c = scene.captions.find((cap) =>
    cap.text.trim().toLowerCase().startsWith(word.toLowerCase()),
  );
  return VO_START + Math.round(((c?.startMs ?? 0) / 1000) * fps);
};
