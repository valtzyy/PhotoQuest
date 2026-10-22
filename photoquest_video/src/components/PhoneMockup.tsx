import { useCurrentFrame } from "remotion";

type Props = {
  width: number;
  children: React.ReactNode;
  // gentle idle float + 3D tilt
  float?: boolean;
  tiltDeg?: number;
  style?: React.CSSProperties;
};

// Screen ratio of the emulator screenshots (1080 x 2400)
export const SCREEN_RATIO = 2400 / 1080;
export const SHOT_WIDTH = 1080;

// Scene position of a screenshot pixel, for a phone placed at (left, top) without tilt/float
export const phonePoint = (phone: { left: number; top: number; width: number }, px: number, py: number) => {
  const bezel = phone.width * 0.035;
  const k = (phone.width - bezel * 2) / SHOT_WIDTH;
  return { x: phone.left + bezel + px * k, y: phone.top + bezel + py * k };
};

// Android phone drawn with divs: bezel, punch-hole camera, side buttons, soft shadow
export const PhoneMockup: React.FC<Props> = ({ width, children, float = true, tiltDeg = -8, style }) => {
  const frame = useCurrentFrame();
  const bezel = width * 0.035;
  const screenW = width - bezel * 2;
  const screenH = screenW * SCREEN_RATIO;
  const t = frame / 30;

  return (
    <div style={{ perspective: 2200, ...style }}>
      <div
        style={{
          position: "relative",
          width,
          height: screenH + bezel * 2,
          borderRadius: width * 0.14,
          background: "linear-gradient(145deg, #2b3446, #0d1220)",
          padding: bezel,
          boxShadow:
            "0 60px 120px rgba(0,0,0,0.55), 0 0 0 2px rgba(255,255,255,0.08) inset, 0 0 0 1px rgba(0,0,0,0.6)",
          rotate: `y ${tiltDeg + (float ? Math.sin(t * 0.8) * 2.5 : 0)}deg`,
          translate: `0px ${float ? Math.sin(t * 1.1) * 10 : 0}px`,
        }}
      >
        {/* side buttons */}
        <div style={{ position: "absolute", right: -4, top: "22%", width: 5, height: "9%", borderRadius: 3, background: "#3a4458" }} />
        <div style={{ position: "absolute", right: -4, top: "34%", width: 5, height: "14%", borderRadius: 3, background: "#3a4458" }} />
        <div
          style={{
            position: "relative",
            width: screenW,
            height: screenH,
            borderRadius: width * 0.11,
            overflow: "hidden",
            background: "#f4f7fb",
          }}
        >
          {children}
          {/* punch-hole camera */}
          <div
            style={{
              position: "absolute",
              top: screenW * 0.025,
              left: "50%",
              width: screenW * 0.04,
              height: screenW * 0.04,
              marginLeft: -screenW * 0.02,
              borderRadius: "50%",
              background: "#0b0f18",
            }}
          />
          {/* glass reflection */}
          <div
            style={{
              position: "absolute",
              inset: 0,
              background: "linear-gradient(115deg, rgba(255,255,255,0.18) 0%, rgba(255,255,255,0) 35%)",
              pointerEvents: "none",
            }}
          />
        </div>
      </div>
    </div>
  );
};
