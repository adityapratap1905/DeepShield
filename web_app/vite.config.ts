import tailwindcss from '@tailwindcss/vite';
import react from '@vitejs/plugin-react';
import { defineConfig } from 'vite';

export default defineConfig(({ command }) => ({
  base: command === 'build' ? '/static/site/' : '/',
  plugins: [react(), tailwindcss()],
  build: {
    outDir: 'static/site',
    emptyOutDir: true,
  },
  server: {
    strictPort: true,
    proxy: {
      '/api': {
        target: process.env.DEEPSHIELD_API_PROXY_TARGET || 'http://127.0.0.1:8000',
        changeOrigin: true,
        rewrite: (path) => path === '/api/health' ? '/health' : path,
      },
    },
  },
}));
