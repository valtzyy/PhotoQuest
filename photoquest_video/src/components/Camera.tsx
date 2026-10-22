import { AbsoluteFill, Easing, interpolate, useCurrentFrame } from "remotion";

type Props = {
  // point that stays fixed while zooming (scene coordinates)
  focusX: number;
  focusY: number;
  scale: number;
  from: number;
  // zoom back out at this frame (omit to stay zoomed)
  to?: number;
  children: React.ReactNode;
};

// Camera push-in on an area of the UI: scales the whole layer around a focus point
export const Camera: React.FC<Props> = ({ focusX, focusY, scale, from, to, children }) => {
  const frame = useCurrentFrame();
  const ease = Easing.bezier(0.65, 0, 0.35, 1);
  const zoom =
    to === undefined
      ? interpolate(frame, [from, from + 24], [1, scale], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: ease })
      : interpolate(frame, [from, from + 24, to, to + 24], [1, scale, scale, 1], {
          extrapolateLeft: "clamp",
          extrapolateRight: "clamp",
          easing: ease,
        });

  return (
    <AbsoluteFill style={{ scale: String(zoom), transformOrigin: `${focusX}px ${focusY}px` }}>{children}</AbsoluteFill>
  );
};
