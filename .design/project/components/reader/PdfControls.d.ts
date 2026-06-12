/** PDF-only floating pill: zoom stepper + "page X of N" jump. 44px steppers; page field opens a go-to prompt. */
export interface PdfControlsProps {
  /** Current page (1-based) */
  page?: number;
  pageCount?: number;
  /** Zoom factor, 1 = 100% */
  zoom?: number;
  /** Default 0.5 */
  minZoom?: number;
  /** Default 3 */
  maxZoom?: number;
  /** Default 0.25 */
  zoomStep?: number;
  onZoom?: (zoom: number) => void;
  onPage?: (page: number) => void;
  /** Tap the page field — open a go-to-page prompt */
  onGoToPage?: () => void;
  style?: object;
}
export declare const PdfControls: (props: PdfControlsProps) => any;
