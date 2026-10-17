<!doctype html><html lang="ja"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Japan Day Planner 修正版Swift作成</title><style>body{font-family:system-ui,sans-serif;background:#101820;color:white;max-width:740px;margin:40px auto;padding:20px}button{font-size:20px;background:#16d2dd;color:#001;padding:20px;border:0;border-radius:12px;cursor:pointer}p{line-height:1.8}#status{white-space:pre-wrap;background:#26313a;padding:15px;border-radius:8px}</style><h2>Japan Day Planner — 完全Swiftファイル復元・移動時間修正</h2><p>GitHubの2026年10月16日の完全な元コードを取得し、経路取得処理を修正して、<b>ChiikawaGuideApp.swift</b> をダウンロードします。現在のGitHubファイルは上書きしません。</p><button id="run">修正版Swiftファイルを作成・ダウンロード</button><p id="status">準備完了</p><script>
const sourceURL='https://raw.githubusercontent.com/shu39a-lang/chiikawa-odekake-guide/2bca266f97695a849a865f728fc9856da322d02f/OdekakeGuide/OdekakeGuide/ChiikawaGuideApp.swift';
const status=document.getElementById('status');
function replaceOnce(source,oldText,newText,label){const count=source.split(oldText).length-1;if(count!==1)throw Error(label+' の一致数 '+count+'（変更中止）');return source.replace(oldText,newText)}
document.getElementById('run').onclick=async()=>{try{status.textContent='元の完全コードを取得中…';const res=await fetch(sourceURL,{cache:'no-store'});if(!res.ok)throw Error('GitHub取得失敗 HTTP '+res.status);let s=await res.text();if(s.length<500000||!s.includes('import SwiftUI')||!s.includes('private enum SharedTravelEstimator'))throw Error('完全な元コードを確認できませんでした');
const old=`        // Transit must use a journey-time timetable, not a potentially empty
        // late-night Google request while the user is planning tomorrow.
        if mode == "transit" {
            // The current backend does not receive the itinerary departure time.
            // Do not present a Google *current-time* rail ETA as a planned ETA.
            return nativeResult
        }
        if let googleMinutes {
            return TravelTime(minutes: googleMinutes, isApproximate: false,
                              routeMetres: nativeResult?.routeMetres)
        }
        if let nativeResult { return nativeResult }
        if mode == "transit" { return nil } // Never invent train or bus schedules.
        return nil`;
const revised=`        // Use verified timetable routes first. If native transit has no route,
        // use the Google Routes result instead of suppressing every rail ETA.
        // The backend currently does not accept a planned departure time;
        // a Google transit ETA is therefore a current-service estimate.
        if mode == "transit" {
            if let nativeResult, nativeResult.minutes > 0 { return nativeResult }
            if let googleMinutes, googleMinutes > 0 {
                return TravelTime(minutes: googleMinutes, isApproximate: false,
                                  routeMetres: nil)
            }
            return nil
        }
        if let googleMinutes, googleMinutes > 0 {
            return TravelTime(minutes: googleMinutes, isApproximate: false,
                              routeMetres: nativeResult?.routeMetres)
        }
        if let nativeResult, nativeResult.minutes > 0 { return nativeResult }
        return nil`;
s=replaceOnce(s,old,revised,'電車の経路取得');
s=replaceOnce(s,'request.timeoutInterval = 10','request.timeoutInterval = 20','Google経路取得のタイムアウト');
const header='// RESTORED FULL SOURCE from commit 2bca266f97695a849a865f728fc9856da322d02f\n// PATCH: allow Google transit fallback when native timetable is unavailable; extend API timeout.\n';s=header+s;
const blob=new Blob([s],{type:'text/plain;charset=utf-8'});const url=URL.createObjectURL(blob);const a=document.createElement('a');a.href=url;a.download='ChiikawaGuideApp.swift';document.body.appendChild(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(url),30000);status.textContent='作成完了：約'+Math.round(blob.size/1024)+' KB。ダウンロードした ChiikawaGuideApp.swift をGitHubに全文貼り付けしてください。\n※Swiftのビルド・実機動作は未検証です。';}catch(e){status.textContent='作成できませんでした：'+e.message+'\n既存のGitHubファイルは変更していません。'}};
</script></html>
