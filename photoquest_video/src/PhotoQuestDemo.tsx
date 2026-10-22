import { Audio } from "@remotion/media";
import { linearTiming, TransitionSeries } from "@remotion/transitions";
import { fade } from "@remotion/transitions/fade";
import { slide } from "@remotion/transitions/slide";
import { wipe } from "@remotion/transitions/wipe";
import { AbsoluteFill, interpolate, Sequence, staticFile, useVideoConfig } from "remotion";
import { Captions } from "./components/Captions";
import type { DemoProps, VoScene } from "./schema";
import { Assistant } from "./scenes/Assistant";
import { Cta } from "./scenes/Cta";
import { Explore } from "./scenes/Explore";
import { Hook } from "./scenes/Hook";
import { Intro } from "./scenes/Intro";
import { MoreFeatures } from "./scenes/MoreFeatures";
import { NearbyMap } from "./scenes/NearbyMap";
import { Problem } from "./scenes/Problem";
import { Sensor } from "./scenes/Sensor";
import { Summary } from "./scenes/Summary";
import { WeatherPlan } from "./scenes/WeatherPlan";
import { sceneStarts, TRANSITION, VO_START } from "./timing";

const timing = linearTiming({ durationInFrames: TRANSITION });

// Voice-over + subtitles shared by every scene
const SceneVo: React.FC<{ scene: VoScene; show: boolean; color: string; centerX?: number }> = ({
  scene,
  show,
  color,
  centerX,
}) => (
  <>
    <Sequence from={VO_START} layout="none" name={`VO ${scene.id}`}>
      <Audio src={staticFile(`vo/${scene.id}.mp3`)} />
    </Sequence>
    {show && <Captions scene={scene} offset={VO_START} activeColor={color} centerX={centerX} />}
  </>
);

