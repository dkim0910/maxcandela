'use client';

import { useState } from 'react';

/** One responsive source: the fallback `src` plus its `srcSet` candidates. */
export type ComparisonImage = {
  src: string;
  srcSet: string;
};

/**
 * Before/after image comparison slider. The "after" (brighter) image sits in a
 * clipped overlay whose width the range input controls; the inner <img> keeps
 * full container width so it isn't squished. Drag the handle to reveal the
 * difference.
 *
 * `width`/`height` are required, not optional: this widget is the home page's
 * LCP element, and without intrinsic dimensions `.ba-img { width:100%;
 * height:auto }` collapses the box to zero height until the bytes land, which
 * shifts the whole page (a Core Web Vitals failure). They describe the aspect
 * ratio, not the rendered size — CSS still caps the box at 1240px.
 *
 * Both images stay eager. They are two halves of one widget, so lazy-loading
 * the overlay would show a half-rendered slider on first paint.
 */
export default function BeforeAfter({
  before,
  after,
  width,
  height,
  beforeLabel = 'Now',
  afterLabel = 'With MaxCandela',
  alt,
}: {
  before: ComparisonImage;
  after: ComparisonImage;
  width: number;
  height: number;
  beforeLabel?: string;
  afterLabel?: string;
  alt: string;
}) {
  const [pos, setPos] = useState(50);

  // The container is full-bleed up to its 1240px cap, so a phone picks the
  // 1240w candidate and a 2× desktop picks 2480w.
  const sizes = '(max-width: 1240px) 100vw, 1240px';

  return (
    <div className="ba">
      {/* Base = "after" (bright); sets the box size and shows on the right. */}
      <img
        className="ba-img"
        src={after.src}
        srcSet={after.srcSet}
        sizes={sizes}
        width={width}
        height={height}
        alt={alt}
        fetchPriority="high"
        decoding="async"
        draggable={false}
      />

      {/* "Before" (dark) overlays the LEFT side, clipped to `pos`%. */}
      <div className="ba-after" style={{ width: `${pos}%` }}>
        <img
          className="ba-img"
          src={before.src}
          srcSet={before.srcSet}
          sizes={sizes}
          width={width}
          height={height}
          alt=""
          decoding="async"
          draggable={false}
        />
      </div>

      <span className="ba-tag ba-tag-left">{beforeLabel}</span>
      <span className="ba-tag ba-tag-right">{afterLabel}</span>

      <div className="ba-divider" style={{ left: `${pos}%` }} aria-hidden="true">
        <span className="ba-handle">⟨ ⟩</span>
      </div>

      <input
        className="ba-range"
        type="range"
        min={0}
        max={100}
        value={pos}
        onChange={(e) => setPos(Number(e.target.value))}
        aria-label="Drag to compare normal brightness with MaxCandela"
      />
    </div>
  );
}
