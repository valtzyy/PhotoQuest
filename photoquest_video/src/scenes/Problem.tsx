import { Audio } from "@remotion/media";
import { AbsoluteFill, Sequence, spring, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { Background } from "../components/Background";
import { fontFamily } from "../font";
import type { Colors, VoScene } from "../schema";
import { wordFrame } from "../timing";

type Props = {
  colors: Colors;
  heading: string;
  pains: readonly string[];
  scene: VoScene;
};

const MapPinIcon = () => (
  <svg viewBox="0 0 48 48" width="100%" height="100%" fill="none" stroke="white" strokeWidth="3.2" strokeLinecap="round" strokeLinejoin="round">
    <path d="M24 43s14-12.6 14-24a14 14 0 0 0-28 0c0 11.4 14 24 14 24z" />
    <path d="M20 16.5a4.2 4.2 0 1 1 5.6 4c-1.2.5-1.6 1.3-1.6 2.5v.8" />
    <circle cx="24" cy="28.5" r="0.6" fill="white" />
  </svg>
);

const SunClockIcon = () => (
  <svg viewBox="0 0 48 48" width="100%" height="100%" fill="none" stroke="white" strokeWidth="3.2" strokeLinecap="round">
    <circle cx="24" cy="24" r="10" />
    <path d="M24 18v6l4 3" />
    <path d="M24 4v4M24 40v4M4 24h4M40 24h4M9.9 9.9l2.8 2.8M35.3 35.3l2.8 2.8M9.9 38.1l2.8-2.8M35.3 12.7l2.8-2.8" />
  </svg>
);

const ShakyCameraIcon = () => (
  <svg viewBox="0 0 48 48" width="100%" height="100%" fill="none" stroke="white" strokeWidth="3.2" strokeLinejoin="round" strokeLinecap="round">
    <path d="M17 13l3-4h8l3 4h7a4 4 0 0 1 4 4v18a4 4 0 0 1-4 4H10a4 4 0 0 1-4-4V17a4 4 0 0 1 4-4z" />
    <circle cx="24" cy="26" r="7" />
    <path d="M2 20v12M46 20v12" opacity="0.7" />
  </svg>
);

const ICONS = [MapPinIcon, SunClockIcon, ShakyCameraIcon];
const ICON_BG = ["#E5484D", "#F5AA00", "#36A6E6"];
// first word of each pain point in the VO, used to time the card entrance
const CUE_WORDS = ["Bingung", "tidak", "hasilnya"];

// Scene 2 — three pain-point cards appear exactly when the VO mentions them
export const Problem: React.FC<Props> = ({ colors, heading, pains, scene }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const headingIn = spring({ frame, fps, config: { damping: 200 } });

  return (
    <AbsoluteFill>
      <Background colors={colors} />
      <AbsoluteFill style={{ alignItems: "center", paddingTop: 150 }}>
        <div
          style={{
            fontFamily,
            fontSize: 40,
            fontWeight: 700,
            letterSpacing: "0.18em",
            textTransform: "uppercase",
            color: colors.primary,
            opacity: headingIn,
            translate: `0px ${(1 - headingIn) * 30}px`,
          }}
        >
          {heading}
        </div>
      </AbsoluteFill>
      <AbsoluteFill style={{ flexDirection: "row", justifyContent: "center", alignItems: "center", gap: 48, paddingBottom: 40 }}>
        {pains.map((pain, i) => {
          const at = wordFrame(scene, CUE_WORDS[i] ?? "", fps);
          const p = spring({ frame: frame - at, fps, config: { damping: 13, mass: 0.7 } });
          const Icon = ICONS[i % ICONS.length];
          // the "shaky" card keeps wobbling
          const shake = i === 2 && frame > at ? Math.sin(frame * 1.7) * 4 : 0;
          return (
            <div
              key={i}
              style={{
                width: 470,
                height: 420,
                borderRadius: 40,
                padding: 44,
                background: "linear-gradient(160deg, rgba(255,255,255,0.12), rgba(255,255,255,0.04))",
                border: "1.5px solid rgba(255,255,255,0.14)",
                boxShadow: "0 40px 80px rgba(0,0,0,0.35)",
                display: "flex",
                flexDirection: "column",
                justifyContent: "space-between",
                opacity: Math.min(1, p * 1.4),
                translate: `${shake}px ${(1 - p) * 120}px`,
                scale: String(0.8 + 0.2 * p),
                rotate: `${shake * 0.5}deg`,
              }}
            >
              <div style={{ width: 120, height: 120, borderRadius: 32, background: ICON_BG[i % ICON_BG.length], padding: 26, boxShadow: `0 16px 40px ${ICON_BG[i % ICON_BG.length]}66` }}>
                <Icon />
              </div>
              <div style={{ fontFamily, fontSize: 48, fontWeight: 700, color: "white", lineHeight: 1.18 }}>{pain}</div>
            </div>
          );
        })}
      </AbsoluteFill>
      {CUE_WORDS.map((w, i) => (
        <Sequence key={w} from={wordFrame(scene, w, fps)} layout="none" name={`Pop ${i + 1}`}>
          <Audio src={staticFile("sfx/pop.mp3")} volume={0.5} />
        </Sequence>
      ))}
    </AbsoluteFill>
  );
};
