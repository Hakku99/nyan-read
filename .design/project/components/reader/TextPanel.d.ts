/** Reader settings panel: font size stepper+slider, line height, font family + live preview. */
export interface TextPanelProps {
  /** Reader preference state object (brightness, warmth, fontSize, lineHeight, serif, readerTheme, ...) */
  t: { [key: string]: any };
  /** Replace the whole preference object */
  setT: (next: { [key: string]: any }) => void;
}
export declare const TextPanel: (props: TextPanelProps) => any;
