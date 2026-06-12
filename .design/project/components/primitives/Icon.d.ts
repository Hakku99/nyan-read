/** Phosphor Regular icon. Accepts Material-style names (menu_book) and maps them to Phosphor kebab-case. */
export interface IconProps {
  /** Material-style (menu_book) or Phosphor kebab-case (book-open) icon name */
  name: string;
  /** Font size in px. Default 20 */
  size?: number;
  /** Any CSS color. Default var(--nyan-text) */
  color?: string;
  /** Phosphor weight class: "regular" (default) | "fill" | "bold" | "thin" | "light" | "duotone" */
  weight?: "regular" | "thin" | "light" | "bold" | "fill" | "duotone";
  /** Accessible name; when onClick is set the icon becomes role="button" + focusable */
  "aria-label"?: string;
  style?: object;
  onClick?: () => void;
}
export declare const Icon: (props: IconProps) => any;
