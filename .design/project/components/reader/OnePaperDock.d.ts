/** Floating panel that is a DOCK collapsed and a SHEET grown. Extra props pass through to DockFooter. */
export interface OnePaperDockProps {
  /** Slide the whole dock off-canvas (immersive mode). Default true */
  visible?: boolean;
  /** Grow the dock into a sheet. Default false */
  sheetOpen?: boolean;
  /** Sheet heading */
  title?: string;
  /** Right-aligned meta line next to the title */
  meta?: string;
  /** Sheet body content */
  children?: any;
  /** Default 520 */
  maxSheetHeight?: number;
  /** Swallow clicks so the canvas tap-to-dismiss doesn't fire. Default true */
  onStopProp?: boolean;
  /** Plus all DockFooter props (chapterIndex, chapterCount, progress, onAction, ...) spread through */
  [footerProp: string]: any;
}
export declare const OnePaperDock: (props: OnePaperDockProps) => any;
