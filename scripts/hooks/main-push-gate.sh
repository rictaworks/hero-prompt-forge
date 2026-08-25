#!/usr/bin/env bash
# main への直接 push を止めるフックです。
#
# PreToolUse(Bash) から呼ばれます。標準入力に渡されたツール呼び出しの内容に
# `git push` が含まれ、いま main にいて、かつ origin/main との差分に src/ が
# 含まれる場合、終了コード 2 で push を止めます。
#
# CLAUDE.md の決まり：
#   - main ブランチでの作業を禁止します
#   - src/** の変更は必ず PR を作成します。直接 push を禁止します
#   - src/** 以外（ドキュメント・SPEC/・TASKS/ 等）は main への push を許可します
set -u

PAYLOAD="$(cat)"

case "$PAYLOAD" in
  *"git push"*) ;;
  *) exit 0 ;;
esac

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
if [ -z "$REPO_ROOT" ]; then
  echo "main への push を確認するフックが、リポジトリを特定できませんでした。" >&2
  exit 2
fi
cd "$REPO_ROOT" || exit 2

BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
if [ "$BRANCH" != "main" ]; then
  exit 0
fi

# origin/main より先にあるコミットの変更範囲を見ます。
CHANGED="$(git diff --name-only origin/main..HEAD 2>/dev/null)"
if [ -z "$CHANGED" ]; then
  exit 0
fi

SRC_CHANGES="$(printf '%s\n' "$CHANGED" | grep '^src/' || true)"
if [ -z "$SRC_CHANGES" ]; then
  # src/ を含まない変更は main への push を許します。
  exit 0
fi

cat >&2 <<EOF
push を止めました。src/ の変更を main へ直接 push しようとしています。

現在のブランチ : $BRANCH
src/ の変更    :
$(printf '%s\n' "$SRC_CHANGES" | sed 's/^/  /')

src/ の変更は必ず PR を経由します。次の手順で進めてください。

1. ブランチへ移します（履歴を書き換えずに移せます）。
     git branch feature/<内容>
     git reset --hard origin/main
     git checkout feature/<内容>
2. push して PR を作ります。
3. reviewer と pr-checker の記録を添えてマージします。

src/ を含まない変更（文書・SPEC・記録）は、main への push を許しています。
EOF
exit 2
