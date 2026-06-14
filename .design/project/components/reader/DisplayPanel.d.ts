/** Reader settings panel: brightness, warmth, page-turn mode. */
export interface DisplayPanelProps {
  /** Reader preference state object (brightness, warmth, fontSize, lineHeight, serif, readerTheme, ...) */
  t: { [key: string]: any };
  /** Replace the whole preference object */
  setT: (next: { [key: string]: any }) => void;
}
export declare const DisplayPanel: (props: DisplayPanelProps) => any;
