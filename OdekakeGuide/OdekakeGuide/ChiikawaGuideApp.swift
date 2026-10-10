Japan Day Plan 移動時間表示修正案（完全置換用Swiftファイルではありません）
対象: OdekakeGuide/OdekakeGuide/ChiikawaGuideApp.swift

確認できた原因候補:
・位置情報が未解決のとき、徒歩・タクシーの時間を算出できない。
・経路ボタンが時間も状態文言も表示しない分岐がある。
・地図検索が失敗しても経路時間が必ず得られるわけではない。

変更する範囲:
1. timedRouteLink(...) 内の最後の条件分岐を変更

【元】
                } else if canEstimate {
                    ProgressView().tint(accent)
                }

【修正案】
                } else if canEstimate {
                    Text(hotelTravelText("calculating"))
                        .font(.caption)
                        .multilineTextAlignment(.trailing)
                } else {
                    Text(travelFailureText(mode: mode, missingPlace: true))
                        .font(.caption)
                        .multilineTextAlignment(.trailing)
                }

注意: この修正は空白を解消する表示改善です。位置情報の取得失敗そのものは解消せず、所要時間が必ず取得できる保証はありません。
GitHubへの保存は接続権限エラー403により未実施。ビルド・実機検証未実施。
