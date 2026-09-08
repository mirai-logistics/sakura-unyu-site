# 桜運輸株式会社 公式サイト — 開発ガイド

愛知県弥富市の運送会社・桜運輸株式会社のコーポレートサイト。
ビルド工程・サーバーサイド処理を持たない**静的サイト**（HTML / CSS / JavaScript のみ）。

---

## デプロイ

**`main` ブランチにpushした内容が、そのまま本番公開される。**

| 項目 | 値 |
|---|---|
| ホスティング | GitHub Pages（`mirai-logistics/sakura-unyu-site`） |
| 公開URL | https://www.sakuraunyu.com/ |
| デプロイ元 | `main` ブランチのルート |
| 反映時間 | push後 約30秒〜1分 |

リポジトリは 2026-07-23 に個人アカウント（`yanagawa-a11y`）から `mirai-logistics` Org へ移管済み。旧URLへのアクセスはリダイレクトされる。

`main` が本番デプロイブランチのため、**作業ブランチを切らず `main` へ直接コミットする運用**。
プッシュ前に必ず動作確認すること（プレビュー環境は無い）。

### ローカル確認

```bash
python3 -m http.server 8000
# → http://localhost:8000/
```

---

## ⚠️ 最重要の注意点：index.html はCSSがインライン複製されている

**`index.html` は `assets/site.css` を読み込んでいない。** 同じCSSが `<style>` タグ内にインラインで複製されている。

そのため、**共通パーツ（ヘッダー・ナビ・ハンバーガーメニュー等）のスタイルを変更する場合は、必ず次の2箇所を同じ内容に修正すること。**

1. `assets/site.css` … トップ以外の全ページが参照
2. `index.html` の `<style>` ブロック … トップページ専用

片方だけ直すと「トップだけ直らない」「トップだけ壊れる」という症状になる。

### CSSの記述順に関する既知の落とし穴

メディアクエリは詳細度を上げない。同じ詳細度なら**後に書かれた方が勝つ**。

```css
/* ❌ 効かない — 後の display:none に負ける */
@media(max-width:1080px){.menu-btn{display:grid}}
.menu-btn{display:none}

/* ✅ 正しい — 上書きを後ろに置く */
.menu-btn{display:none}
@media(max-width:1080px){.menu-btn{display:grid}}
```

過去にこれが原因で、ハンバーガーメニューがスマホ・タブレットからも消える不具合が発生している（コミット `4d8f0f8` で修正）。

### レスポンシブの分岐点

| 画面幅 | ハンバーガーメニュー | グローバルナビ |
|---|---|---|
| 1081px 以上 | 非表示 | 表示 |
| 1080px 以下 | 表示 | 非表示 |

---

## お知らせの自動更新（microCMS）

お知らせ記事は **microCMS で編集し、GitHub Actions が静的HTMLを自動生成する**。
`news/` 配下のHTMLや `news.html` を**手で編集しないこと**（次回のビルドで上書きされる）。

### 仕組み

```
microCMS で公開/更新/削除
  └→ Webhook → repository_dispatch (microcms-publish)
       └→ .github/workflows/microcms-deploy.yml
            └→ .github/scripts/build-news.mjs が以下を再生成
                 ├ news/<id>.html … 各記事ページ
                 ├ news.html      … 一覧（＋JSON-LD ItemList）
                 ├ index.html     … トップの新着欄（最新1件）
                 └ sitemap.xml    … お知らせURL
            └→ 変更があれば main へ自動commit&push → Pages再デプロイ
```

生成範囲は各ファイル内のマーカーコメント（`<!-- NEWS_URLS:START -->` 等）で挟まれた区間のみ。**マーカーを消さないこと。**

### 必要な Secrets（リポジトリ設定）

- `MICROCMS_SERVICE_ID`
- `MICROCMS_API_KEY`（読み取り可能なキー）

APIキー未設定時はスクリプトが何もせず正常終了する安全設計のため、CIは赤くならない。

### ローカルでの動作検証

```bash
MICROCMS_MOCK=1 node .github/scripts/build-news.mjs
```

サンプルデータで動くため、APIキー無しで生成ロジックを確認できる。
手動実行はGitHubの Actions 画面からも可能（`workflow_dispatch`）。

