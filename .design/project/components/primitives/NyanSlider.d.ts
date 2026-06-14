/** Pointer-driven slider with ring thumb. Used for brightness / warmth / font size. */
export interface NyanSliderProps {
  value: number;
  /** Default 0 */
  min?: number;
  /** Default 100 */
  max?: number;
  /** Increment for drag-snap and arrow keys. Default 1 */
  step?: number;
  onChange: (value: number) => void;
  /** Track + thumb-ring accent. Default var(--nyan-primary-deep) */
  color?: string;
  /** Accessible name (role="slider"; supports Arrow / Home / End / PageUp / PageDown) */
  "aria-label"?: string;
  /** Disable interaction and dim to 40% */
  disabled?: boolean;
}
export declare const NyanSlider: (props: NyanSliderProps) => any;
