/** Bottom sheet for "pick one" (radio) or "do one" (action rows). Selecting fires onSelect then onClose. */
export interface NyanOptionSheetProps {
  title: string;
  subtitle?: string;
  options?: Array<string | { label: string; hint?: string; swatch?: string; icon?: string }>;
  /** Selected index (radio variant). Default 0 */
  selected?: number;
  /** "radio" single-select list (default) | "action" icon rows */
  variant?: "radio" | "action";
  /** Play the scrim-fade + slide-up entrance. Default true; set false for static mocks/thumbnails. */
  animateIn?: boolean;
  /** Fires with the tapped option index, before onClose */
  onSelect?: (index: number) => void;
  /** Dismiss handler (scrim tap + option select) */
  onClose?: () => void;
  style?: object;
}
export declare const NyanOptionSheet: (props: NyanOptionSheetProps) => any;