---

## ドメイン / DNS

DNSは **Canonet**（`ns1.canonet.ne.jp` / `ns2.canonet.ne.jp`）で管理。

| ホスト | 種別 | 向き先 |
|---|---|---|
| `www.sakuraunyu.com` | CNAME | `yanagawa-a11y.github.io`（**正**・`CNAME`ファイルの内容） |
| `sakuraunyu.com` | A ×4 | `185.199.108-111.153`（GitHub Pages）→ wwwへ301転送 |

**メール関連のレコード（MX / SPFのTXT / imap・pop・smtp・mx の A）は絶対に削除しないこと。**
Search Console の所有権確認用TXTも同様（削除すると確認が外れる）。

旧サイト（AWS運用時代）の ACM 証明書検証用CNAME `_6cd75b756c...` が残存しているが、無害なため放置している。

---

## SEO

- 全ページに `title` / `description` / `canonical` / OGP / 構造化データ（JSON-LD）を設置済み
- Search Console は**ドメインプロパティ**（`sc-domain:sakuraunyu.com`）で登録。所有権確認はDNSのTXTレコード方式のため、**HTMLへの認証タグ埋め込みは不要**
- `sitemap.xml` は送信済み。お知らせ追加時は自動更新されるため**再送信は不要**
- 新規ページを追加した場合のみ、`sitemap.xml` に手動で `<url>` を追記すること（マーカー区間の外に書く）

### 既知の課題

- 旧サイトのURL（拡張子なし。例 `/greeting`）が404。外部サイトからの被リンクが存在するため、転送用HTMLの設置を検討中
- GitHub Pages は**サーバー側リダイレクトが使えない**ため、転送が必要な場合はHTMLファイルを設置する方式になる

---

## ディレクトリ構成

```
├ index.html            … トップページ（CSSインライン。site.cssは読まない）
├ our_business.html     … 事業紹介
├ vehicle.html          … 保有車両
├ company.html          … 会社概要
├ recruit.html          … 採用情報
├ safety.html           … 安全への取り組み
├ reason.html           … 選ばれる理由
├ news.html             … お知らせ一覧（自動生成区間あり）
├ news/                 … お知らせ個別記事（自動生成。手動編集禁止）
├ contact.html          … お問い合わせ（Googleフォーム連携）
├ privacy.html          … プライバシーポリシー
├ 404.html              … Not Found
├ sitemap.xml           … （お知らせ部分は自動生成）
├ robots.txt
├ CNAME                 … www.sakuraunyu.com（消さないこと）
├ .nojekyll             … Jekyll処理の無効化（消さないこと）
├ assets/
│   ├ site.css          … 共通CSS（index.html以外が参照）
│   ├ site.js           … 共通JS（ハンバーガー開閉など）
│   └ img/              … 画像
└ .github/
    ├ workflows/microcms-deploy.yml
    └ scripts/build-news.mjs
```

`CNAME` と `.nojekyll` は削除するとサイトが正しく公開されなくなる。

## 開発ルール(organization共通)

organizationの全リポに効く開発ルールは`mirai-logistics/dev-rules`。clone先は各自の`~/.claude/CLAUDE.md`に書いてある。
**Issueを立てる・ブランチを切る・PRを出す・危ないコマンドを打つ・壊した**ときは、
必ず`dev-rules/README.md`の索引を読み、そこから該当ルールをReadする。

常時効くもの(正本はdev-rules):

- 🔴 `main`へ直接pushしない。ブランチを切ってPRを出す
- 🔴 自分のPRを自分でマージしない。レビュアーを指名する(例外は上野さんだけ)
- 🔴 `--dangerously-skip-permissions`と`defaultMode: bypassPermissions`を使わない
- 🔴 秘密情報をcommitしない(`.env`・鍵・給与・個人情報・取引先名)
- ⚠ `git add -A`と`git add .`を使わない。パスを明示する
- ⚠ `origin`はorg(`mirai-logistics/…`)に固定する。forkしない

⚠ **cloneしただけでは歯止めが効かない**。このリポで1回`bash scripts/setup.sh`を打つまで、
`main`への直接pushも秘密の混入も止まらない。
