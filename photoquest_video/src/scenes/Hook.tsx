import { AbsoluteFill, Easing, interpolate, interpolateColors, useCurrentFrame, useVideoConfig } from "remotion";
import { KineticTitle } from "../components/KineticTitle";
import type { Colors } from "../schema";

type Props = {
  colors: Colors;
  title: string;
  highlight: readonly string[];
};

// Scene 1 — a golden sun sinks below the horizon while the question appears
export const Hook: React.FC<Props> = ({ colors, title, highlight }) => {
  const frame = useCurrentFrame();
  const { durationInFrames } = useVideoConfig();
  const sink = interpolate(frame, [0, durationInFrames], [0, 1], {
    extrapolateRight: "clamp",
    easing: Easing.bezier(0.45, 0, 0.55, 1),
  });

  return (
    <AbsoluteFill style={{ overflow: "hidden" }}>
      {/* sky: warm -> dusk */}
      <AbsoluteFill
        style={{
          background: `linear-gradient(180deg, ${interpolateColors(sink, [0, 1], ["#1d2b4a", "#070b16"])} 0%, ${interpolateColors(sink, [0, 1], ["#c4672c", "#1a1f3a"])} 100%)`,
        }}
      />
      {/* sun */}
      <div
        style={{
          position: "absolute",
          left: 960 - 170,
          top: interpolate(sink, [0, 1], [560, 900]),
          width: 340,
          height: 340,
          borderRadius: "50%",
          background: `radial-gradient(circle, #FFE896 0%, ${colors.secondary} 55%, rgba(245,170,0,0) 72%)`,
          boxShadow: `0 0 220px 80px rgba(245,170,0,${interpolate(sink, [0, 1], [0.55, 0.05])})`,
          opacity: interpolate(sink, [0, 0.85, 1], [1, 0.6, 0.2]),
        }}
      />
      {/* horizon */}
      <div
        style={{
          position: "absolute",
          left: 0,
          right: 0,
          top: 820,
          bottom: 0,
          background: "linear-gradient(180deg, #0a1020 0%, #05070d 100%)",
          borderTop: "2px solid rgba(255,255,255,0.08)",
        }}
      />
      <AbsoluteFill style={{ justifyContent: "center", alignItems: "center", paddingBottom: 260 }}>
        <KineticTitle
          text={title}
          highlight={highlight}
          highlightColor={colors.secondary}
          fontSize={92}
          delay={8}
          style={{ maxWidth: 1500, textAlign: "center" }}
        />
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
