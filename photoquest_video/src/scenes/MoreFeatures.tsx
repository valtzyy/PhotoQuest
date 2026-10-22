import { AbsoluteFill, Img, spring, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { Background } from "../components/Background";
import { KineticTitle } from "../components/KineticTitle";
import { PhoneMockup } from "../components/PhoneMockup";
import { fontFamily } from "../font";
import type { Colors, Screens, VoScene } from "../schema";
import { wordFrame } from "../timing";

type Props = { colors: Colors; screens: Screens; title: string; labels: readonly string[]; scene: VoScene };

const WIDTH = 300;
const GAP = 60;
const CUES = ["kuis", "konverter", "saran", "login"];

// Scene 9 — montage: quiz, converter, feedback, biometric login pop in as they are named
export const MoreFeatures: React.FC<Props> = ({ colors, screens, title, labels, scene }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const shots = [screens.quiz, screens.converter, screens.feedback, screens.profile];
  const startX = (1920 - (WIDTH * 4 + GAP * 3)) / 2;

  return (
    <AbsoluteFill>
      <Background colors={colors} />
      <div style={{ position: "absolute", top: 60, left: 0, right: 0 }}>
        <KineticTitle text={title} highlightColor={colors.secondary} highlight={["lagi"]} fontSize={72} delay={2} />
      </div>
      {shots.map((src, i) => {
        const at = wordFrame(scene, CUES[i], fps) - 6;
        const p = spring({ frame: frame - at, fps, config: { damping: 13, mass: 0.7 } });
        return (
          <div
            key={src}
            style={{
              position: "absolute",
              left: startX + i * (WIDTH + GAP),
              top: 190,
              opacity: Math.min(1, p * 1.5),
              translate: `0px ${(1 - p) * 260}px`,
              scale: String(0.85 + 0.15 * p),
            }}
          >
            <PhoneMockup width={WIDTH} tiltDeg={0} float={false}>
              <Img src={staticFile(src)} style={{ width: "100%", height: "100%", objectFit: "cover" }} />
            </PhoneMockup>
            <div
              style={{
                marginTop: 22,
                textAlign: "center",
                fontFamily,
                fontSize: 36,
                fontWeight: 700,
                color: "white",
              }}
            >
              {labels[i]}
            </div>
          </div>
        );
      })}
    </AbsoluteFill>
  );
};
