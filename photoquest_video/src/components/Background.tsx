import { AbsoluteFill, useCurrentFrame } from "remotion";
import type { Colors } from "../schema";

// Dark backdrop with two slowly drifting glows (brand blue + golden-hour gold)
export const Background: React.FC<{ colors: Colors }> = ({ colors }) => {
  const frame = useCurrentFrame();
  const t = frame / 30;

  return (
    <AbsoluteFill style={{ backgroundColor: colors.background, overflow: "hidden" }}>
      <div
        style={{
          position: "absolute",
          width: 1100,
          height: 1100,
          borderRadius: "50%",
          background: colors.primary,
          opacity: 0.28,
          filter: "blur(180px)",
          left: -250 + Math.sin(t * 0.35) * 120,
          top: -380 + Math.cos(t * 0.3) * 90,
        }}
      />
      <div
        style={{
          position: "absolute",
          width: 900,
          height: 900,
          borderRadius: "50%",
          background: colors.secondary,
          opacity: 0.2,
          filter: "blur(170px)",
          right: -260 + Math.cos(t * 0.4) * 110,
          bottom: -380 + Math.sin(t * 0.33) * 90,
        }}
      />
      {/* subtle dot grid */}
      <AbsoluteFill
        style={{
          backgroundImage: "radial-gradient(rgba(255,255,255,0.07) 1.5px, transparent 1.5px)",
          backgroundSize: "44px 44px",
          translate: `0px ${-(frame * 0.3) % 44}px`,
        }}
      />
    </AbsoluteFill>
  );
};
