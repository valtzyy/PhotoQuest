import { createTikTokStyleCaptions } from "@remotion/captions";
import { useMemo } from "react";
import { AbsoluteFill, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { fontFamily } from "../font";
import type { VoScene } from "../schema";

type Props = {
  scene: VoScene;
  // frame (relative to the scene) where the VO audio starts
  offset: number;
  activeColor: string;
  // horizontal center of the subtitle box (keeps it clear of the phone)
  centerX?: number;
};

// TikTok-style subtitles: 2–4 words per page, the word being spoken is highlighted
export const Captions: React.FC<Props> = ({ scene, offset, activeColor, centerX = 960 }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const ms = ((frame - offset) / fps) * 1000;

  const pages = useMemo(
    () =>
      createTikTokStyleCaptions({
        captions: scene.captions,
        combineTokensWithinMilliseconds: 750,
      }).pages,
    [scene.captions],
  );

  const pageIndex = pages.findIndex((p, i) => {
    const end = pages[i + 1]?.startMs ?? p.startMs + p.durationMs;
    return ms >= p.startMs && ms < end;
  });
  if (pageIndex === -1) return null;
  const page = pages[pageIndex];
  const pageFrame = Math.round((page.startMs / 1000) * fps) + offset;
  const pop = spring({ frame: frame - pageFrame, fps, config: { damping: 15, mass: 0.5 } });

  return (
    <AbsoluteFill
      style={{ justifyContent: "flex-end", alignItems: "center", paddingBottom: 60, translate: `${centerX - 960}px 0px` }}
    >
      <div
        style={{
          fontFamily,
          fontSize: 50,
          fontWeight: 800,
          color: "white",
          padding: "14px 30px",
          borderRadius: 22,
          background: "rgba(8,14,26,0.62)",
          backdropFilter: "blur(10px)",
          whiteSpace: "pre",
          scale: String(0.9 + 0.1 * pop),
          opacity: pop,
          textShadow: "0 3px 12px rgba(0,0,0,0.5)",
        }}
      >
        {page.tokens.map((tok) => {
          const active = ms >= tok.fromMs && ms < tok.toMs;
          return (
            <span key={tok.fromMs} style={{ color: active ? activeColor : "white" }}>
              {tok.text}
            </span>
          );
        })}
      </div>
    </AbsoluteFill>
  );
};
