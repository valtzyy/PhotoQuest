import { Audio } from "@remotion/media";
import { AbsoluteFill, Img, Sequence, spring, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { SHOT_WIDTH } from "./PhoneMockup";
import { TapIndicator } from "./TapIndicator";

export type FlowScreen = {
  src: string;
  // frame the screen starts entering (ignored for the first one)
  at: number;
  // push = native navigation, fade = same screen changing state
  mode?: "push" | "fade";
};

export type FlowTap = { x: number; y: number; at: number };

type Props = {
  screens: FlowScreen[];
  taps?: FlowTap[];
  // inner screen width in px, to map screenshot pixels to the mockup
  screenWidth: number;
  children?: React.ReactNode;
};

// Sequence of app screenshots inside a PhoneMockup, with tap ripples and native-like push
export const ScreenFlow: React.FC<Props> = ({ screens, taps = [], screenWidth, children }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const k = screenWidth / SHOT_WIDTH;
  const enter = (i: number) =>
    i === 0 ? 1 : spring({ frame: frame - screens[i].at, fps, config: { damping: 200 }, durationInFrames: 16 });

  return (
    <AbsoluteFill>
      {screens.map((s, i) => {
        if (i > 0 && frame < s.at) return null;
        const next = screens[i + 1];
        if (next && enter(i + 1) >= 1) return null; // fully covered
        const p = enter(i);
        const nextP = next ? enter(i + 1) : 0;
        const push = (s.mode ?? "push") === "push";
        const nextPush = next && (next.mode ?? "push") === "push";
        return (
          <AbsoluteFill
            key={s.src + i}
            style={{
              translate: `${push ? (1 - p) * 100 : 0}% 0px`,
              opacity: push ? 1 : p,
              filter: nextPush ? `brightness(${1 - nextP * 0.25})` : undefined,
              boxShadow: push && i > 0 ? "-20px 0 40px rgba(0,0,0,0.15)" : undefined,
            }}
          >
            <AbsoluteFill style={{ translate: nextPush ? `${-nextP * 30}% 0px` : undefined }}>
              <Img src={staticFile(s.src)} style={{ width: "100%", height: "100%", objectFit: "cover" }} />
            </AbsoluteFill>
          </AbsoluteFill>
        );
      })}
      {children}
      {taps.map((t) => (
        <TapIndicator key={t.at} x={t.x * k} y={t.y * k} at={t.at} />
      ))}
      {taps.map((t) => (
        <Sequence key={`sfx${t.at}`} from={t.at} layout="none" name="Tap sfx">
          <Audio src={staticFile("sfx/tap.mp3")} volume={0.6} />
        </Sequence>
      ))}
    </AbsoluteFill>
  );
};
