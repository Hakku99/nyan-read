/** Centered empty state: tinted icon tile, title, description, optional action. */
export interface NyanEmptyStateProps {
  /** Icon name, or a custom node */
  icon?: string | any;
  title: string;
  description?: string;
  /** Action node (e.g. NyanPrimaryButton) */
  action?: any;
}
export declare const NyanEmptyState: (props: NyanEmptyStateProps) => any;
