import type { NextConfig } from "next";
import { backendRewrites } from "./src/config/backend";
import { SECURITY_HEADERS } from "./src/config/security-headers";

/**
 * **バックエンドのドメインを隠蔽します**（CLAUDE.md）。
 *
 * ブラウザからは `/api/...` ・ `/auth/...` だけが見えます。実際の
 * 呼び出し先は、ここでサーバー側だけが知ります。
 */
const nextConfig: NextConfig = {
  async rewrites() {
    return backendRewrites();
  },
  async headers() {
    return [
      {
        source: "/:path*",
        headers: [...SECURITY_HEADERS],
      },
    ];
  },
};

export default nextConfig;
