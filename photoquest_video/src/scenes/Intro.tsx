import { Audio } from "@remotion/media";
import { AbsoluteFill, Easing, Img, interpolate, Sequence, spring, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { Background } from "../components/Background";
import { PhoneMockup } from "../components/PhoneMockup";
import { fontFamily } from "../font";
import type { Colors } from "../schema";

type Props = {
  colors: Colors;
  name: string;
  tagline: string;
  homeScreen: string;
};

// Scene 3 — logo reveal in the center, then it slides left as the phone rises in
export const Intro: React.FC<Props> = ({ colors, name, tagline, homeScreen }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const LOGO_AT = 8;
  const SPLIT_AT = Math.round(1.9 * fps);

  const logoIn = spring({ frame: frame - LOGO_AT, fps, config: { damping: 11, mass: 0.8 } });
  const split = spring({ frame: frame - SPLIT_AT, fps, config: { damping: 200 }, durationInFrames: 30 });
  const phoneIn = spring({ frame: frame - SPLIT_AT - 6, fps, config: { damping: 18, mass: 0.9 } });
  const taglineIn = spring({ frame: frame - SPLIT_AT - 14, fps, config: { damping: 200 } });

  return (
    <AbsoluteFill>
      <Background colors={colors} />
      {/* light burst behind the logo */}
      <AbsoluteFill style={{ justifyContent: "center", alignItems: "center" }}>
        <div
          style={{
            width: 900,
            height: 900,
            borderRadius: "50%",
            background: `radial-gradient(circle, ${colors.primary}88 0%, rgba(0,0,0,0) 60%)`,
            scale: String(interpolate(frame, [LOGO_AT, LOGO_AT + 25], [0.2, 1.4], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: Easing.out(Easing.cubic) })),
            opacity: interpolate(frame, [LOGO_AT, LOGO_AT + 10, LOGO_AT + 45], [0, 1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }),
          }}
        />
      </AbsoluteFill>

      {/* brand block: centered first, then moves to the left column */}
      <AbsoluteFill
        style={{
          justifyContent: "center",
          alignItems: "center",
          translate: `${interpolate(split, [0, 1], [0, -390])}px 0px`,
        }}
      >
        <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 28 }}>
          <Img
            src={staticFile("logo.svg")}
            style={{
              width: 220,
              height: 220,
              scale: String(logoIn),
              rotate: `${(1 - logoIn) * -25}deg`,
              filter: `drop-shadow(0 30px 60px ${colors.primary}88)`,
            }}
          />
          <div
            style={{
              fontFamily,
              fontSize: 120,
              fontWeight: 800,
              letterSpacing: "-0.03em",
              color: "white",
              opacity: interpolate(frame, [LOGO_AT + 10, LOGO_AT + 22], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }),
              translate: `0px ${interpolate(frame, [LOGO_AT + 10, LOGO_AT + 28], [40, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: Easing.out(Easing.cubic) })}px`,
            }}
          >
            {name.slice(0, 5)}
            <span style={{ color: colors.secondary }}>{name.slice(5)}</span>
          </div>
          <div
            style={{
              fontFamily,
              fontSize: 46,
              fontWeight: 500,
              color: "rgba(255,255,255,0.82)",
              maxWidth: 720,
              textAlign: "center",
              lineHeight: 1.3,
              opacity: taglineIn,
              translate: `0px ${(1 - taglineIn) * 24}px`,
            }}
          >
            {tagline}
          </div>
        </div>
      </AbsoluteFill>

      {/* phone rises from below on the right */}
      <AbsoluteFill style={{ justifyContent: "center", alignItems: "center" }}>
        <PhoneMockup
          width={400}
          tiltDeg={-12}
          style={{
            translate: `${430}px ${interpolate(phoneIn, [0, 1], [1100, 40])}px`,
          }}
        >
          <Img src={staticFile(homeScreen)} style={{ width: "100%", height: "100%", objectFit: "cover" }} />
        </PhoneMockup>
      </AbsoluteFill>

      <Sequence from={LOGO_AT} layout="none" name="Logo shimmer">
        <Audio src={staticFile("sfx/shimmer.mp3")} volume={0.45} />
      </Sequence>
      <Sequence from={SPLIT_AT} layout="none" name="Phone whoosh">
        <Audio src={staticFile("sfx/whoosh.mp3")} volume={0.4} />
      </Sequence>
    </AbsoluteFill>
  );
};
