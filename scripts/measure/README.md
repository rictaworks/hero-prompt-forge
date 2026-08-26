# 検出範囲の計測

**検出の仕組みを触ったときに、両方向（誤検出と取りこぼし）で測るための道具です。**
片方だけを追うと、検出側が痩せても気づけません。

| ファイル | 測るもの |
|---|---|
| `anti_ai_coverage.rb` | アンチAIルック規則（requirements.md 4.2） |
| `forbidden_input_coverage.rb` | 禁止入力の検出（requirements.md 4.1 の 1） |
| `proper_noun_coverage.rb` | 日本語固有名詞の切り出し（requirements.md 4.1 の 6） |

## 実行

```bash
docker compose exec dev bash -c 'cd /workspace/src/backend && RAILS_ENV=test bin/rails runner ../../scripts/measure/anti_ai_coverage.rb'
docker compose exec dev bash -c 'cd /workspace/src/backend && RAILS_ENV=test bin/rails runner ../../scripts/measure/forbidden_input_coverage.rb'
docker compose exec dev bash -c 'cd /workspace/src/backend && RAILS_ENV=test bin/rails runner ../../scripts/measure/proper_noun_coverage.rb'
```

**素材の一覧は、レビューで積み上げたものです。** 減らさずに足してください。
減らすと、これまでに防いだ後戻りが分からなくなります。
