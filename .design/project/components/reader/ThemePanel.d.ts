/** Reader settings panel: 2x2 reading-theme swatch grid (cream / sepia / sumi / charcoal). */
export interface ThemePanelProps {
  /** Reader preference state object (brightness, warmth, fontSize, lineHeight, serif, readerTheme, ...) */
  t: { [key: string]: any };
  /** Replace the whole preference object */
  setT: (next: { [key: string]: any }) => void;
}
export declare const ThemePanel: (props: ThemePanelProps) => any;
