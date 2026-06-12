/** Collapsible Continue Reading card: header toggles; expanded shows cover, progress, full-width CTA. */
export interface NyanContinueReadingCardProps {
  book: { title: string; author?: string; /** 0-1 */ progress: number };
  onContinue?: () => void;
  collapsed?: boolean;
  /** Omit to hide the collapse caret */
  onToggleCollapse?: () => void;
  /** Eyebrow label. Default "Continue Reading" — pass a localized string */
  eyebrow?: string;
  /** CTA label. Default "Continue Reading" — pass a localized string */
  continueLabel?: string;
}
export declare const NyanContinueReadingCard: (props: NyanContinueReadingCardProps) => any;
