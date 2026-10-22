import { zColor } from "@remotion/zod-types";
import { z } from "zod";

const captionSchema = z.object({
  text: z.string(),
  startMs: z.number(),
  endMs: z.number(),
  timestampMs: z.number().nullable(),
  confidence: z.number().nullable(),
});

// One entry per scene, filled by calculateMetadata() from public/vo/<id>.mp3/.srt
const voSceneSchema = z.object({
  id: z.string(),
  audioFrames: z.number(),
  sceneFrames: z.number(),
  captions: z.array(captionSchema),
});

const featureSchema = z.object({
  eyebrow: z.string(),
  title: z.string(),
  highlight: z.array(z.string()),
  labels: z.array(z.string()),
});

export const demoSchema = z.object({
  colors: z.object({
    primary: zColor(),
    secondary: zColor(),
    background: zColor(),
  }),
  // paths inside public/
  screens: z.object({
    home: z.string(),
    explore: z.string(),
    detail: z.string(),
    map: z.string(),
    weather: z.string(),
    planForm: z.string(),
    planResult: z.string(),
    assistantEmpty: z.string(),
    assistantTyping: z.string(),
    assistantAnswer: z.string(),
    levelTilt: z.string(),
    levelFlat: z.string(),
    steadyResult: z.string(),
    chainValid: z.string(),
    quiz: z.string(),
    converter: z.string(),
    feedback: z.string(),
    profile: z.string(),
  }),
  hook: z.object({
    title: z.string(),
    highlight: z.array(z.string()),
  }),
  problem: z.object({
    heading: z.string(),
    pains: z.array(z.string()),
  }),
  intro: z.object({
    name: z.string(),
    tagline: z.string(),
  }),
  explore: featureSchema,
  map: featureSchema,
  weather: featureSchema,
  assistant: featureSchema,
  sensor: featureSchema,
  more: z.object({ title: z.string(), labels: z.array(z.string()) }),
  summary: z.object({ title: z.string(), pillars: z.array(z.string()) }),
  cta: z.object({ tagline: z.string(), footer: z.string() }),
  showCaptions: z.boolean(),
  vo: z.array(voSceneSchema),
});

export type DemoProps = z.infer<typeof demoSchema>;
export type Colors = DemoProps["colors"];
export type Screens = DemoProps["screens"];
export type Feature = DemoProps["explore"];
export type VoScene = DemoProps["vo"][number];
