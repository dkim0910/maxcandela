/** @type {import('next').NextConfig} */
const nextConfig = {
  // Static export — the site is a pure client-side utility, deployable to any
  // static host (GitHub Pages, Netlify, S3, …).
  output: 'export',
  // Emit folder/index.html per route so /privacy, /terms, /support resolve on
  // dumb static hosts without .html rewrite rules.
  trailingSlash: true,
};

export default nextConfig;
