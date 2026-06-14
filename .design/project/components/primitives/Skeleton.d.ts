/** Loading placeholder — calm paper shimmer (not grey). Respects prefers-reduced-motion. */
export interface SkeletonProps {
  /** "text" line | "cover" 120:156 | "circle" | "block". Default "text" */
  variant?: "text" | "cover" | "circle" | "block";
  /** CSS width override */
  width?: number | string;
  /** CSS height override (cover derives height from aspect if omitted) */
  height?: number | string;
  /** Border radius override */
  radius?: number | string;
  style?: object;
}
export declare const Skeleton: (props: SkeletonProps) => any;
