// GlobalStyle.tsx - Global Styles
// Version: 1.0.0
// Description: グローバルスタイル定義

import { createGlobalStyle } from 'styled-components'

const GlobalStyle = createGlobalStyle`
  /* リセットとベーススタイル */
  * {
    box-sizing: border-box;
  }

  html, body {
    margin: 0;
    padding: 0;
    height: 100%;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Noto Sans', Helvetica, Arial, sans-serif, 'Apple Color Emoji', 'Segoe UI Emoji';
    -webkit-font-smoothing: antialiased;
    -moz-osx-font-smoothing: grayscale;
  }

  #root {
    height: 100%;
  }

  /* カスタムスクロールバー */
  ::-webkit-scrollbar {
    width: 8px;
    height: 8px;
  }

  ::-webkit-scrollbar-track {
    background: var(--color-canvas-subtle);
  }

  ::-webkit-scrollbar-thumb {
    background: var(--color-border-default);
    border-radius: 4px;
  }

  ::-webkit-scrollbar-thumb:hover {
    background: var(--color-border-muted);
  }

  /* トランジションのデフォルト設定 */
  * {
    transition: background-color 0.2s ease, border-color 0.2s ease, color 0.2s ease;
  }

  /* モーダルオーバーレイ用 */
  .modal-overlay {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background-color: var(--color-primer-canvas-backdrop);
    z-index: 999;
  }

  /* コードブロックのスタイル */
  pre, code {
    font-family: ui-monospace, SFMono-Regular, 'SF Mono', Consolas, 'Liberation Mono', Menlo, monospace;
  }

  /* テーブルのデフォルトスタイル */
  table {
    border-collapse: collapse;
    width: 100%;
  }

  /* リンクのデフォルトスタイル */
  a {
    color: var(--color-accent-fg);
    text-decoration: none;
  }

  a:hover {
    text-decoration: underline;
  }

  /* フォーカススタイル */
  :focus {
    outline: 2px solid var(--color-accent-fg);
    outline-offset: -2px;
  }

  /* 選択時のスタイル */
  ::selection {
    background-color: var(--color-accent-subtle);
    color: var(--color-fg-default);
  }

  /* アニメーション */
  @keyframes fadeIn {
    from {
      opacity: 0;
    }
    to {
      opacity: 1;
    }
  }

  @keyframes slideIn {
    from {
      transform: translateY(-10px);
      opacity: 0;
    }
    to {
      transform: translateY(0);
      opacity: 1;
    }
  }

  @keyframes spin {
    from {
      transform: rotate(0deg);
    }
    to {
      transform: rotate(360deg);
    }
  }

  /* ユーティリティクラス */
  .fade-in {
    animation: fadeIn 0.3s ease;
  }

  .slide-in {
    animation: slideIn 0.3s ease;
  }

  .text-ellipsis {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .no-select {
    user-select: none;
  }

  /* レスポンシブ用のブレークポイント */
  @media (max-width: 768px) {
    .hide-on-mobile {
      display: none !important;
    }
  }

  @media (min-width: 769px) {
    .show-on-mobile {
      display: none !important;
    }
  }

  /* Monaco Editorのテーマ調整 */
  .monaco-editor {
    border: 1px solid var(--color-border-default);
    border-radius: 6px;
  }

  /* React Hot Toastのカスタマイズ */
  .react-hot-toast {
    font-size: 14px;
  }
`

export default GlobalStyle 