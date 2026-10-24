# Foxbook Firefox Split View

Surface などのタッチ操作中心の環境で、Firefox Split View の中央仕切りを
ドラッグできない場合に備える AutoConfig です。ナビゲーションバーに
「分割 50:50」のスライダーを追加し、左ペインの幅をタッチで変更・保存します。

## 内容

| パス | 用途 |
| --- | --- |
| `autoconfig/defaults/pref/foxbook-splitview-autoconfig.js` | Firefox に AutoConfig 本体を読み込ませる設定 |
| `autoconfig/foxbook-splitview.cfg` | Split View 比率スライダーの実装 |
| `scripts/install.sh` | ファイルの検証・バックアップ・導入 |
| `scripts/uninstall.sh` | 導入した 2 ファイルの削除（明示実行時のみ） |

導入済みの原本とリポジトリ内のコピーは同一です。改変後は `scripts/install.sh`
を再実行してください。

## 導入

Firefox をすべて終了してから、このディレクトリで実行します。

```bash
sudo ./scripts/install.sh
```

通常は `/usr/lib64/firefox`、`/usr/lib/firefox`、`/opt/firefox` を順に検出します。
別の場所にある Firefox では、インストール先を明示します。

```bash
sudo ./scripts/install.sh /path/to/firefox
```

スクリプトは、既存の同名ファイルが異なる内容なら
`foxbook-splitview-backup-YYYYmmdd-HHMMSS` に退避してから、次の場所に
`root:root`・モード `0644` で導入します。

```text
<Firefox のインストール先>/defaults/pref/foxbook-splitview-autoconfig.js
<Firefox のインストール先>/foxbook-splitview.cfg
```

AutoConfig は Firefox 本体の権限で実行されます。このリポジトリを信頼できる状態で
のみ導入し、`cfg` の内容を未確認のまま差し替えないでください。

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
