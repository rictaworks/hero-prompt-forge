/**
 * 画面に出す文言です。
 *
 * 文言をコンポーネントへ直書きしません。ここへ追加します。
 * 日本語版のみを提供するため、他の言語のファイルを置きません。
 */
export const strings = {
  app: {
    title: "hero-prompt-forge",
    wordmark: "Veyra Dragon",
    description:
      "ヒーローイメージのプロンプトを、アートディレクターの指示水準で生成します。",
  },
  nav: {
    projects: { en: "Projects", ja: "プロジェクト" },
    presets: { en: "Presets", ja: "プリセット" },
    admin: { en: "Admin", ja: "管理" },
    newRequest: { en: "New Request", ja: "新規生成", action: "新規生成" },
  },
  errors: {
    common: {
      nextActionUnknown: "解決しない場合は info@rictaworks.jp までご連絡ください。",
    },
    unauthorized: {
      message: "ログインが必要です。",
      nextAction: "X でログインしてから、もう一度お試しください。",
    },
    forbidden: {
      message: "この操作を行う権限がありません。",
      nextAction: "利用条件をご確認ください。",
    },
    notFound: {
      message: "お探しのものが見つかりませんでした。",
      nextAction: "一覧から選び直してください。",
    },
    invalidInput: {
      message: "入力の内容に誤りがあります。",
      nextAction: "赤く示された項目を直してから、もう一度お試しください。",
    },
    unexpected: {
      message: "想定していない問題が起きました。",
      nextAction: "時間をおいて、もう一度お試しください。",
      traceLabel: "参照番号",
    },
    serviceUnavailable: {
      message: "ただいま処理を受け付けられません。",
      nextAction: "時間をおいて、もう一度お試しください。",
    },
  },
} as const;

export type Strings = typeof strings;
