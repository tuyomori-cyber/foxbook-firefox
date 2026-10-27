# foxbook-firefox 仕様書 v0.2

- 文書バージョン：0.2
- 作成日：2026-10-27
- 状態：実装対象
- 対象：常用のSplit View操作と開発用一時拡張読込の分離

## 1. 目的

`foxbook-firefox` は、常用するSplit View比率操作と、Surface実機で拡張を開発・検査するための署名なし一時拡張読込を明確に分離する。開発用機能の有無・失敗が、常用のSplit View機能に影響してはならない。

## 2. 構成

Firefox AutoConfigは設定できる主ファイルが一つだけである。このため、常用のブートストラップ `foxbook-autoconfig.cfg` を唯一のAutoConfigエントリとし、そこから次を独立して読み込む。

| 区分 | ファイル | 導入条件 | 役割 |
| --- | --- | --- | --- |
| 常用 | `foxbook-splitview.cfg` | `install.sh` | Split View比率スライダーと保存値の適用 |
| 常用 | `foxbook-autoconfig.cfg` / `foxbook-autoconfig.js` | `install.sh` | 常用AutoConfigのブートストラップ |
| 開発 | `foxbook-dev-temp-addon.cfg` | `install-dev-addon.sh` | 許可済み拡張を起動後に一時読込 |

ブートストラップは開発用ファイルが存在する場合にだけそれを読み込む。Split View実装は開発用の状態・設定・例外を参照しない。

## 3. 常用機能

`sudo ./scripts/install.sh [FIREFOX_DIR]` は、ブートストラップとSplit Viewだけを導入する。署名なし拡張の読込設定、許可リスト、拡張ディレクトリには触れない。

`sudo ./scripts/uninstall.sh [FIREFOX_DIR]` は常用AutoConfigを削除する。開発用AutoConfigを残すことは許容しないため、開発用AutoConfigも同時に削除して、一時拡張読込を停止する。開発元の登録表は削除しない。

## 4. 開発用の一時拡張読込

### 4.1 導入と停止

```bash
sudo ./scripts/install-dev-addon.sh ADDON_ID SOURCE_DIR [FIREFOX_DIR]
sudo ./scripts/uninstall-dev-addon.sh [FIREFOX_DIR]
```

導入スクリプトは、開発元の `SOURCE_DIR` が展開済みWebExtensionであり、`manifest.json` のGecko IDが引数の `ADDON_ID` と一致することを検査する。合格したIDと解決済み絶対パスの組をroot所有の登録表 `/etc/foxbook/dev-addons.tsv` へ登録し、開発用AutoConfigをFirefox本体へ導入する。拡張ソース自体はコピーしない。

Firefox起動後、開発用AutoConfigは登録表の各IDについて、対応する開発元ディレクトリだけを `AddonManager.installTemporaryAddon()` で読み込む。一時拡張は署名不要で、そのFirefoxプロセスの終了時に自動削除される。最初のタブ読み込みより前に有効化されることは保証しない。開発用AutoConfigはツールバーへ「開発拡張を再読み込み」ボタンを追加し、クリック時に登録済みの一時拡張だけを `addon.reload()` する。

### 4.2 安全境界

- 読込候補は、root所有・通常ユーザー非書込みの `/etc/foxbook/dev-addons.tsv` に完全一致で登録されたID・絶対パスの組だけとする。
- IDにはパス区切り・空白・制御文字を許可せず、登録表にはタブ・改行を含むパスを記録しない。
- 導入時とReload時に、開発元の `manifest.json` のGecko IDを登録IDと照合する。
- 開発元は開発ユーザーが変更できることを意図的に許容する。開発用Reloadボタンを押した時点のファイル内容が実行対象となる。
- SHA-256は開発中のソース更新を阻害するため、この開発用機能では固定しない。配布・常用する拡張には署名済みXPIとFirefoxポリシーを用いる。
- AutoConfigと拡張ソースを編集できるroot権限の主体は信頼境界の外側であり、その改変は防げない。

## 5. 診断と失敗時の扱い

- 開発用読込の成功・スキップ・失敗はFirefoxコンソールへ `[Foxbook dev addon]` 接頭辞で記録する。
- 一つの拡張が無効・不正・既に読み込み済みでも、他の登録済み拡張とSplit View処理を停止しない。
- Firefox内部APIの変更などで開発用機能が失敗した場合は、`uninstall-dev-addon.sh` で開発用AutoConfigだけを取り除ける。

## 6. 検証項目

1. `install.sh` のみを導入し、Split Viewスライダーが従来どおり機能し、開発用拡張が読まれないこと。
2. `install-dev-addon.sh` で正しい展開済み拡張を登録し、Firefox起動後に `about:debugging` で一時拡張として確認できること。
3. 開発元を変更して「開発拡張を再読み込み」を押し、Firefox再起動なしでbackground scriptとmanifest変更が反映されること。
4. manifest ID不一致、登録表外の拡張、登録後にmanifest IDが変わった拡張を拒否すること。
5. `uninstall-dev-addon.sh` 後、Split Viewを維持したまま一時拡張が読まれないこと。
6. Firefox更新後に、Split View自己診断と一時拡張読込・Reloadを実機で再確認すること。
