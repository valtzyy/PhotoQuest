import { AbsoluteFill, interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { Background } from "../components/Background";
import { Callout } from "../components/Callout";
import { Camera } from "../components/Camera";
import { FeatureText } from "../components/FeatureText";
import { PhoneMockup, phonePoint, SHOT_WIDTH } from "../components/PhoneMockup";
import { ScreenFlow } from "../components/ScreenFlow";
import type { Colors, Feature, Screens, VoScene } from "../schema";
import { wordFrame } from "../timing";

type Props = { colors: Colors; screens: Screens; text: Feature; scene: VoScene };

const PHONE = { left: 330, top: 70, width: 420 };
const SCREEN_W = PHONE.width * 0.93;
// "Tugu Jogja" marker (= demo GPS position) in the map screenshot
const MARKER = { x: 540, y: 1027 };

// Scene 5 — open the nearby map, GPS pulse on your position, camera pushes in
export const NearbyMap: React.FC<Props> = ({ colors, screens, text, scene }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const w = (word: string) => wordFrame(scene, word, fps);
  const phoneIn = spring({ frame, fps, config: { damping: 18 } });
  const openMap = w("GPS") - 2;
  const focus = phonePoint(PHONE, MARKER.x, MARKER.y);
  const k = SCREEN_W / SHOT_WIDTH;
  const pulse = (Math.max(0, frame - openMap) % 36) / 36;
  const gpsIn = interpolate(frame, [openMap + 16, openMap + 24], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });

  return (
    <AbsoluteFill>
      <Background colors={colors} />
      <FeatureText
        eyebrow={text.eyebrow}
        title={text.title}
        highlight={text.highlight}
        primary={colors.primary}
        secondary={colors.secondary}
        left={960}
        width={820}
      />
      <Camera focusX={focus.x} focusY={focus.y} scale={1.5} from={w("terdekat") - 6}>
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
              { src: screens.map, at: openMap + 6 },
            ]}
            taps={[{ x: 540, y: 1277, at: openMap }]}
          >
            {/* live GPS pulse on the user's position */}
            <div style={{ position: "absolute", left: MARKER.x * k - 40, top: MARKER.y * k - 40, width: 80, height: 80, opacity: gpsIn }}>
              <div
                style={{
                  position: "absolute",
                  inset: 0,
                  borderRadius: "50%",
                  background: colors.primary,
                  scale: String(0.3 + pulse * 1.4),
                  opacity: 0.6 * (1 - pulse),
                }}
              />
            </div>
          </ScreenFlow>
        </PhoneMockup>
      </Camera>
      <Callout {...focus} label={text.labels[0]} at={w("posisimu") - 2} side="left" length={150} color={colors.secondary} />
    </AbsoluteFill>
  );
};
