import { interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { fontFamily } from "../font";

type Props = {
  // target point in scene coordinates
  x: number;
  y: number;
  label: string;
  at: number;
  side?: "left" | "right";
  // horizontal length of the pointer line
  length?: number;
  color: string;
  // hide again at this frame (optional)
  until?: number;
};

// Annotation: pulsing dot on the UI, a pointer line that draws itself, then a label
export const Callout: React.FC<Props> = ({ x, y, label, at, side = "right", length = 220, color, until }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const f = frame - at;
  if (f < 0) return null;

  const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;
  const out = until === undefined ? 1 : interpolate(frame, [until, until + 8], [1, 0], clamp);
  const line = interpolate(f, [4, 16], [0, 1], clamp);
  const labelIn = spring({ frame: f - 12, fps, config: { damping: 14, mass: 0.6 } });
  const pulse = (f % 30) / 30;
  const dir = side === "right" ? 1 : -1;
  const endX = x + dir * length;

  return (
    <div style={{ position: "absolute", inset: 0, opacity: out }}>
      <svg width={1920} height={1080} style={{ position: "absolute", left: 0, top: 0, overflow: "visible" }}>
        <line
          x1={x}
          y1={y}
          x2={x + dir * length * line}
          y2={y}
          stroke={color}
          strokeWidth={4}
          strokeLinecap="round"
        />
      </svg>
      <div
        style={{
          position: "absolute",
          left: x - 30,
          top: y - 30,
          width: 60,
          height: 60,
          borderRadius: "50%",
          border: `3px solid ${color}`,
          scale: String(0.4 + pulse * 1.2),
          opacity: 1 - pulse,
        }}
      />
      <div
        style={{
          position: "absolute",
          left: x - 12,
          top: y - 12,
          width: 24,
          height: 24,
          borderRadius: "50%",
          background: color,
          boxShadow: `0 0 0 6px ${color}44`,
          scale: String(interpolate(f, [0, 6], [0, 1], clamp)),
        }}
      />
      <div
        style={{
          position: "absolute",
          top: y - 36,
          left: side === "right" ? endX + 10 : undefined,
          right: side === "left" ? 1920 - endX + 10 : undefined,
          fontFamily,
          fontSize: 38,
          fontWeight: 700,
          color: "#0B1424",
          background: color,
          padding: "12px 26px",
          borderRadius: 18,
          whiteSpace: "nowrap",
          boxShadow: "0 18px 40px rgba(0,0,0,0.35)",
          opacity: labelIn,
          scale: String(0.7 + 0.3 * labelIn),
          transformOrigin: side === "right" ? "left center" : "right center",
        }}
      >
        {label}
      </div>
    </div>
  );
};
