import { AbsoluteFill, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { Background } from "../components/Background";
import { Callout } from "../components/Callout";
import { FeatureText } from "../components/FeatureText";
import { PhoneMockup, phonePoint } from "../components/PhoneMockup";
import { ScreenFlow } from "../components/ScreenFlow";
import type { Colors, Feature, Screens, VoScene } from "../schema";
import { wordFrame } from "../timing";

type Props = { colors: Colors; screens: Screens; text: Feature; scene: VoScene };

const PHONE = { left: 600, top: 70, width: 420 };
const SCREEN_W = PHONE.width * 0.93;

// Scene 7 — tap a suggested question, "typing…", then the AI answer arrives
export const Assistant: React.FC<Props> = ({ colors, screens, text, scene }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const w = (word: string) => wordFrame(scene, word, fps);
  const phoneIn = spring({ frame, fps, config: { damping: 18 } });
  const ask = w("Tanyakan") - 6;
  const answer = w("berbasis") - 4;

  return (
    <AbsoluteFill>
      <Background colors={colors} />
      <FeatureText
        eyebrow={text.eyebrow}
        title={text.title}
        highlight={text.highlight}
        primary={colors.primary}
        secondary={colors.secondary}
        left={1150}
        width={680}
      />
      <PhoneMockup
        width={PHONE.width}
        tiltDeg={0}
        float={false}
        style={{ position: "absolute", left: PHONE.left, top: PHONE.top, translate: `0px ${(1 - phoneIn) * 900}px` }}
      >
        <ScreenFlow
          screenWidth={SCREEN_W}
          screens={[
            { src: screens.assistantEmpty, at: 0 },
            { src: screens.assistantTyping, at: ask + 4, mode: "fade" },
            { src: screens.assistantAnswer, at: answer, mode: "fade" },
          ]}
          taps={[{ x: 432, y: 942, at: ask }]}
        />
      </PhoneMockup>
      <Callout {...phonePoint(PHONE, 120, 942)} label={text.labels[0]} at={ask - 24} until={ask + 2} side="left" length={140} color={colors.secondary} />
      <Callout {...phonePoint(PHONE, 90, 1100)} label={text.labels[1]} at={answer + 6} side="left" length={140} color={colors.secondary} />
    </AbsoluteFill>
  );
};
