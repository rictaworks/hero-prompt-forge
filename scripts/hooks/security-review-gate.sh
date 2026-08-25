#!/usr/bin/env bash
# コミット前のセキュリティレビューを強制するフックです。
#
# PreToolUse(Bash) から呼ばれます。標準入力に渡されたツール呼び出しの内容に
# `git commit` が含まれる場合、対応するセキュリティレビュー記録が
# review-records/security-review/ に存在しなければ、終了コード 2 でコミットを止めます。
#
# 記録にはステージ済み差分の指紋を書きます。差分が変われば指紋が変わるため、
# 「昔のレビュー記録で通す」ことができません。
set -u

PAYLOAD="$(cat)"

# git commit を含まない呼び出しは対象外です。
case "$PAYLOAD" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
if [ -z "$REPO_ROOT" ]; then
  echo "セキュリティレビューのフックがリポジトリを特定できませんでした。" >&2
  exit 2
fi
cd "$REPO_ROOT" || exit 2

BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
SAFE_BRANCH="$(printf '%s' "$BRANCH" | tr '/' '-')"
RECORD_DIR="review-records/security-review"
RECORD="$RECORD_DIR/${SAFE_BRANCH}.md"

STAGED_DIFF="$(git diff --cached -- . ":(exclude)review-records/")"
if [ -z "$STAGED_DIFF" ]; then
  echo "ステージされた変更がありません。" >&2
  exit 2
fi
FINGERPRINT="$(printf '%s' "$STAGED_DIFF" | sha256sum | cut -c1-16)"

if [ -f "$RECORD" ] && grep -q "$FINGERPRINT" "$RECORD"; then
  exit 0
fi

cat >&2 <<EOF
コミットを止めました。セキュリティレビューが未実施です。

ブランチ : $BRANCH
差分の指紋 : $FINGERPRINT

次の手順で進めてください。

1. security-review を実行し、ステージ済みの差分を検査します。
   検査の観点は .claude/OWASP10.md に従います。
2. 結果を次のファイルへ記録します（版管理対象です）。
   $RECORD
3. 記録の本文に、上の差分の指紋をそのまま書きます。
   指紋 : $FINGERPRINT
4. 記録を追加したうえで、あらためてコミットします。

差分を変更した場合は指紋が変わります。レビューをやり直してください。
EOF
exit 2
