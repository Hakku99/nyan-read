/** Settings-style list row: tinted icon chip, title + subtitle, trailing slot or auto-chevron. */
export interface NyanListRowProps {
  icon?: string;
  title: string;
  subtitle?: string;
  /** Custom trailing node; omit for auto-chevron when onPress is set */
  trailing?: any;
  onPress?: () => void;
  /** Render title + icon in error tones */
  danger?: boolean;
  /** Drop the icon tile and inset the text — for sub-rows nested under a setting */
  indent?: boolean;
  /** Force the trailing chevron even without onPress */
  chevron?: boolean;
}
export declare const NyanListRow: (props: NyanListRowProps) => any;
