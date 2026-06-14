/** Chromeless settings body: Display / Text / Theme tab switcher + active panel. Host inside OnePaperDock. */
export interface ReaderSettingsBodyProps {
  t: { [key: string]: any };
  setT: (next: { [key: string]: any }) => void;
  /** Active tab index: 0 Display, 1 Text, 2 Theme */
  tab: number;
  setTab: (index: number) => void;
}
export declare const ReaderSettingsBody: (props: ReaderSettingsBodyProps) => any;
