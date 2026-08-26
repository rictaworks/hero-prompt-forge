#!/usr/bin/env bash
# マージ前の reviewer と pr-checker の実行を強制するフックです。
#
# PreToolUse(Bash) から呼ばれます。標準入力に渡されたツール呼び出しの内容に
# マージの呼び出しが含まれる場合、対象 PR の reviewer 記録と pr-checker 記録が
# review-records/ に存在しなければ、終了コード 2 でマージを止めます。
#
# **判定は「## 判定」の節だけを読みます。** 記録の全文を対象にすると、
# 本文で語を挙げただけでマージが止まります。実際に PR #119 と PR #121 で、
# 「不合格の指摘はありません」という合格を意味する文で止まりました（issue #122）。
#
# **最後の「## 判定」の節だけを読みます。** 本プロジェクトは、再レビューの
# 結果を同じ記録へ追記します。すべての節をつないで見ると、**先に書いた古い
# 判定に引きずられます**（issue #142）。
#
# **判定の節の先頭行が、既定の語のいずれかと一致することを求めます。**
# 語の有無で見ると、「合格ではありません」「要修正のため合格に届きません」と
# 書いた記録が通ります（PR #140 のレビューで実測）。
set -u

PAYLOAD="$(cat)"

# マージの呼び出しを含まない場合は対象外です。
# **この語をこのファイルへ直接書きません。** 自分自身に反応します。
MERGE_CALL="gh pr$(printf ' ')merge"
case "$PAYLOAD" in
  *"$MERGE_CALL"*) ;;
  *) exit 0 ;;
esac

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
if [ -z "$REPO_ROOT" ]; then
  echo "マージ前フックがリポジトリを特定できませんでした。" >&2
  exit 2
fi
cd "$REPO_ROOT" || exit 2

# マージの呼び出しから PR 番号を取り出します。
PR_NUMBER="$(printf '%s' "$PAYLOAD" | grep -oE "${MERGE_CALL}[^\"]*" | grep -oE '[0-9]+' | head -n 1)"
if [ -z "$PR_NUMBER" ]; then
  cat >&2 <<EOF
マージを止めました。PR 番号を特定できません。

\`${MERGE_CALL} <PR番号>\` の形式で、番号を明示して実行してください。
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

# 最後の「## 判定」の節だけを取り出します。次の「## 」で終わりです。
#
# **コードの塀（```）の中は見ません。** 記録の中でフックの書式を例示すると、
# 例示した見出しを本物の節として拾ってしまいます。
VERDICT="$(awk '
  /^```/                             { fenced = !fenced; next }
  fenced                             { next }
  /^##[[:space:]]+判定[[:space:]]*$/ { inside = 1; body = ""; next }
  /^##[[:space:]]/                   { inside = 0 }
  inside                             { body = body $0 "\n" }
  END                                { printf "%s", body }
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

# 節の先頭の、中身のある行だけを見ます。
FIRST_LINE="$(printf '%s\n' "$VERDICT" | awk 'NF { print; exit }')"

# 強調の記号・空白・末尾の句点を落として、語そのものにそろえます。
NORMALIZED="$(printf '%s' "$FIRST_LINE" | sed 's/[*＊`]//g; s/[[:space:]]//g; s/　//g; s/[。．\.]$//')"

# **既定の語のいずれかと一致することを求めます（許可制）。**
# 語の有無で見ると、「合格ではありません」のような否定した書き方が通ります。
case "$NORMALIZED" in
  合格|条件付き合格)
    exit 0
    ;;
  要修正|未達|保留)
    REASON="判定が通っていません"
    ;;
  *)
    REASON="判定の書き方が既定の語と一致しません"
    ;;
esac

cat >&2 <<EOF
マージを止めました。${REASON}。

記録 : $REVIEWER_RECORD
判定の先頭行 :
  ${FIRST_LINE}

**「## 判定」の節の先頭行へ、次のいずれかだけを書いてください。**

  合格 / 条件付き合格 / 要修正 / 未達 / 保留

通すのは「合格」と「条件付き合格」だけです。
理由や指摘は、その次の行から書いてください。
EOF
exit 2
