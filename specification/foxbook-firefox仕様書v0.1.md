# foxbook-firefox 仕様書 v0.1

- 文書バージョン：0.1
- 作成日：2026-10-26
- 状態：現行実装ベース
- 対象：Firefox AutoConfigによるSplit View比率操作

## 1. 目的

SurfaceなどでSplit View中央仕切りをタッチドラッグできない場合に、ナビゲーションバーのスライダーから左ペイン幅を操作・保存する。対象はFirefox本体のUIであり、Webページ、拡張、Native Messagingから入力を受けない。

## 2. 動作

- `foxbook-splitview.cfg`はAutoConfigとしてFirefox起動後に読み込まれる。
- `foxbook-splitview-ratio`ウィジェットをナビゲーションバーへ一度だけ配置する。以後のユーザーによるツールバーカスタマイズを尊重する。
- 左ペイン比率は30〜60%、5%刻み。input中は即時反映し、change時に`foxbook.splitview.savedRatio`へ文字列として保存する。
- `SplitViewCreated`後に保存値を適用する。内部API・パネル・寸法が利用できない場合は変更せず、コンソールへ記録する。
- `foxbook.splitview.probe.selftest=true`で一時Split Viewを作り、適用値を`foxbook.splitview.probe.result`へ記録する。

## 3. 導入と安全境界

`scripts/install.sh`はrootで実行し、Firefoxの`defaults/pref/`と直下へ2ファイルだけを`0644 root:root`で導入する。既存同名ファイルが異なる場合は時刻付きバックアップへ退避する。`uninstall.sh`はこの2ファイルだけを明示削除し、バックアップや他のAutoConfigには触れない。

AutoConfigはFirefox本体権限で動くため、信頼できるリポジトリ内容だけを導入する。Firefox内部APIに依存するため、Firefox更新後は自己診断と実機操作を必ず確認する。

## 4. 検証

AutoConfig JavaScript構文と導入・削除スクリプト構文は2026-10-26に確認済み。Xubuntu／Surfaceでのタッチ操作、保存・再起動復元、ツールバー再配置、Firefox更新後の自己診断は未確認である。
