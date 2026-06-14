/* ============================================================================
   Nyan Read — TTSPlayer
   Compiled into the DS bundle; consume as window.<Namespace>.TTSPlayer.
   Props contract: ./TTSPlayer.d.ts
   ============================================================================ */

import { Icon } from "../primitives/Icon.jsx";

const { useRef } = React;

/* ── Read-aloud player (U17) ──────────────────────────────────────────────────
   The Read Aloud transport, designed to drop inside a NyanBottomSheet. Header
   (title + chapter + voice chip), a draggable progress scrubber with times, a
   speed segmented control, and the play / skip transport. Fully controlled — the
   caller owns playing / progress / speed and the speech engine; this is the UI. */
const TTS_SPEEDS = ["0.75×", "1.0×", "1.25×", "1.5×"];

const TTSPlayer = ({
  title = "Read Aloud", chapter, voice = "System Voice",
  playing = false, onTogglePlay, onSkipBack, onSkipForward,
  progress = 0, onSeek, elapsed = "0:00", remaining = "0:00",
  speeds = TTS_SPEEDS, speedIndex = 1, onSpeed, onVoice, style,
}) => {
  const trackRef = useRef(null);
  const pct = Math.round(progress * 100);
  const seek = (clientX) => {
    if (!trackRef.current || !onSeek) return;
    const r = trackRef.current.getBoundingClientRect();
    onSeek(Math.max(0, Math.min(1, (clientX - r.left) / r.width)));
  };
  return (
    <div style={{ padding: "4px 20px 8px", display: "flex", flexDirection: "column", gap: 16, ...style }}>
      {/* Header */}
      <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: 12 }}>
        <div style={{ minWidth: 0 }}>
          <div style={{ font: "600 17px/1.2 var(--font-ui)", color: "var(--nyan-text)", letterSpacing: "-0.1px" }}>{title}</div>
          {chapter && <div style={{ font: "400 13px/1.3 var(--font-ui)", color: "var(--nyan-text-secondary)", marginTop: 2, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{chapter}</div>}
        </div>
        <button onClick={onVoice} style={{ all: "unset", cursor: onVoice ? "pointer" : "default", height: 34, padding: "0 12px", borderRadius: 999, background: "color-mix(in srgb, var(--nyan-primary) 10%, var(--nyan-surface-muted))", border: "1px solid color-mix(in srgb, var(--nyan-primary) 18%, transparent)", display: "flex", alignItems: "center", gap: 6, flexShrink: 0 }}>
          <Icon name="user-sound" size={14} color="var(--nyan-primary)" />
          <span style={{ font: "500 13px/1 var(--font-ui)", color: "var(--nyan-primary-deep)" }}>{voice}</span>
        </button>
      </div>

      {/* Scrubber */}
      <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
        <div
          ref={trackRef}
          onMouseDown={(e) => { seek(e.clientX); const mv = (ev) => seek(ev.clientX); const up = () => { window.removeEventListener("mousemove", mv); window.removeEventListener("mouseup", up); }; window.addEventListener("mousemove", mv); window.addEventListener("mouseup", up); }}
          style={{ position: "relative", height: 14, cursor: "pointer", display: "flex", alignItems: "center" }}
        >
          <div style={{ position: "absolute", left: 0, right: 0, height: 6, borderRadius: 8, background: "color-mix(in srgb, var(--nyan-divider) 30%, var(--nyan-surface-muted))" }} />
          <div style={{ position: "absolute", left: 0, height: 6, width: `${pct}%`, borderRadius: 8, background: "var(--nyan-primary)" }} />
          <div style={{ position: "absolute", left: `calc(${pct}% - 7px)`, width: 14, height: 14, borderRadius: 8, background: "var(--nyan-primary)", border: "1.2px solid color-mix(in srgb, var(--nyan-surface) 82%, transparent)" }} />
        </div>
        <div style={{ display: "flex", justifyContent: "space-between" }}>
          <span style={{ font: "400 12px/1 var(--font-ui)", color: "var(--nyan-text-muted)", fontVariantNumeric: "tabular-nums" }}>{elapsed}</span>
          <span style={{ font: "400 12px/1 var(--font-ui)", color: "var(--nyan-text-muted)", fontVariantNumeric: "tabular-nums" }}>{remaining}</span>
        </div>
      </div>

      {/* Speed */}
      <div style={{ display: "flex", background: "var(--nyan-surface-muted)", borderRadius: 14, padding: 3, gap: 2 }}>
        {speeds.map((s, i) => (
          <button key={s} onClick={() => onSpeed && onSpeed(i)} style={{ all: "unset", cursor: "pointer", flex: 1, height: 32, borderRadius: 11, background: speedIndex === i ? "var(--nyan-surface)" : "transparent", boxShadow: speedIndex === i ? "var(--shadow-subtle)" : "none", font: `${speedIndex === i ? 600 : 500} 13px/1 var(--font-ui)`, color: speedIndex === i ? "var(--nyan-text)" : "var(--nyan-text-muted)", display: "grid", placeItems: "center", transition: "background 160ms ease" }}>{s}</button>
        ))}
      </div>

      {/* Transport */}
      <div style={{ display: "flex", alignItems: "center", justifyContent: "center", gap: 22 }}>
        <button onClick={onSkipBack} aria-label="Skip back" style={{ all: "unset", cursor: "pointer", width: 44, height: 44, borderRadius: "50%", display: "grid", placeItems: "center" }}>
          <Icon name="skip-back" size={24} color="var(--nyan-text-secondary)" />
        </button>
        <button onClick={onTogglePlay} aria-label={playing ? "Pause" : "Play"} style={{ all: "unset", cursor: "pointer", width: 60, height: 60, borderRadius: "50%", background: "var(--nyan-primary)", display: "grid", placeItems: "center", boxShadow: "var(--shadow-light-card)" }}>
          <Icon name={playing ? "pause" : "play"} size={26} color="var(--nyan-surface)" weight="fill" />
        </button>
        <button onClick={onSkipForward} aria-label="Skip forward" style={{ all: "unset", cursor: "pointer", width: 44, height: 44, borderRadius: "50%", display: "grid", placeItems: "center" }}>
          <Icon name="skip-forward" size={24} color="var(--nyan-text-secondary)" />
        </button>
      </div>
    </div>
  );
};

export { TTSPlayer };
