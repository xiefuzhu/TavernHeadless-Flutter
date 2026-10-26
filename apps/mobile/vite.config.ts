import { defineConfig } from 'vite';
import vue from '@vitejs/plugin-vue';
import { fileURLToPath } from 'node:url';
const source = (path: string) => fileURLToPath(new URL(path, import.meta.url));
export default defineConfig({
  plugins: [vue()],
  resolve: { alias: {
    '@tavern/sdk': source('../../packages/official-integration-kit/sdk/src/index.ts'),
    '@tavern/client-helpers': source('../../packages/official-integration-kit/client-helpers/src/index.ts'),
    '@tavern/shared': source('../../packages/shared/src/index.ts'),
    '@tavern/adapters-sillytavern': source('../../packages/adapters-sillytavern/src/index.ts'),
    '@tavern/core': source('../../packages/core/src/index.ts'),
  } },
  server: { host: '127.0.0.1', port: 5174, strictPort: true, fs: { deny: ['**/.env*', '**/.git/**', '**/.local/**', '**/data/**'] }, proxy: { '/api': { target: 'http://127.0.0.1:3000', rewrite: path => path.replace(/^\/api/, '') } } },
  preview: { host: '127.0.0.1', port: 5174, strictPort: true },
});
