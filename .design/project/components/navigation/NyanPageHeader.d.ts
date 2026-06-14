/** Page title block: title + optional subtitle, leading slot, trailing actions row. */
export interface NyanPageHeaderProps {
  title: string;
  subtitle?: string;
  /** Leading slot (e.g. back button) */
  leading?: any;
  /** Trailing actions (icons / buttons) */
  actions?: any;
  /** Render the standard arrow-left button in the leading slot (ignored if `leading` is set) */
  back?: boolean;
  /** Handler for the convenience back button */
  onBack?: () => void;
  style?: object;
}
export declare const NyanPageHeader: (props: NyanPageHeaderProps) => any;
