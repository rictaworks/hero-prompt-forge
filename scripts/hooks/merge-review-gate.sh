#!/usr/bin/env bash
# マージ前の reviewer と pr-checker の実行を強制するフックです。
#
# PreToolUse(Bash) から呼ばれます。標準入力に渡されたツール呼び出しの内容に
# `gh pr merge` が含まれる場合、対象 PR の reviewer 記録と pr-checker 記録が
# review-records/ に存在しなければ、終了コード 2 でマージを止めます。
#
# **判定は「## 判定」の節だけを読みます。** 記録の全文を対象にすると、
# 本文で語を挙げただけでマージが止まります。実際に PR #119 と PR #121 で、
# 「不合格の指摘はありません」という合格を意味する文で止まりました（issue #122）。
set -u

PAYLOAD="$(cat)"

# gh pr merge を含まない呼び出しは対象外です。
case "$PAYLOAD" in
  *"gh pr merge"*) ;;
  *) exit 0 ;;
esac

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
if [ -z "$REPO_ROOT" ]; then
  echo "マージ前フックがリポジトリを特定できませんでした。" >&2
  exit 2
fi
cd "$REPO_ROOT" || exit 2

# `gh pr merge <番号>` の番号を取り出します。
PR_NUMBER="$(printf '%s' "$PAYLOAD" | grep -oE 'gh pr merge[^"]*' | grep -oE '[0-9]+' | head -n 1)"
if [ -z "$PR_NUMBER" ]; then
  cat >&2 <<'EOF'
マージを止めました。PR 番号を特定できません。

`gh pr merge <PR番号>` の形式で、番号を明示して実行してください。
番号が無いと、どの PR のレビュー記録を確認すればよいか判定できません。
EOF
  exit 2
fi

REVIEWER_RECORD="review-records/reviewer/pr${PR_NUMBER}.md"
CHECKER_RECORD="review-records/pr-checker/pr${PR_NUMBER}.md"

MISSING=""
[ -f "$REVIEWER_RECORD" ] || MISSING="${MISSING}  - reviewer の記録がありません : $REVIEWER_RECORD"$'\n'
[ -f "$CHECKER_RECORD" ] || MISSING="${MISSING}  - pr-checker の記録がありません : $CHECKER_RECORD"$'\n'

if [ -n "$MISSING" ]; then
  cat >&2 <<EOF
マージを止めました。PR #${PR_NUMBER} のレビューが未完了です。

$MISSING
次の手順で進めてください。

1. reviewer を実行します。Issue の受け入れ要件と各基準への適合を検証します。
   結果を $REVIEWER_RECORD へ記録します。
2. pr-checker を実行します。PR のタイトルと本文を日本語にし、
   非エンジニア向けのユーザーテスト手順を本文へ書きます。
   結果を $CHECKER_RECORD へ記録します。
3. 記録を追加したうえで、あらためてマージします。

記録は版管理対象です。コミットしてから実行してください。
EOF
  exit 2
fi

# 「## 判定」の節だけを取り出します。次の「## 」で終わりです。
#
# **コードの塀（```）の中は見ません。** 記録の中でフックの書式を例示すると、
# 例示した見出しを本物の節として拾ってしまいます。
VERDICT="$(awk '
  /^```/                             { fenced = !fenced; next }
  fenced                             { next }
  /^##[[:space:]]+判定[[:space:]]*$/ { inside = 1; next }
  /^##[[:space:]]/                   { inside = 0 }
  inside                             { print }
' "$REVIEWER_RECORD")"

# **節が無い記録・節が空の記録は止めます。** 判定を読めないまま通すと、
# レビューの有無を確かめる仕組みが黙って無効になります。
if [ -z "$(printf '%s' "$VERDICT" | tr -d '[:space:]')" ]; then
  cat >&2 <<EOF
マージを止めました。reviewer の記録から判定を読み取れません。

記録 : $REVIEWER_RECORD

記録に「## 判定」の節を設け、その節へ判定を書いてください。
節の中身が空の場合も、判定が無いものとして止めます。
EOF
  exit 2
fi

# **許可制で見ます。判定の節に「合格」があり、かつ「不合格」が無いときだけ通します。**
#
# 特定の語があれば止める形（除外制）にすると、書かれ方の数だけ穴が空きます。
# 実際に「要修正」「マージ不可」「保留」がいずれも通り抜けました（PR #140 のレビュー）。
# **本プロジェクトは、通らない項目を「要修正」「未達」と書く取り決めです。**
# いちばん書かれやすい語で門番が黙って通る状態を残しません。
if printf '%s' "$VERDICT" | grep -q '不合格' || ! printf '%s' "$VERDICT" | grep -q '合格'; then
  cat >&2 <<EOF
マージを止めました。reviewer の判定が通っていません。

記録 : $REVIEWER_RECORD
判定 :
$(printf '%s\n' "$VERDICT" | sed 's/^/  /')

**「## 判定」の節へ「合格」と明記されているときだけ通します。**
「要修正」「未達」「保留」のままではマージできません。

指摘を修正し、reviewer を再実行して記録を更新してください。
見出しは `## 判定` だけにし、判定はその次の行から書いてください。
EOF
  exit 2
fi

exit 0
