import { spring, useCurrentFrame, useVideoConfig } from "remotion";
import { fontFamily } from "../font";
import { KineticTitle } from "./KineticTitle";

type Props = {
  eyebrow: string;
  title: string;
  highlight: readonly string[];
  primary: string;
  secondary: string;
  left: number;
  width: number;
  top?: number;
};

// Feature heading block: numbered pill + kinetic title (left aligned)
export const FeatureText: React.FC<Props> = ({ eyebrow, title, highlight, primary, secondary, left, width, top = 330 }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const pill = spring({ frame: frame - 4, fps, config: { damping: 200 } });

  return (
    <div style={{ position: "absolute", left, top, width }}>
      <div
        style={{
          display: "inline-block",
          fontFamily,
          fontSize: 32,
          fontWeight: 700,
          letterSpacing: "0.08em",
          textTransform: "uppercase",
          color: primary,
          padding: "10px 24px",
          borderRadius: 999,
          border: `2px solid ${primary}66`,
          background: `${primary}1f`,
          opacity: pill,
          translate: `${(1 - pill) * -40}px 0px`,
          marginBottom: 34,
        }}
      >
        {eyebrow}
      </div>
      <KineticTitle
        text={title}
        highlight={highlight}
        highlightColor={secondary}
        fontSize={80}
        delay={10}
        style={{ justifyContent: "flex-start" }}
      />
    </div>
  );
};
