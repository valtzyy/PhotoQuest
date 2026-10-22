import { spring, useCurrentFrame, useVideoConfig } from "remotion";
import { fontFamily } from "../font";

type Props = {
  text: string;
  // words (case-insensitive, punctuation ignored) painted in highlightColor
  highlight?: readonly string[];
  highlightColor: string;
  fontSize: number;
  delay?: number;
  // frames between words
  stagger?: number;
  style?: React.CSSProperties;
};

const clean = (w: string) => w.toLowerCase().replace(/[^\p{L}\p{N}]/gu, "");

// Title that pops in word by word with a spring
export const KineticTitle: React.FC<Props> = ({
  text,
  highlight = [],
  highlightColor,
  fontSize,
  delay = 0,
  stagger = 4,
  style,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const marks = highlight.map(clean);

  return (
    <div
      style={{
        fontFamily,
        fontSize,
        fontWeight: 800,
        lineHeight: 1.12,
        letterSpacing: "-0.02em",
        color: "white",
        display: "flex",
        flexWrap: "wrap",
        justifyContent: "center",
        columnGap: fontSize * 0.28,
        ...style,
      }}
    >
      {text.split(" ").map((word, i) => {
        const p = spring({ frame: frame - delay - i * stagger, fps, config: { damping: 14, mass: 0.6 } });
        const isMark = marks.includes(clean(word));
        return (
          <span
            key={i}
            style={{
              display: "inline-block",
              opacity: Math.min(1, p * 1.5),
              translate: `0px ${(1 - p) * fontSize * 0.6}px`,
              scale: String(0.85 + 0.15 * p),
              color: isMark ? highlightColor : undefined,
            }}
          >
            {word}
          </span>
        );
      })}
    </div>
  );
};
