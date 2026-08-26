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
  landing: {
    // 画面の題です。**英語の言い回しはデザインの一部です。**
    // モックの体裁をそのまま再現します（`app-ui/index.html`）。
    //
    // **文ではないもの（押せるものの名前・見出しの語・添え書き）は
    // `labels` の下へ置きます。** 句点で終わらないためです。
    meta: {
      title: "hero-prompt-forge — Forge Heroes Beyond the Cliché.",
    },
    labels: {
      navFeatures: "Features",
      navProcess: "Process",
      navFaq: "FAQ",
      navLogin: "Xでログイン",
      heroEyebrow: "HERO IMAGE PROMPT ENGINE",
      heroTitleFirst: "Forge Heroes",
      heroTitleSecond: "Beyond the ",
      heroTitleAccent: "Cliché.",
      heroAction: "Xでログインして始める",
      heroNoteBefore: "利用条件：",
      heroNoteAccount: "@rictaworks",
      heroNoteAfter: " のフォロワーであること",
      heroImageAlt: "",
      featuresEyebrow: "WHAT WE DO",
      featuresTitle: "Three Guards",
      processEyebrow: "OUR PROCESS",
      processTitle: "From Input to Package",
      processStep: "Step",
      faqEyebrow: "FAQ",
      faqTitle: "Before You Start",
      contactEyebrow: "GET IN GEAR",
      contactAction: "Xでログイン",
      contactImageAlt: "",
    },
    hero: {
      lead: "ヒーローイメージのプロンプトを、アートディレクターの指示水準で生成します。クリシェ配色・意味のない浮遊オブジェクト・破綻した人物表現は、規則辞書の段階で排除されます。",
    },
    features: {
      body: "出力されるすべての案が、この3つの規則を通過します。通過しない案は出力されません。",
      cards: {
        antiCliche: {
          title: "Anti-Cliché Rules",
          body: "紫〜ティールのグラデーション、浮遊する3Dオブジェクト、過剰な彩度を辞書で常時排除し、対応するネガティブプロンプトを自動で注入します。",
        },
        photographic: {
          title: "Photographic Spec",
          body: "実写系はレンズ焦点距離・キーライト／フィルライト／リムライト・被写界深度を必ず明示します。撮影指示を欠く案は出力しません。",
        },
        copySpace: {
          title: "Copy Space Guard",
          body: "見出しとCTAを載せる余白を三分割構図で確保し、被写体と視線誘導が余白側と競合しない配置を指示します。",
        },
      },
    },
    process: {
      body: "入力から3案の受け取りまで、4段階で処理されます。",
      steps: {
        input: {
          title: "Input",
          body: "業種・スタイル系統・生成モデルの3項目を選び、必要に応じてサービス概要とブランド条件を加えます。",
        },
        rules: {
          title: "Rules",
          body: "アンチAIルック規則とスタイル仕様化規則を適用し、入力の矛盾を優先順位に従って統合します。",
        },
        refine: {
          title: "Refine",
          body: "モデル別の記法へ整形し、非同期ジョブでLLMが表現を磨き込みます。障害時は辞書のみの合成へ縮退します。",
        },
        packageStep: {
          title: "Package",
          body: "構図の異なる3案を、ネガティブプロンプト・推奨パラメータ・アートディレクションノート付きで受け取ります。",
        },
      },
    },
    faq: {
      items: {
        images: {
          question: "Q. 生成された画像もこのアプリで作れますか？",
          answer:
            "画像生成は行いません。出力はプロンプトパッケージのみで、生成はお使いの画像生成サービス側で実行してください。",
        },
        names: {
          question: "Q. 実在の人物名やブランド名を入れられますか？",
          answer:
            "実在人物名・企業ロゴ・第三者著作物への言及を検出した場合は生成を行わず、理由を添えてエラーを返します。",
        },
        japanese: {
          question: "Q. 日本語で入力できますか？",
          answer:
            "サービス概要は日本語で入力できます。日本語固有名詞は翻訳せずローマ字表記で保持し、意味説明を併記します。",
        },
      },
    },
    contact: {
      title: "第一印象を、業務品質に。",
      body: "ログインは指定アカウントのフォロワー判定のみで完了します。メールアドレスの登録はありません。",
    },
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
