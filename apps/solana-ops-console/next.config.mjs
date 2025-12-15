/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  experimental: {
    // Allow importing config/IDL from the monorepo root (e.g. addresses/, idl/)
    externalDir: true
  }
};

export default nextConfig;


