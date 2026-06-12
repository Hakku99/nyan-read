/** Recessed-track segmented control; the selected segment is a floating paper chip that slides. */
export interface SegmentedTabControlProps {
  tabs: Array<{ label: string; icon?: string }>;
  /** Index of the active tab */
  selected: number;
  onChange: (index: number) => void;
  /** "emphasis" white sliding chip (default) | "subtle" matcha-tint chip */
  style?: "emphasis" | "subtle";
}
export declare const SegmentedTabControl: (props: SegmentedTabControlProps) => any;
