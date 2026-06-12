/** One Paper floating bottom sheet: warm scrim + blur, inset 12px, all four corners rounded. */
export interface NyanBottomSheetProps {
  open: boolean;
  onClose?: () => void;
  children?: any;
  /** CSS height for the sheet (e.g. "60%"); omit for content height capped at 85% */
  height?: string;
}
export declare const NyanBottomSheet: (props: NyanBottomSheetProps) => any;
