# Step 4: Claude Design ハンドオフ（UI を含む場合）

対象が UI を含む場合（LP、ダッシュボード、モバイル画面、ランディング等）。Claude Design は **2026-04-17 公開の Research Preview、Pro/Max/Team/Enterprise 限定、最新 Opus 駆動**。

## 4.1 使用可否の確認

```
UI デザインが必要です。Claude Design（claude.ai/design）を使って最初のプロトタイプ
を作成してから実装に進む方針でよいですか？

- Yes: Claude.ai の Design モードでプロトタイプ作成 → 公式ハンドオフで Claude Code へ
- No: Design Doc の UI セクションで代替（ワイヤーフレーム + コンポーネント分解）
```

Pro/Max 以上のサブスクリプションが無い場合、`No` フローへ自動で案内。

## 4.2 Claude Design に渡すプロンプト構造（Yes の場合）

**4 要素テンプレート** で user に入力を促す:

- **Goal**: 何を達成する UI か（1-2 文）
- **Layout**: レイアウトの指定（カラム数、ナビ位置、モバイル対応等）
- **Content**: 含むべきコンテンツ要素（セクション、データ種別、画像）
- **Audience**: ターゲットユーザー（年齢層、技術レベル、利用文脈）

**補助素材（任意、精度向上）**:
- デザインシステム（Figma ファイル名 / トークン一覧 / ブランドガイド）
- 参考 UI のスクリーンショット
- **初回コードベースリンク**（既存コード規約を反映させる、**強く推奨**）
- 既存の `docs/specs/designs/` にあるドラフト

## 4.3 Claude Design → Claude Code ハンドオフ（公式 1 ステップフロー）

1. Claude Design でプロトタイプ完成後、**Export → "Hand off to Claude Code"** を選ぶ
2. バンドル ZIP が自動生成（中身: `README.md` + `prototype.html` + `assets/`）
3. Claude Design がペースト用プロンプト（バンドル URL 入り）を発行
4. それを **Claude Code にペースト**するだけで実装開始

**バンドル展開先**:
- 推奨: `docs/specs/designs/{topic}/` に保存（プロジェクト内共有）
- あるいは Claude Code が URL を直接参照（一時的）

**バンドル内容**:
- `README.md`（約 26KB）: デザイントークン定義、コンポーネント境界、実装優先順位、採用バリアント推奨。AI 向けに「トークンを最初に実装せよ（他のブロッカー）」等の具体的指示を含む
- `prototype.html`（約 72KB）: 複数バリアントを含むクリッカブル HTML プロトタイプ
- `assets/`: 画像・アイコン等

Claude Code は `README.md` を読んで既存コードベース規約に沿って実装を生成する。

## 4.4 制約と注意点（リサーチプレビュー）

- マルチプレイヤー非対応
- Figma ファイル**直接エクスポート不可**
- API **未公開**
- Pro プランは週次制限が厳しい（2 セッションで 58% 消費の報告あり）→ **Max 推奨**
- **数値・法的テキストに hallucination リスクあり** → 本番前に user レビュー必須
- フォールバック（Pro 以下 / Claude Design 非対応時）:
  - v0.dev → Claude Code
  - Figma + Figma MCP 経由（banto の figma-implement-design skill）

## 4.5 `No` ルート（Design Doc 代替）

Claude Design が使えない / UI が重要でない場合:
- Design Doc の「3.1 概要図」と「3.2 コンポーネント」で UI を文章で定義
- ASCII アート or Mermaid 記法でワイヤーフレーム代替
- 必要なら Figma-implement-design skill にフォールバック
