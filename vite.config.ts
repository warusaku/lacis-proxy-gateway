// vite.config.ts - Vite Configuration
// Version: 1.0.0

import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src/web'),
      '@components': path.resolve(__dirname, './src/web/components'),
      '@pages': path.resolve(__dirname, './src/web/pages'),
      '@contexts': path.resolve(__dirname, './src/web/contexts'),
      '@hooks': path.resolve(__dirname, './src/web/hooks'),
      '@services': path.resolve(__dirname, './src/web/services'),
      '@types': path.resolve(__dirname, './src/web/types'),
      '@utils': path.resolve(__dirname, './src/web/utils'),
      '@styles': path.resolve(__dirname, './src/web/styles'),
    },
  },

  server: {
    port: 5173,
    host: true,
    https: {
      key: './certs/localhost.key',
      cert: './certs/localhost.crt',
    },
    proxy: {
      '/api': {
        target: 'https://localhost:8443',
        changeOrigin: true,
        secure: false,
      },
    },
  },

  build: {
    outDir: 'dist',
    sourcemap: true,
    rollupOptions: {
      output: {
        manualChunks: {
          'react-vendor': ['react', 'react-dom', 'react-router-dom'],
          'primer-vendor': ['@primer/react', '@primer/octicons-react'],
          'editor-vendor': ['@monaco-editor/react'],
        },
      },
    },
  },
}) 