import Link from 'next/link';
import ScrollLink from './ScrollLink';

/**
 * Fixed top nav bar: brand + section links. Presentation-only — the boost
 * toggle deliberately lives in the demo section on the page, where every
 * visitor sees it, not up here. Section links use ScrollLink (no history
 * pollution); cross-page links use next/link.
 */
export default function NavBar() {
  return (
    <nav className="navbar">
      <span className="brand">
        <img className="brand-logo" src="/brand.png" alt="" width={28} height={28} />
        MaxCandela
      </span>
      <div className="nav-links">
        <ScrollLink targetId="demo">Try it</ScrollLink>
        <ScrollLink targetId="features">Features</ScrollLink>
        <ScrollLink targetId="pricing">Pricing</ScrollLink>
        <ScrollLink targetId="faq">FAQ</ScrollLink>
        <Link href="/about/">About</Link>
      </div>
    </nav>
  );
}
