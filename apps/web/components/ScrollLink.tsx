'use client';

import { MouseEvent, ReactNode } from 'react';

/**
 * In-page section link that smooth-scrolls to a target WITHOUT pushing a
 * browser-history entry or changing the URL hash.
 *
 * Plain `<a href="#section">` links add a history entry on every click, which
 * pollutes the back stack — after clicking a few nav sections, the browser's
 * Back button walks through them (scrolling to #demo etc.) instead of leaving
 * the page. Intercepting the click and calling scrollIntoView avoids that.
 * `scroll-margin-top` on the target still applies, so it lands below the navbar.
 */
export default function ScrollLink({
  targetId,
  className,
  children,
}: {
  targetId: string;
  className?: string;
  children: ReactNode;
}) {
  const onClick = (e: MouseEvent<HTMLAnchorElement>) => {
    // Let modifier-clicks (open in new tab, etc.) behave normally.
    if (e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return;
    const el = document.getElementById(targetId);
    if (!el) return;
    e.preventDefault();
    el.scrollIntoView({ behavior: 'smooth', block: 'start' });
  };

  return (
    <a href={`#${targetId}`} className={className} onClick={onClick}>
      {children}
    </a>
  );
}
