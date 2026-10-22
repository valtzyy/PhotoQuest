import { AbsoluteFill, Easing, Img, interpolate, spring, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { KineticTitle } from "../components/KineticTitle";
import { fontFamily } from "../font";
import type { Colors, VoScene } from "../schema";
import { wordFrame } from "../timing";

type Props = { colors: Colors; name: string; tagline: string; footer: string; scene: VoScene };

// Scene 11 — bookend of the hook: the sun rises behind the logo
export const Cta: React.FC<Props> = ({ colors, name, tagline, footer, scene }) => {
  const frame = useCurrentFrame();
  const { fps, durationInFrames } = useVideoConfig();
  const rise = interpolate(frame, [0, durationInFrames], [0, 1], {
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });
  const logoIn = spring({ frame: frame - 4, fps, config: { damping: 12 } });
  const taglineAt = wordFrame(scene, "Temukan", fps) - 4;
  const footerIn = spring({ frame: frame - taglineAt - 20, fps, config: { damping: 200 } });

  return (
    <AbsoluteFill style={{ overflow: "hidden", backgroundColor: colors.background }}>
      <AbsoluteFill
        style={{
          background: `linear-gradient(180deg, ${colors.background} 0%, #1d2b4a 55%, #c4672c 100%)`,
          opacity: interpolate(rise, [0, 1], [0.35, 1]),
        }}
      />
      <div
        style={{
          position: "absolute",
          left: 960 - 260,
          top: interpolate(rise, [0, 1], [1000, 640]),
          width: 520,
          height: 520,
          borderRadius: "50%",
          background: `radial-gradient(circle, #FFE896 0%, ${colors.secondary} 50%, rgba(245,170,0,0) 72%)`,
          boxShadow: "0 0 260px 110px rgba(245,170,0,0.35)",
        }}
      />
      <AbsoluteFill style={{ justifyContent: "center", alignItems: "center", paddingBottom: 140 }}>
        <div style={{ display: "flex", alignItems: "center", gap: 36, scale: String(logoIn) }}>
          <Img src={staticFile("logo.svg")} style={{ width: 170, height: 170, filter: "drop-shadow(0 24px 50px rgba(0,0,0,0.4))" }} />
          <div style={{ fontFamily, fontSize: 130, fontWeight: 800, letterSpacing: "-0.03em", color: "white" }}>
            {name.slice(0, 5)}
            <span style={{ color: colors.secondary }}>{name.slice(5)}</span>
          </div>
        </div>
        <div style={{ marginTop: 40 }}>
          <KineticTitle text={tagline} highlight={["cahayamu."]} highlightColor={colors.secondary} fontSize={84} delay={taglineAt} stagger={6} />
        </div>
        <div
          style={{
            marginTop: 50,
            fontFamily,
            fontSize: 34,
            fontWeight: 500,
            color: "rgba(255,255,255,0.75)",
            opacity: footerIn,
            translate: `0px ${(1 - footerIn) * 20}px`,
          }}
        >
          {footer}
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
