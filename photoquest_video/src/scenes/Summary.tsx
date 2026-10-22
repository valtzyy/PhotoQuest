import { AbsoluteFill, Img, interpolate, spring, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { Background } from "../components/Background";
import { KineticTitle } from "../components/KineticTitle";
import { PhoneMockup } from "../components/PhoneMockup";
import { fontFamily } from "../font";
import type { Colors, Screens, VoScene } from "../schema";
import { wordFrame } from "../timing";

type Props = { colors: Colors; screens: Screens; title: string; pillars: readonly string[]; scene: VoScene };

const WIDTH = 300;
const CUES = ["Lokasi", "cuaca", "AI", "sensor"];
// fanned arc: x offset from center, rotation, y drop
const FAN = [
  { x: -540, r: -10, y: 60 },
  { x: -180, r: -3.5, y: 10 },
  { x: 180, r: 3.5, y: 10 },
  { x: 540, r: 10, y: 60 },
];

// Scene 10 — the four pillars, each with its phone, fanned out; title lands on "Semua"
export const Summary: React.FC<Props> = ({ colors, screens, title, pillars, scene }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const shots = [screens.map, screens.planResult, screens.assistantAnswer, screens.levelFlat];
  const all = wordFrame(scene, "Semua", fps) - 4;
  // phones gather slightly when the title lands
  const gather = spring({ frame: frame - all, fps, config: { damping: 200 }, durationInFrames: 24 });

  return (
    <AbsoluteFill>
      <Background colors={colors} />
      {shots.map((src, i) => {
        const at = wordFrame(scene, CUES[i], fps) - 6;
        const p = spring({ frame: frame - at, fps, config: { damping: 13, mass: 0.7 } });
        const f = FAN[i];
        return (
          <div
            key={src}
            style={{
              position: "absolute",
              left: 960 - WIDTH / 2 + f.x * (1 - 0.12 * gather),
              top: 330 + f.y,
              opacity: Math.min(1, p * 1.5),
              translate: `0px ${(1 - p) * 300}px`,
              rotate: `${f.r * p}deg`,
            }}
          >
            <div
              style={{
                position: "absolute",
                top: -84,
                left: 0,
                right: 0,
                textAlign: "center",
              }}
            >
              <span
                style={{
                  fontFamily,
                  fontSize: 38,
                  fontWeight: 800,
                  color: "#0B1424",
                  background: i % 2 === 0 ? colors.primary : colors.secondary,
                  padding: "10px 28px",
                  borderRadius: 999,
                }}
              >
                {pillars[i]}
              </span>
            </div>
            <PhoneMockup width={WIDTH} tiltDeg={0} float={false}>
              <Img src={staticFile(src)} style={{ width: "100%", height: "100%", objectFit: "cover" }} />
            </PhoneMockup>
          </div>
        );
      })}
      <div
        style={{
          position: "absolute",
          top: 70,
          left: 0,
          right: 0,
          opacity: interpolate(frame, [all, all + 4], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }),
        }}
      >
        <KineticTitle text={title} highlight={["satu"]} highlightColor={colors.secondary} fontSize={88} delay={all} />
      </div>
    </AbsoluteFill>
  );
};