export const PhotoQuestDemo: React.FC<DemoProps> = (props) => {
  const { colors, screens, vo, showCaptions } = props;
  const { durationInFrames } = useVideoConfig();
  if (vo.length === 0) return null; // filled by calculateMetadata()

  const starts = sceneStarts(vo);
  const [hook, problem, intro, explore, map, weather, assistant, sensor, more, summary, cta] = vo;
  const gold = colors.secondary;

  // Music ducks from 0.15 to 0.08 while the VO is speaking
  const musicVolume = (f: number) => {
    const duck = Math.max(
      0,
      ...vo.map((s, i) => {
        const a = starts[i] + VO_START;
        const b = a + s.audioFrames;
        return interpolate(f, [a - 8, a, b, b + 12], [0, 1, 1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
      }),
    );
    const fadeOut = interpolate(f, [durationInFrames - 45, durationInFrames], [1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
    return (0.15 - 0.07 * duck) * fadeOut;
  };

  return (
    <AbsoluteFill style={{ backgroundColor: colors.background }}>
      <TransitionSeries>
        <TransitionSeries.Sequence name="1 Hook" durationInFrames={hook.sceneFrames}>
          <Hook colors={colors} title={props.hook.title} highlight={props.hook.highlight} />
          <SceneVo scene={hook} show={showCaptions} color={gold} />
        </TransitionSeries.Sequence>
        <TransitionSeries.Transition presentation={fade()} timing={timing} />
        <TransitionSeries.Sequence name="2 Masalah" durationInFrames={problem.sceneFrames}>
          <Problem colors={colors} heading={props.problem.heading} pains={props.problem.pains} scene={problem} />
          <SceneVo scene={problem} show={showCaptions} color={gold} />
        </TransitionSeries.Sequence>
        <TransitionSeries.Transition presentation={slide({ direction: "from-right" })} timing={timing} />
        <TransitionSeries.Sequence name="3 Perkenalan" durationInFrames={intro.sceneFrames}>
          <Intro colors={colors} name={props.intro.name} tagline={props.intro.tagline} homeScreen={screens.home} />
          <SceneVo scene={intro} show={showCaptions} color={gold} centerX={570} />
        </TransitionSeries.Sequence>
        <TransitionSeries.Transition presentation={wipe({ direction: "from-left" })} timing={timing} />
        <TransitionSeries.Sequence name="4 Explore" durationInFrames={explore.sceneFrames}>
          <Explore colors={colors} screens={screens} text={props.explore} scene={explore} />
          <SceneVo scene={explore} show={showCaptions} color={gold} centerX={410} />
        </TransitionSeries.Sequence>
        <TransitionSeries.Transition presentation={slide({ direction: "from-right" })} timing={timing} />
        <TransitionSeries.Sequence name="5 Peta" durationInFrames={map.sceneFrames}>
          <NearbyMap colors={colors} screens={screens} text={props.map} scene={map} />
          <SceneVo scene={map} show={showCaptions} color={gold} centerX={1370} />
        </TransitionSeries.Sequence>
        <TransitionSeries.Transition presentation={slide({ direction: "from-left" })} timing={timing} />
        <TransitionSeries.Sequence name="6 Cuaca & Plan" durationInFrames={weather.sceneFrames}>
          <WeatherPlan colors={colors} screens={screens} text={props.weather} scene={weather} />
          <SceneVo scene={weather} show={showCaptions} color={gold} centerX={510} />
        </TransitionSeries.Sequence>
        <TransitionSeries.Transition presentation={slide({ direction: "from-right" })} timing={timing} />
        <TransitionSeries.Sequence name="7 Asisten" durationInFrames={assistant.sceneFrames}>
          <Assistant colors={colors} screens={screens} text={props.assistant} scene={assistant} />
          <SceneVo scene={assistant} show={showCaptions} color={gold} centerX={1490} />
        </TransitionSeries.Sequence>
        <TransitionSeries.Transition presentation={wipe({ direction: "from-right" })} timing={timing} />
        <TransitionSeries.Sequence name="8 Sensor" durationInFrames={sensor.sceneFrames}>
          <Sensor colors={colors} screens={screens} text={props.sensor} scene={sensor} />
          <SceneVo scene={sensor} show={showCaptions} color={gold} centerX={420} />
        </TransitionSeries.Sequence>
        <TransitionSeries.Transition presentation={fade()} timing={timing} />
        <TransitionSeries.Sequence name="9 Lainnya" durationInFrames={more.sceneFrames}>
          <MoreFeatures colors={colors} screens={screens} title={props.more.title} labels={props.more.labels} scene={more} />
          <SceneVo scene={more} show={showCaptions} color={gold} />
        </TransitionSeries.Sequence>
        <TransitionSeries.Transition presentation={slide({ direction: "from-bottom" })} timing={timing} />
        <TransitionSeries.Sequence name="10 Ringkasan" durationInFrames={summary.sceneFrames}>
          <Summary colors={colors} screens={screens} title={props.summary.title} pillars={props.summary.pillars} scene={summary} />
          <SceneVo scene={summary} show={false} color={gold} />
        </TransitionSeries.Sequence>
        <TransitionSeries.Transition presentation={fade()} timing={timing} />
        <TransitionSeries.Sequence name="11 CTA" durationInFrames={cta.sceneFrames}>
          <Cta colors={colors} name={props.intro.name} tagline={props.cta.tagline} footer={props.cta.footer} scene={cta} />
          <SceneVo scene={cta} show={false} color={gold} />
        </TransitionSeries.Sequence>
      </TransitionSeries>

      <Audio name="Music" src={staticFile("music.mp3")} volume={musicVolume} />
      {/* whoosh on every scene change */}
      {starts.slice(1).map((s, i) => (
        <Sequence key={s} from={s - 4} layout="none" name={`Whoosh ${i + 1}`}>
          <Audio src={staticFile("sfx/whoosh.mp3")} volume={0.35} />
        </Sequence>
      ))}
    </AbsoluteFill>
  );
};
