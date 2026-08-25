# 開発の流れ

実装した工程のみを記載します。

![diagram](./development-flow-1.svg)

各工程はフックで強制しています。セキュリティレビューの記録が無ければコミットが止まり、
reviewer と pr-checker の記録が無ければマージが止まります。
