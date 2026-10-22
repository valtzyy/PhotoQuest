import { Composition } from "remotion";
import { PhotoQuestDemo } from "./PhotoQuestDemo";
import { demoSchema } from "./schema";
import { calculateMetadata } from "./timing";

export const RemotionRoot: React.FC = () => {
  return (
    <Composition
      id="PhotoQuestDemo"
      component={PhotoQuestDemo}
      schema={demoSchema}
      calculateMetadata={calculateMetadata}
      durationInFrames={300}
      fps={30}
      width={1920}
      height={1080}
      defaultProps={{
        colors: {
          primary: "#36A6E6",
          secondary: "#F5AA00",
          background: "#0B1424",
        },
        screens: {
          home: "screens/home.png",
          explore: "screens/explore.png",
          detail: "screens/detail.png",
          map: "screens/map.png",
          weather: "screens/weather.png",
          planForm: "screens/plan_form.png",
          planResult: "screens/plan_result.png",
          assistantEmpty: "screens/assistant_empty.png",
          assistantTyping: "screens/assistant_typing.png",
          assistantAnswer: "screens/assistant_answer.png",
          levelTilt: "screens/level_tilt.png",
          levelFlat: "screens/level_flat.png",
          steadyResult: "screens/steady_result.png",
          chainValid: "screens/chain_valid.png",
          quiz: "screens/quiz.png",
          converter: "screens/converter.png",
          feedback: "screens/feedback.png",
          profile: "screens/profile.png",
        },
        hook: {
          title: "Pernah sampai di spot foto, tapi cahayanya sudah hilang?",
          highlight: ["cahayanya", "hilang"],
        },
        problem: {
          heading: "Masalah fotografer pemula",
          pains: ["Bingung mau foto di mana", "Tidak tahu kapan cahaya terbaik", "Hasil foto goyang & miring"],
        },
        intro: {
          name: "PhotoQuest",
          tagline: "Teman berburu foto yang pintar untuk fotografer pemula",
        },
        explore: {
          eyebrow: "01 · Explore Spot",
          title: "Spot foto terbaik di Yogyakarta",
          highlight: ["Yogyakarta"],
          labels: ["Foto asli spot", "Tips memotret", "Info tiket", "Waktu terbaik"],
        },
        map: {
          eyebrow: "02 · Peta Terdekat",
          title: "Spot terdekat dari posisimu",
          highlight: ["terdekat"],
          labels: ["Posisimu (GPS)"],
        },
        weather: {
          eyebrow: "03 · Cuaca & Plan AI",
          title: "Tahu kapan cahaya terbaik datang",
          highlight: ["cahaya", "terbaik"],
          labels: ["Golden hour 7 hari", "Skor", "Rencana dari AI"],
        },
        assistant: {
          eyebrow: "04 · Asisten AI",
          title: "Tanya apa saja soal fotografi",
          highlight: ["fotografi"],
          labels: ["Pertanyaan cepat", "Dijawab Gemini AI"],
        },
        sensor: {
          eyebrow: "05 · Sensor & Steady Shot",
          title: "Lurus, stabil, tercatat di blockchain",
          highlight: ["blockchain"],
          labels: [],
        },
        more: {
          title: "Dan masih banyak lagi",
          labels: ["PhotoQuiz", "Konverter gear", "Saran & Kesan", "Login biometrik"],
        },
        summary: {
          title: "Semua dalam satu aplikasi",
          pillars: ["Lokasi", "Cuaca", "AI", "Sensor"],
        },
        cta: {
          tagline: "Temukan cahayamu.",
          footer: "Smart Photography Companion · Pemrograman Aplikasi Mobile",
        },
        showCaptions: true,
        vo: [],
      }}
    />
  );
};
