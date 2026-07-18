import Link from 'next/link';

/**
 * Fixed top nav bar: brand + section links. Presentation-only — the boost
 * toggle deliberately lives in the demo section on the page, where every
 * visitor sees it, not up here. Cross-page links use next/link so the boost
 * video in the root layout survives navigation.
 */
export default function NavBar() {
  return (
    <nav className="navbar">
      <span className="brand">
        <img className="brand-logo" src="/brand.png" alt="" width={28} height={28} />
        MaxCandela
      </span>
      <div className="nav-links">
        <a href="#demo">Try it</a>
        <a href="#features">Features</a>
        <a href="#pricing">Pricing</a>
        <a href="#faq">FAQ</a>
        <Link href="/about/">About</Link>
      </div>
    </nav>
  );
}
