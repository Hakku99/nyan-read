/** Row for action sheets: tinted icon chip, title + subtitle, optional chevron. */
export interface NyanActionSheetRowProps {
  icon: string;
  title: string;
  subtitle?: string;
  onPress?: () => void;
  /** Default true */
  showChevron?: boolean;
}
export declare const NyanActionSheetRow: (props: NyanActionSheetRowProps) => any;
