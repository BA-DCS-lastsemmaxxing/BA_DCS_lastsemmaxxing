import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  /* config options here */
  output: "export",
  trailingSlash: false,
  images: {
    unoptimized: true,
  },
  async rewrites() {
    return [
      {
        source: '/:path*',
        destination: '/_next/static/chunks/pages/:path*.js',
      },
    ];
  },
};

export default nextConfig;