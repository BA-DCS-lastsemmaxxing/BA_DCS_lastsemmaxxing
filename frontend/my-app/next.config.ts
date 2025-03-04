import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: "export",
  trailingSlash: true, // Ensures Next.js exports pages with a trailing slash
  distDir: "out",
};

export default nextConfig;
