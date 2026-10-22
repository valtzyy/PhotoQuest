import { AbsoluteFill, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { Background } from "../components/Background";
import { Callout } from "../components/Callout";
import { FeatureText } from "../components/FeatureText";
import { PhoneMockup, phonePoint } from "../components/PhoneMockup";
import { ScreenFlow } from "../components/ScreenFlow";
import type { Colors, Feature, Screens, VoScene } from "../schema";
import { wordFrame } from "../timing";

type Props = { colors: Colors; screens: Screens; text: Feature; scene: VoScene };

const PHONE = { left: 760, top: 70, width: 420 };
const SCREEN_W = PHONE.width * 0.93;

// Scene 4 — Home -> Explore list -> spot detail, then callouts on the detail page
export const Explore: React.FC<Props> = ({ colors, screens, text, scene }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const w = (word: string) => wordFrame(scene, word, fps);
  const phoneIn = spring({ frame, fps, config: { damping: 18 } });
  const openList = w("spot") - 4;
  const openDetail = w("Lengkap") - 18;
  const [lPhoto, lTips, lTicket, lTime] = text.labels;

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
        width={580}
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
            { src: screens.home, at: 0 },
            { src: screens.explore, at: openList + 6 },
            { src: screens.detail, at: openDetail + 6 },
          ]}
          taps={[
            { x: 199, y: 1277, at: openList },
            { x: 540, y: 821, at: openDetail },
          ]}
        />
      </PhoneMockup>
      <Callout {...phonePoint(PHONE, 760, 420)} label={lPhoto} at={w("asli") - 4} length={190} color={colors.secondary} />
      <Callout {...phonePoint(PHONE, 760, 811)} label={lTime} at={w("waktu") - 4} length={190} color={colors.secondary} />
      <Callout {...phonePoint(PHONE, 900, 1509)} label={lTips} at={w("tips") - 4} length={130} color={colors.secondary} />
      <Callout {...phonePoint(PHONE, 700, 1766)} label={lTicket} at={w("harga") - 4} length={220} color={colors.secondary} />
    </AbsoluteFill>
  );
};
