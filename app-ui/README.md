# app-ui

hero-prompt-forge の画面モックと、その実装。

Claude Design プロジェクト「モック制作の範囲確認」
（https://claude.ai/design/p/11e7af5d-65ae-452c-8c57-1437d375b392 ）からの取り込み。

## 実装状況（全9画面）

| # | 画面 | 原本 | 実装 |
|---|---|---|---|
| 01 | Landing（ランディング） | `Landing.dc.html` | `index.html` |
| 02 | Projects（履歴・一覧） | — | — |
| 03 | New Request（入力フォーム） | — | — |
| 04 | Generating（生成中） | — | — |
| 05 | Result（結果3案） | — | — |
| 06 | Evaluation（評価メモ） | — | — |
| 07 | Presets（プリセット） | — | — |
| 08 | Degraded（縮退・エラー） | `Degraded.dc.html` | `degraded.html` |
| 09 | Admin（規則辞書） | — | — |

画面リストは `scripts/chrome.js` の `SCREENS` が唯一の情報源。**画面を実装したら `file` を埋めるだけで、全ページの導線が同時に開く**。

## 構成

| パス | 内容 |
|---|---|
| `index.html` / `degraded.html` | 各画面の実装（素の HTML/CSS） |
| `styles/components.css` | デザインシステムのコンポーネント（Logo / Button / SectionHeading / StrengthCard / ProcessStep / FaqItem）の CSS 移植 |
| `styles/chrome.css` | 全画面共通の外枠。helmet の `<style>` 相当・`HPFAppBar`・`HPFMockLinks` |
| `styles/landing.css` / `styles/degraded.css` | 各画面のレイアウト（`.dc.html` のインラインスタイルをクラス化） |
| `scripts/chrome.js` | 画面リスト（`SCREENS`）と、AppBar・モックインデックスの描画 |
| `scripts/faq.js` | FaqItem のアコーディオン（React の `useState` 相当を素の DOM で再現） |
| `*.dc.html` | **原本**（Claude Design のソースそのまま。差分確認用） |
| `support.js` | 原本。`.dc.html` を素のブラウザで描画するための Claude Design ランタイム |
| `_ds/veyra-dragon-c89babbb-.../` | 原本。デザインシステム（トークン CSS・コンポーネントバンドル・画像・フォント） |

実装と `.dc.html` は**同じ `_ds/` を参照している**。トークンや画像を差し替えれば両方に効く。

## 表示方法

原本・実装とも、静的ファイルを HTTP で配信すれば開ける（`file://` だとフォントとアセットの相対解決が崩れる）。
ワークスペースの no-cache サーバーを使う場合は `20_開発/.claude/launch.json` の `hero-prompt-forge-app-ui`（port 8794）を起動する。

## 実装時の判断（原本との差分）

原本と挙動が変わる点は以下のみ。それ以外は数値・色・余白まで `.dc.html` と `_ds_bundle.js` に一致させている。

- **`SectionHeading` の `size="small"`**：`_ds_bundle.js` の `SIZES` は `default` / `sm` / `contact` / `band` の4つで、`small` は無い。よって原本も既定値（`--fs-title`）で描画されている。実装もそれに合わせた（`--fs-title-sm` にはしていない）。
- **未実装画面への導線**：遷移先が未実装の場合は `href="#"` にし、本来の遷移先を `data-mock-target` に残す（404 を出さないため）。モックインデックスでも未実装分はリンクにせず淡色の非活性表示にしている。判定は `scripts/chrome.js` が一括で行う。
- **`HPFAppBar` / `HPFMockLinks`**：原本では `dc-import` される部品なので、実装側でも各ページに直書きせず `scripts/chrome.js` から描画している（`data-chrome="appbar"` / `data-chrome="mocklinks"`）。**JS が無効だとこの2つは描画されない。**
- **狭い画面（≤768px）**：原本にはメディアクエリが無く横スクロールが出るため、各 CSS の末尾に最小限の調整を追加した。デザイン上の意図的な差分。
- **フォント**：`_ds/.../assets/fonts/` の woff2（Latin サブセット）を原本ごと同梱。日本語グリフは `tokens/fonts.css` の Google Fonts `@import` から取得する。
- **Font Awesome**：原本と同じく cdnjs 6.5.0 を参照する（オフラインではアイコンが出ない）。

## 未確定事項

- ロゴ・ワードマークは、デザインシステム（Veyra Dragon）の既定値がそのまま出ている。hero-prompt-forge のブランドは未確定。
- AppBar のプラン表記（`PLAN · ACTIVE`）とユーザー名（`@ao_design`）は原本のダミー値。
- 仕様書ではフロントエンドは **Next.js（TypeScript）/ Vercel**。この `app-ui` はモックと静的実装であり、本実装のスキャフォールドはまだ無い。
