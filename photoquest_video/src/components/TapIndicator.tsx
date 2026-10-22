import { interpolate, useCurrentFrame } from "remotion";

type Props = { x: number; y: number; at: number };

// Finger-tap: a dot that lands, presses, then ripples out
export const TapIndicator: React.FC<Props> = ({ x, y, at }) => {
  const frame = useCurrentFrame();
  const f = frame - at;
  if (f < -8 || f > 22) return null;

  const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;
  const dotScale = interpolate(f, [-8, -2, 0, 3, 12], [0.4, 1, 0.8, 0.85, 1.1], clamp);
  const dotOpacity = interpolate(f, [-8, -4, 10, 18], [0, 0.9, 0.7, 0], clamp);
  const ripple = interpolate(f, [0, 20], [0.3, 2.6], clamp);
  const rippleOpacity = interpolate(f, [0, 4, 20], [0, 0.7, 0], clamp);

  return (
    <>
      <div
        style={{
          position: "absolute",
          left: x - 40,
          top: y - 40,
          width: 80,
          height: 80,
          borderRadius: "50%",
          border: "4px solid white",
          boxShadow: "0 0 20px rgba(54,166,230,0.9)",
          scale: String(ripple),
          opacity: rippleOpacity,
        }}
      />
      <div
        style={{
          position: "absolute",
          left: x - 26,
          top: y - 26,
          width: 52,
          height: 52,
          borderRadius: "50%",
          background: "rgba(255,255,255,0.85)",
          border: "3px solid rgba(54,166,230,0.9)",
          boxShadow: "0 6px 18px rgba(0,0,0,0.3)",
          scale: String(dotScale),
          opacity: dotOpacity,
        }}
      />
    </>
  );
};
