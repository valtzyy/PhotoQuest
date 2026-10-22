import { AbsoluteFill, Easing, interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { Background } from "../components/Background";
import { Callout } from "../components/Callout";
import { FeatureText } from "../components/FeatureText";
import { PhoneMockup, phonePoint } from "../components/PhoneMockup";
import { ScreenFlow } from "../components/ScreenFlow";
import type { Colors, Feature, Screens, VoScene } from "../schema";
import { wordFrame } from "../timing";

type Props = { colors: Colors; screens: Screens; text: Feature; scene: VoScene };

const PHONE = { left: 1300, top: 70, width: 420 };
const SCREEN_W = PHONE.width * 0.93;
const SCORE = 87;

// Scene 6 — weather & golden hour, then Plan (AI): analyse -> score count-up -> AI advice
export const WeatherPlan: React.FC<Props> = ({ colors, screens, text, scene }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const w = (word: string) => wordFrame(scene, word, fps);
  const phoneIn = spring({ frame, fps, config: { damping: 18 } });
  const openPlan = w("PhotoQuest") - 6;
  const analyse = w("skor") - 8;
  const [lGolden, lScore, lAi] = text.labels;
  const count = Math.round(
    interpolate(frame, [analyse + 8, analyse + 38], [0, SCORE], {
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
      easing: Easing.out(Easing.cubic),
    }),
  );

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
        width={780}
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
            { src: screens.weather, at: 0 },
            { src: screens.planForm, at: openPlan },
            { src: screens.planResult, at: analyse + 6, mode: "fade" },
          ]}
          taps={[{ x: 540, y: 1834, at: analyse }]}
        />
      </PhoneMockup>
      <Callout
        {...phonePoint(PHONE, 120, 868)}
        label={lGolden}
        at={w("golden") - 4}
        until={openPlan - 4}
        side="left"
        length={160}
        color={colors.secondary}
      />
      <Callout {...phonePoint(PHONE, 330, 484)} label={`${lScore} ${count}`} at={analyse + 8} side="left" length={160} color={colors.secondary} />
      <Callout {...phonePoint(PHONE, 640, 1722)} label={lAi} at={w("AI") - 4} side="left" length={250} color={colors.secondary} />
    </AbsoluteFill>
  );
};
