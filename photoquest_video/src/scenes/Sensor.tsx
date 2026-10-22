import { AbsoluteFill, Easing, interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { Background } from "../components/Background";
import { FeatureText } from "../components/FeatureText";
import { PhoneMockup } from "../components/PhoneMockup";
import { ScreenFlow } from "../components/ScreenFlow";
import { fontFamily } from "../font";
import type { Colors, Feature, Screens, VoScene } from "../schema";
import { wordFrame } from "../timing";

type Props = { colors: Colors; screens: Screens; text: Feature; scene: VoScene };

const PHONE = { left: 780, top: 70, width: 420 };
const SCREEN_W = PHONE.width * 0.93;
// last blocks of the local chain (shortened hashes)
const BLOCKS = [
  { n: 5, hash: "00c336a0…" },
  { n: 6, hash: "007b96d4…" },
  { n: 7, hash: "00237a77…" },
];

// Scene 8 — the phone itself tilts and levels out, Steady Shot result, then the blockchain
export const Sensor: React.FC<Props> = ({ colors, screens, text, scene }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const w = (word: string) => wordFrame(scene, word, fps);
  const phoneIn = spring({ frame, fps, config: { damping: 18 } });
  const level = w("lurus") - 4;
  const steady = w("Steady") - 4;
  const chain = w("dicatat") - 4;
  const roll = interpolate(frame, [0, level - 20, level + 6], [7, 6, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.inOut(Easing.cubic),
  });

  return (
    <AbsoluteFill>
      <Background colors={colors} />
      <FeatureText
        eyebrow={text.eyebrow}
        title={text.title}
        highlight={text.highlight}
        primary={colors.primary}
        secondary={colors.secondary}
        left={120}
        width={600}
      />
      <PhoneMockup
        width={PHONE.width}
        tiltDeg={0}
        float={false}
        style={{
          position: "absolute",
          left: PHONE.left,
          top: PHONE.top,
          translate: `0px ${(1 - phoneIn) * 900}px`,
          rotate: `${roll}deg`,
        }}
      >
        <ScreenFlow
          screenWidth={SCREEN_W}
          screens={[
            { src: screens.levelTilt, at: 0 },
            { src: screens.levelFlat, at: level, mode: "fade" },
            { src: screens.steadyResult, at: steady },
            { src: screens.chainValid, at: chain },
          ]}
        />
      </PhoneMockup>

      {/* mini chain: blocks link up one after another */}
      <div style={{ position: "absolute", left: 1290, top: 250, display: "flex", flexDirection: "column", gap: 34 }}>
        {BLOCKS.map((b, i) => {
          const at = chain + 10 + i * 9;
          const p = spring({ frame: frame - at, fps, config: { damping: 14, mass: 0.6 } });
          const last = i === BLOCKS.length - 1;
          return (
            <div key={b.n} style={{ position: "relative", opacity: p, translate: `${(1 - p) * 80}px 0px` }}>
              {i > 0 && (
                <div
                  style={{
                    position: "absolute",
                    left: 60,
                    top: -34,
                    width: 6,
                    height: 34 * p,
                    borderRadius: 3,
                    background: colors.primary,
                  }}
                />
              )}
              <div
                style={{
                  width: 540,
                  padding: "22px 28px",
                  borderRadius: 24,
                  background: last ? `${colors.secondary}26` : "rgba(255,255,255,0.08)",
                  border: `2px solid ${last ? colors.secondary : "rgba(255,255,255,0.16)"}`,
                  fontFamily,
                  color: "white",
                  boxShadow: last ? `0 0 50px ${colors.secondary}55` : undefined,
                }}
              >
                <div style={{ fontSize: 36, fontWeight: 800 }}>
                  Block #{b.n} {last && <span style={{ color: colors.secondary }}>• Steady Shot ✓</span>}
                </div>
                <div style={{ fontSize: 28, fontWeight: 500, opacity: 0.7, marginTop: 6, fontVariantNumeric: "tabular-nums" }}>
                  hash {b.hash}
                </div>
              </div>
            </div>
          );
        })}
      </div>
    </AbsoluteFill>
  );
};
