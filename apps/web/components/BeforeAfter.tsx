'use client';

import { useState } from 'react';

/**
 * Before/after image comparison slider. The "after" (brighter) image sits in a
 * clipped overlay whose width the range input controls; the inner <img> keeps
 * full container width so it isn't squished. Drag the handle to reveal the
 * difference.
 */
export default function BeforeAfter({
  before,
  after,
  beforeLabel = 'Now',
  afterLabel = 'With MaxCandela',
  alt,
}: {
  before: string;
  after: string;
  beforeLabel?: string;
  afterLabel?: string;
  alt: string;
}) {
  const [pos, setPos] = useState(50);

  return (
    <div className="ba">
      {/* Base = "after" (bright); sets the box size and shows on the right. */}
      <img className="ba-img" src={after} alt={alt} draggable={false} />

      {/* "Before" (dark) overlays the LEFT side, clipped to `pos`%. */}
      <div className="ba-after" style={{ width: `${pos}%` }}>
        <img className="ba-img" src={before} alt="" draggable={false} />
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
