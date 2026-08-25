#!/usr/bin/env bash
# マージ前の reviewer と pr-checker の実行を強制するフックです。
#
# PreToolUse(Bash) から呼ばれます。標準入力に渡されたツール呼び出しの内容に
# `gh pr merge` が含まれる場合、対象 PR の reviewer 記録と pr-checker 記録が
# review-records/ に存在しなければ、終了コード 2 でマージを止めます。
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

if [ -z "$MISSING" ]; then
  # reviewer の判定が不合格のままなら止めます。
  if grep -q '不合格' "$REVIEWER_RECORD"; then
    cat >&2 <<EOF
マージを止めました。reviewer の判定に「不合格」が残っています。

記録 : $REVIEWER_RECORD

指摘を修正し、reviewer を再実行して記録を更新してください。
EOF
    exit 2
  fi
  exit 0
fi

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
