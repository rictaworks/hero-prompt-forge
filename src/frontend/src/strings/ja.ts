/**
 * 画面に出す文言です。
 *
 * 文言をコンポーネントへ直書きしません。ここへ追加します。
 * 日本語版のみを提供するため、他の言語のファイルを置きません。
 */
export const strings = {
  app: {
    title: "hero-prompt-forge",
    // 画面に出す名前です。
    //
    // **モックの既定値（Veyra Dragon）を、そのまま公開しません**
    // （PR #170 のレビューより）。デザインシステムの既定値であり、
    // 他社の名称と衝突しうるためです。**モックは書き換えません。
    // 正しい値は実装側で入れます**（CLAUDE.md）。
    //
    // ブランドが確定したら、ここを直します。
    wordmark: "hero-prompt-forge",
    description:
      "ヒーローイメージのプロンプトを、アートディレクターの指示水準で生成します。",
  },
  // 画面をまたいで使う、短い区切りと呼び名です。
  common: {
    labels: {
      // 値と値の区切りです。**画面へ直書きしません。**
      separator: " / ",
    },
  },
  nav: {
    projects: { en: "Projects", ja: "プロジェクト" },
    presets: { en: "Presets", ja: "プリセット" },
    admin: { en: "Admin", ja: "管理" },
    newRequest: { en: "New Request", ja: "新規生成", action: "新規生成" },
    planPrefix: "PLAN · ",
  },
  // 選択肢の呼び名です。**値そのものを画面へ出しません。**
  choices: {
    industry: {
      saas: "SaaS・ソフトウェア",
      restaurant: "飲食",
      medical: "医療・歯科",
      education: "教育",
      real_estate: "不動産",
      manufacturing: "製造",
      professional_services: "士業・専門サービス",
      ecommerce: "EC・通販",
      beauty: "美容",
      other: "その他",
    },
    styleFamily: {
      photoreal: "実写",
      illustration: "イラスト",
      three_d: "3D",
      abstract: "抽象",
    },
    targetModel: {
      midjourney: "Midjourney",
      dalle: "DALL·E",
      stable_diffusion: "Stable Diffusion",
      nano_banana: "nano banana",
    },
    status: {
      draft: "下書き",
      queued: "順番待ち",
      generating: "生成中",
      completed: "完了",
      degraded_completed: "完了（縮退）",
      failed: "失敗",
      rejected: "差し戻し",
      archived: "整理済み",
    },
    compositionType: {
      subject_led: "被写体主導",
      environment_led: "環境主導",
      abstract_background: "抽象背景",
    },
    brandTone: {
      trust: "信頼感",
      advanced: "先進性",
      warmth: "温かみ",
      premium: "高級感",
      friendly: "親しみ",
      minimal: "ミニマル",
    },
    copySpacePosition: {
      left: "左",
      right: "右",
      bottom_center: "中央下",
    },
    aspectRatio: {
      "16:9": "16:9（横長）",
      "21:9": "21:9（超横長）",
      "3:2": "3:2",
    },
  },
  // 履歴・一覧（02）です。
  projects: {
    labels: {
      eyebrow: "HISTORY",
      title: "Projects & Requests",
      projectsHeading: "プロジェクト",
      requestsHeading: "生成履歴",
      filterAll: "すべてのプロジェクト",
      filterLabel: "プロジェクトで絞り込む",
      open: "開く",
      duplicate: "同じ条件で作る",
      degraded: "縮退",
      delivered: "受け取り済み",
      outputsUnit: "案",
    },
    body: "過去の生成を開き直したり、同じ条件で作り直したりできます。",
    loading: "読み込んでいます。",
    emptyProjects: "プロジェクトがまだありません。新規生成から作れます。",
    emptyRequests: "生成履歴がまだありません。新規生成からお試しください。",
  },
  // 入力フォーム（03）です（issue #71、#152）。
  newRequest: {
    labels: {
      eyebrow: "NEW REQUEST",
      title: "Input Conditions",
      projectHeading: "プロジェクト",
      requiredHeading: "必ず選ぶ項目",
      optionalHeading: "任意の項目",
      project: "保存先のプロジェクト",
      projectNew: "新しく作る",
      projectName: "サイト名",
      industry: "業種",
      styleFamily: "スタイル系統",
      targetModel: "生成モデル",
      brandTone: "ブランドトーン",
      serviceSummary: "サービス概要",
      brandColors: "ブランドカラー",
      brandColorFirst: "1 色目",
      brandColorSecond: "2 色目",
      copySpacePosition: "文字を置く余白の位置",
      aspectRatio: "画角",
      unselected: "未選択",
      unspecified: "指定なし",
      submit: "3 案を生成",
      submitting: "生成の受け付け中",
      namingHeading: "名前を確実に反映させる書き方",
      requiredMark: "必須",
      counterUnit: "文字",
    },
    body: "業種・スタイル系統・生成モデルの 3 項目を選ぶと、3 案を生成できます。",
    loading: "読み込んでいます。",
    projectHelp:
      "プロジェクトは、サイト単位の入れ物です。選ばない場合は、いま選んだ業種とスタイル系統で新しく作ります。",
    serviceSummaryHelp: "どのようなサービスかを、日本語で書けます。",
    brandColorsHelp:
      "カラーコード（#RRGGBB）を 2 色まで指定できます。画面全体を塗る色ではなく、アクセントとして入ります。",
    // 名前の書き方の案内です（issue #152）。
    naming: {
      body: "お店や会社の名前は、名前だと分かる書き方のときだけローマ字へ写します。次のいずれかの形で書いてください。",
      examples: {
        quoted: "「さくら堂」という店の焼き菓子です。",
        reading: "「櫻花堂」（おうかどう）の店構えです。",
        company: "株式会社ミライ工房が運営します。",
      },
      caution:
        "この形で書かない名前は、名前として拾いません。読みが決まらなかった名前は、アートディレクションノートに出ます。",
    },
    errors: {
      industryMissing: "業種を選んでください。",
      styleFamilyMissing: "スタイル系統を選んでください。",
      targetModelMissing: "生成モデルを選んでください。",
      serviceSummaryTooLong: "サービス概要は 1000 文字までです。",
      brandColorFormat: "ブランドカラーは #RRGGBB の形で入力してください。",
    },
  },
  // 生成中（04）です（issue #72）。
  requestStatus: {
    labels: {
      eyebrow: "IN PROGRESS",
      title: "Generating",
      // 状態ごとの見出しです（PR #174 のレビュー・要修正 13）。
      // **終わった状態でも「Generating」のままにしません。**
      titleDelivered: "Package Ready",
      titleFailed: "Limits & Fallbacks",
      eyebrowDelivered: "PACKAGE",
      eyebrowFailed: "EXCEPTIONS",
      requestNumber: "REQUEST",
      variationNumber: "VARIATION",
      degradedQuote: "DEGRADED PROMPT",
      openResultPlain: "このまま 3 案を見る",
      stateHeading: "STATE",
      modelHeading: "MODEL",
      dictionaryHeading: "DICTIONARY",
      startedHeading: "STARTED",
      openResult: "3 案を見る",
      retry: "同じ条件で作り直す",
      historyLink: "履歴を見る",
      degradedEyebrow: "DEGRADED MODE",
      degradedChip: "NOT REFINED",
      completedEyebrow: "COMPLETED",
      failedEyebrow: "FAILED",
    },
    loading: "状態を読み込んでいます。",
    generating: "規則の適用・矛盾解決・モデル別整形・3 案の展開を順に行っています。状態が進むと、この画面の表示が切り替わります。",
    queued: "順番をお待ちいただいています。まもなく生成が始まります。",
    completed: "3 案がそろいました。構図の違う 3 案を見比べて、お使いになる案をコピーしてください。",
    degraded: "LLM への呼び出しが上限に達したため、規則辞書のみによる合成へ縮退しました。規則の適用とコピースペースの規定は通常どおり行われていますが、表現の磨き込みは行われていません。成果物を提供していますので、本日の生成枠は確定します。",
    degradedNote: "縮退で生成された案には、履歴の一覧にも印が残ります。",
    archived: "この生成リクエストは整理済みです。",
    // 状態ごとの添え書きです（`app-ui/degraded.html` の節の添え書きに当たります）。
    exceptionsBody: "上限到達・縮退モードでの完了・禁止入力の差し戻しは、いずれも曖昧なエラーを返さず、次の操作と時刻を明示します。",
  },
  // 結果 3 案（05）です（issue #73）。
  result: {
    labels: {
      eyebrow: "PACKAGE",
      title: "Three Variations",
      variation: "VARIATION",
      mainPrompt: "MAIN PROMPT",
      negativePrompt: "NEGATIVE PROMPT",
      parameters: "PARAMETERS",
      copy: "コピー",
      copied: "コピー済み",
      degradedChip: "NOT REFINED",
      backToStatus: "生成の状態へ戻る",
      openNotes: "評価メモを書く",
    },
    body: "構図の異なる 3 案です。使う案の本文をコピーして、お使いの画像生成サービスへ貼り付けてください。",
    // 推奨パラメータの鍵の呼び名です。**機械の鍵をそのまま出しません。**
    parameters: {
      labels: {
        aspect_ratio: "画角",
        size: "画像の大きさ",
        api_version: "呼び出しの版",
      },
    },
    negativeAbsent: "このモデルは打ち消しの欄を持ちません。",
    copyFailed: "コピーできませんでした。本文を選んで、手元の操作でコピーしてください。",
    empty: "この生成リクエストには、まだ案がありません。",
  },
  // 評価メモ（06）です（issue #74）。
  evaluation: {
    labels: {
      eyebrow: "EVALUATION",
      title: "Evaluation Notes",
      ratingHeading: "5 段階の評価",
      memoHeading: "所感",
      save: "この案のメモを保存",
      saving: "保存中",
      saved: "保存済み",
      unrated: "未評価",
      backToResult: "3 案へ戻る",
    },
    body: "生成した絵を実際に作ってみた所感を残せます。次に条件を決めるときの手がかりになります。",
    quotaNote: "評価メモの記録は、本日の生成枠を使い切っていても行えます。記録は生成ではありません。",
    empty: "この生成リクエストには、まだ案がありません。",
    loading: "読み込んでいます。",
  },
  // プリセット（07）です（issue #75）。
  presets: {
    labels: {
      eyebrow: "PRESETS",
      title: "Saved Conditions",
      nameHeading: "プリセット名",
      use: "この条件で作る",
      save: "いまの条件を保存",
      saving: "保存中",
      saved: "保存済み",
      newHeading: "いまの条件をプリセットとして保存",
    },
    body: "よく使う入力条件を、名前を付けて保存できます。入力フォームへそのまま呼び出せます。",
    empty: "プリセットがまだありません。入力フォームの下から保存できます。",
    loading: "読み込んでいます。",
    nameRequired: "プリセット名を入力してください。",
    savedNotice: "プリセットを保存しました。",
  },
  // 上限到達・差し戻しの伝え方です（issue #71、#76）。
  //
  // **文言そのものは、できる限り API から受け取ります。** 契約は、失敗のたびに
  // 「何が起きたか」と「次に何をすればよいか」を返します（`SPEC/api/README.md`）。
  // ここへ置くのは、**API が返さない見出しと、種別から引く説明**だけです。
  exceptions: {
    labels: {
      quotaEyebrow: "DAILY QUOTA",
      quotaResetHeading: "NEXT RESET",
      quotaZone: "JST",
      quotaDayHeading: "消費の帰属",
      quotaRefundHeading: "返還される場合",
      quotaRefundValue: "縮退も失敗したとき",
      resultLink: "本日の結果を見る",
      rejectedEyebrow: "REJECTED",
      rejectedDetectedHeading: "DETECTED IN — サービス概要",
      rejectedReasonHeading: "REASON",
      rejectedSuggestionHeading: "SUGGESTION",
      rejectedFix: "入力を修正する",
      historyLink: "履歴を見る",
    },
    quotaNote:
      "生成済みの 3 案の閲覧・コピー・評価メモの記録は、上限に関係なく行えます。",
    // 取り出しの経路では、見つかった語も入力の写しも返りません。
    rejectedInputAbsent:
      "差し戻した記録には、書いていただいた文章を残していません。権利に触れると判定した文章ですので、実在の方のお名前や商標を含みます。",
    // 差し戻しの種別です（`config/forbidden_inputs.yml` の `kind`）。
    reasons: {
      real_person: "実在人物名の指定です。肖像・パブリシティ権の観点から生成の対象外です。",
      brand_logo: "第三者のロゴ・商標の指定です。商標を含む生成物は出力できません。",
      third_party_work: "第三者の著作物への言及です。権利の及ぶ表現は出力できません。",
    },
    // 直し方です（`config/forbidden_inputs.yml` の `suggestion_key`）。
    suggestions: {
      describe_person_by_role:
        "「後ろ姿の人物」「遠景の人影」のように役割で書くと、同じ構図の意図を保ったまま生成できます。",
      remove_third_party_mark:
        "「無地の看板」「文字の無いサイン」に置き換えると、同じ構図の意図を保ったまま生成できます。",
      describe_style_by_attribute:
        "作品名を外し、伝えたい雰囲気そのものを書くと、同じ意図で生成できます。",
    },
  },
  landing: {
    // 画面の題です。**英語の言い回しはデザインの一部です。**
    // モックの体裁をそのまま再現します（`app-ui/index.html`）。
    //
    // **文ではないもの（押せるものの名前・見出しの語・添え書き）は
    // `labels` の下へ置きます。** 句点で終わらないためです。
    meta: {
      title: "hero-prompt-forge — Forge Heroes Beyond the Cliché.",
      // 共有されたときに出る説明です。
      shareDescription:
        "ヒーローイメージのプロンプトを、アートディレクターの指示水準で生成します。",
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
      heroNoteAfter: " の",
      heroNoteTail: "フォロワーであること",
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
    labels: {
      retry: "もう一度読み込む",
    },
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
