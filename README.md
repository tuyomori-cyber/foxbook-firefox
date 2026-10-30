# Foxbook Firefox Split View

Surface などのタッチ操作中心の環境で、Firefox Split View の中央仕切りを
ドラッグできない場合に備える AutoConfig です。ナビゲーションバーに
「分割 50:50」のスライダーを追加し、左ペインの幅をタッチで変更・保存します。

現行実装の正本は[仕様書 v0.2](specification/foxbook-firefox仕様書v0.2.md)、未完了事項は[TODO](TODO.md)です。
Split Viewの片側で既存タブを切り替える[検討案](specification/Split%20Viewタブ切替仕様案.md)は見送り・クローズ済みで、未実装です。

## 内容

| パス | 用途 |
| --- | --- |
| `autoconfig/defaults/pref/foxbook-autoconfig.js` | 常用AutoConfigブートストラップを読み込ませる設定 |
| `autoconfig/foxbook-autoconfig.cfg` | Split Viewと任意導入の開発用機能を分離して読み込むブートストラップ |
| `autoconfig/foxbook-splitview.cfg` | Split View 比率スライダーの実装 |
| `scripts/install.sh` | ファイルの検証・バックアップ・導入 |
| `scripts/uninstall.sh` | 導入した常用・開発用AutoConfigの削除（明示実行時のみ） |
| `scripts/install-dev-addon.sh` | 署名なし開発用拡張を明示登録し、開発用読込器を導入 |
| `scripts/uninstall-dev-addon.sh` | 開発用読込器だけを削除 |

導入済みの原本とリポジトリ内のコピーは同一です。改変後は `scripts/install.sh`
を再実行してください。

## 導入

Firefox をすべて終了してから、このディレクトリで実行します。

```bash
sudo ./scripts/install.sh
```

通常は、`sudo` を実行したユーザーの
`~/.local/opt/foxbook-firefox`（専用Firefox）、`/usr/lib64/firefox`、
`/usr/lib/firefox`、`/opt/firefox` を順に検出します。別の場所にある Firefox
では、インストール先を明示します。

```bash
sudo ./scripts/install.sh /path/to/firefox
```

スクリプトは、既存の同名ファイルが異なる内容なら
`foxbook-autoconfig-backup-YYYYmmdd-HHMMSS` に退避してから、次の場所に
`root:root`・モード `0644` で導入します。

```text
<Firefox のインストール先>/defaults/pref/foxbook-autoconfig.js
<Firefox のインストール先>/foxbook-autoconfig.cfg
<Firefox のインストール先>/foxbook-splitview.cfg
```

AutoConfig は Firefox 本体の権限で実行されます。このリポジトリを信頼できる状態で
のみ導入し、`cfg` の内容を未確認のまま差し替えないでください。

## 開発用の署名なし拡張

この節の機能は常用のSplit View機能とは独立した、Surface実機での開発・検査専用です。
通常の `install.sh` は拡張を読み込みません。

拡張を展開済みの開発元ディレクトリとして用意し、Firefoxを終了して明示導入します。
この前に一度、常用の `install.sh` を導入済みである必要があります。拡張ソースはコピーせず、
root所有の登録表 `/etc/foxbook/dev-addons.tsv` に拡張IDと開発元の絶対パスを記録します。

```bash
sudo ./scripts/install-dev-addon.sh <ADDON_ID> /path/to/extension-source
```

スクリプトは `manifest.json` のGecko IDを検査してから、登録済みIDと開発元の組を追加・更新します。
以後、Firefox起動後にその開発元の拡張だけを一時読み込みします。読み込みは署名不要ですが、
Firefox終了時に消え、次回起動時に再読込されます。初期タブより前に有効になる保証はありません。

### 複数の開発プロジェクトを登録する例

`~/project` に複数の拡張プロジェクトがあり、各プロジェクト直下に
`manifest.json` がある場合は、常用機能を一度導入してから、拡張ごとに一度ずつ登録します。
`ADDON_ID` は各 `manifest.json` の `browser_specific_settings.gecko.id`（旧形式では
`applications.gecko.id`）と完全一致させます。

```bash
cd ~/project/foxbook-firefox

# 常用のSplit Viewを一度だけ導入する。
sudo ./scripts/install.sh

# ~/project 内の開発用拡張を個別に登録する。
sudo ./scripts/install-dev-addon.sh foxbook-helper@example.com ~/project/foxbook-helper
sudo ./scripts/install-dev-addon.sh setoli-devtools@example.com ~/project/setoli-devtools
sudo ./scripts/install-dev-addon.sh ui-checker@example.com ~/project/ui-checker
```

登録した拡張はすべて、次回Firefox起動後に一時読み込みされます。

### ソース変更をFirefox再起動なしで反映する

ソースを保存した後、Firefoxツールバーの「開発拡張を再読み込み」を押します。登録済みの
一時拡張だけが、同じ開発元ディレクトリから再読込されます。background scriptと
`manifest.json` の変更が反映されます。すでに開いているタブのcontent scriptを反映するには、
必要に応じてそのタブも再読み込みしてください。

Firefox本体を自動検出できない場合だけ、Firefoxの `application.ini` があるディレクトリを
最後の引数として追加します。

```bash
sudo ./scripts/install-dev-addon.sh \
  setoli-devtools@example.com \
  ~/project/setoli-devtools \
  /path/to/firefox
```

開発用読込だけを止める場合は次を実行します。開発元と登録表は残ります。

```bash
sudo ./scripts/uninstall-dev-addon.sh
```

## 使い方

1. Firefox を起動します。
2. ツールバーに表示される「分割 50:50」スライダーを指で動かします。
3. 左側の幅は 30–60% の範囲、5% 刻みで即時に反映されます。
4. 指を離して値が確定すると、比率がプロファイルの
   `foxbook.splitview.savedRatio` に保存されます。以後、新しく開く Split View に
   自動適用されます。

ツールバーをカスタマイズした後は、ユーザーが置いた位置を尊重します。スライダーを
非表示にした場合は、Firefox の「ツールバーをカスタマイズ」から再び配置できます。

## 動作確認と診断

導入確認は次で行えます。

```bash
sudo ./scripts/install.sh --check
```

Firefox 上で自己診断を行うには、`about:config` で
`foxbook.splitview.probe.selftest` を `true` に設定し、保存済みの比率を一度作ってから
Firefox を再起動します。結果は `about:config` の
`foxbook.splitview.probe.result` に `passed: ...` として記録されます。

Firefox 本体の更新後は Split View の内部 API が変わる可能性があるため、まずこの
自己診断と実際のタッチ操作を確認してください。

## 更新・削除

実装を更新した場合は Firefox を終了して `sudo ./scripts/install.sh` を再実行します。

削除する場合も Firefox を終了し、対象の Firefox を必要に応じて指定して実行します。

```bash
sudo ./scripts/uninstall.sh
sudo ./scripts/uninstall.sh /path/to/firefox
```

削除スクリプトはこの機能のファイル名だけを対象にし、他の AutoConfig 設定には触れません。
インストール時に作られたバックアップは自動削除しません。
