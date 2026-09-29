import SwiftUI

// iPhoneアプリの最初の土台。Xcodeでこのファイルを追加する場合は、
// 既存の @main App ファイルと重複しないよう、どちらか一方だけを使います。
@main
struct ChiikawaGuideApp: App {
    var body: some Scene {
        WindowGroup {
            GuideRootView()
                .preferredColorScheme(.dark)
        }
    }
}

private enum GuideStyle {
    static let navy = Color(red: 0.08, green: 0.17, blue: 0.29)
    static let panel = Color(red: 0.13, green: 0.25, blue: 0.38)
    static let header = Color(red: 0.09, green: 0.20, blue: 0.33)
    static let yellow = Color(red: 0.95, green: 0.77, blue: 0.40)
    static let background = navy
    static let muted = Color(red: 0.82, green: 0.89, blue: 0.94)
    static let border = Color(red: 0.43, green: 0.57, blue: 0.69)
}

private struct GuideItem: Identifiable, Decodable {
    enum Category: String, Decodable, Equatable { case event, shop, goods }
    let id: String
    let category: Category
    let title: String
    let detail: String
    let region: String
    let badge: String
    let button: String
    let url: URL
    var period: String? = nil
    var venue: String? = nil
    var startsOn: String? = nil
    var eventType: String? = nil
    var endsOn: String? = nil // yyyy-MM-dd。終了日の翌日から一覧に表示しない。
    var keywords: String? = nil
}

private struct GuideSource: Decodable, Identifiable {
    let title: String
    let region: String
    let detail: String
    let url: URL
    let types: [String]
    let keywords: String
    var id: String { url.absoluteString }
}

private struct GuideFeed: Decodable {
    let schemaVersion: Int
    let checkedOn: String
    let items: [GuideItem]
    let sources: [GuideSource]?
}

private enum GuideData {
    // 初期データは手動確認。公開前・公開後も開催日とリンクを定期的に更新する。
    static let checkedOn = "2026年9月28日"
    static let feedURL = URL(string: "https://chiikawa-odekake-guide.shu-tok39.chatgpt.site/guide-data-v2.json")!
    static let privacyURL = URL(string: "https://chiikawa-odekake-guide.shu-tok39.chatgpt.site/privacy.html")!
    static let allowedHosts: Set<String> = [
        "www.tokyo-skytree.jp", "chiikawapark-tokyo.jp", "cafe.parco.jp",
        "chiikawa-info.jp", "www.chiikawamogumogu.jp", "chiikawabakery.jp",
        "chiikawamarket.jp", "eshop.fujitv.co.jp",
        "www.sapporo.travel", "www.sapporo-kokusai.jp", "www.expo2025.or.jp",
        "hololivepro.com", "www.sakaepark.co.jp", "www.crossroadfukuoka.jp",
        "www.hetalia-20thex.com", "szo.handmade-marche.jp",
        "www.kagoshima-kankou.com", "www.creema.jp", "minne.com",
        "www.tokyo-park.or.jp", "www.welcome.city.yokohama.jp",
        "osaka-info.jp", "www.visit-hokkaido.jp", "www.tohokukanko.jp",
        "www.aichinow.pref.aichi.jp", "ja.kyoto.travel", "www.okinawastory.jp"
    ]
    static func isValid(_ feed: GuideFeed) -> Bool {
        feed.schemaVersion == 2 && !feed.checkedOn.isEmpty &&
        (1...500).contains(feed.items.count) &&
        Set(feed.items.map(\.id)).count == feed.items.count &&
        feed.items.allSatisfy { item in
            item.url.scheme == "https" &&
            item.url.host.map { allowedHosts.contains($0) } == true &&
            !item.title.isEmpty && !item.button.isEmpty
        } && (feed.sources ?? []).allSatisfy { source in
            source.url.scheme == "https" &&
            source.url.host.map { allowedHosts.contains($0) } == true
        }
    }
    static func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        return formatter.string(from: date)
    }
    static func localToday() -> String { dateString(Date()) }
    static let bundledFeed: GuideFeed? = {
        let text = #"""
{"schemaVersion":2,"checkedOn":"2026年9月28日","items":[{"id":"skytree","title":"ちいかわ☆星ふるスカイツリー®とひみつの島","detail":"東京スカイツリー／10月31日まで。展示や限定メニューなど。","region":"東京","badge":"開催中","button":"公式のイベント詳細","url":"https://www.tokyo-skytree.jp/event/special/chiikawa/","period":"2026年7月10日〜10月31日","venue":"東京スカイツリー","endsOn":"2026-10-31","category":"event","eventType":"character","startsOn":"2026-07-10"},{"id":"cafe-osaka","title":"映画ちいかわ コラボレーションカフェ","detail":"心斎橋PARCO／9月28日まで。予約や利用条件を会場ページで確認。","region":"大阪","badge":"9月28日まで","button":"会場の詳細","url":"https://cafe.parco.jp/event/information/chiikawamovie_cafe_osaka?area=029441","period":"2026年7月24日〜9月28日","venue":"心斎橋PARCO","endsOn":"2026-09-28","category":"event","eventType":"character","startsOn":"2026-07-24"},{"id":"machida-popup","title":"ちいかわ POP UP STORE 町田モディ","detail":"町田駅近くの期間限定店。入店方法は公式ページで確認。","region":"東京","badge":"期間限定","button":"町田の公式ページ","url":"https://chiikawa-info.jp/p26/pus_matd/","period":"2026年10月9日〜11月1日","venue":"町田モディ 4F イベントスペース","startsOn":"2026-10-09","endsOn":"2026-11-01","category":"event","eventType":"character"},{"id":"popup","title":"期間限定ショップの催事一覧","detail":"開催地と期間は公式の催事一覧で確認できます。","region":"全国","badge":"随時更新","button":"公式の催事一覧","url":"https://chiikawa-info.jp/pus.html","category":"shop"},{"id":"tachikawa-magical","title":"まじかるちいかわ POP UP STORE 立川","detail":"グランデュオ立川の期間限定店。入店方法は公式ページで確認。","region":"東京","badge":"期間限定","button":"立川の公式ページ","url":"https://chiikawa-info.jp/p26/mg_tckw/index.html","period":"2026年9月30日〜11月8日","venue":"グランデュオ立川 2F","startsOn":"2026-09-30","endsOn":"2026-11-08","category":"event","eventType":"character"},{"id":"sapporo-magical","title":"まじかるちいかわ POP UP SHOP 札幌","detail":"期間限定店。入店方法は公式ページで確認。","region":"北海道","badge":"期間限定","button":"札幌の公式ページ","url":"https://chiikawa-info.jp/magical_store/kd_spr/index.html","period":"2026年10月2日〜11月3日","venue":"キデイランド POP UP SHOP","startsOn":"2026-10-02","endsOn":"2026-11-03","category":"event","eventType":"character"},{"id":"oita-land","title":"ちいかわらんど POP UP SHOP 大分","detail":"期間限定店。入店方法は公式ページで確認。","region":"大分","badge":"期間限定","button":"大分の公式ページ","url":"https://chiikawa-info.jp/chiikawaland/oita/index.html","period":"2026年9月11日〜10月12日","venue":"アミュプラザおおいた 2F","startsOn":"2026-09-11","endsOn":"2026-10-12","category":"event","eventType":"character"},{"id":"land","title":"ちいかわらんど","detail":"全国の常設店。営業時間・入店方法は各店舗の案内を確認。","region":"全国","badge":"常設店","button":"店舗一覧を見る","url":"https://chiikawa-info.jp/ck_land.html","category":"shop"},{"id":"park","title":"ちいかわパーク","detail":"東京・池袋。チケット販売と利用案内。","region":"東京","badge":"施設","button":"チケット案内","url":"https://chiikawapark-tokyo.jp/ticket","category":"shop"},{"id":"bakery-tokyo","title":"ちいかわベーカリー 表参道","detail":"オモカド3階。入店方法と営業時間を公式案内で確認。","region":"東京","badge":"飲食","button":"表参道店の案内","url":"https://chiikawabakery.jp/information/","category":"shop"},{"id":"bakery-osaka","title":"ちいかわベーカリー OSAKA","detail":"KITTE大阪3階。入店方法と営業時間を公式案内で確認。","region":"大阪","badge":"飲食","button":"大阪店の案内","url":"https://chiikawabakery.jp/information-osaka/","category":"shop"},{"id":"ramen-ikebukuro","title":"ちいかわラーメン 豚 池袋","detail":"池袋PARCO本館8階。予約・入店方法は公式案内で確認。","region":"東京","badge":"飲食","button":"池袋店の案内","url":"https://cafe.parco.jp/event/chiikawaramenbuta_ikebukuro?area=029688","category":"shop"},{"id":"ramen-shibuya","title":"ちいかわラーメン 豚 渋谷","detail":"渋谷PARCO地下1階。予約・入店方法は公式案内で確認。","region":"東京","badge":"飲食","button":"渋谷店の案内","url":"https://cafe.parco.jp/event/chiikawaramenbuta_shibuya?area=029979","category":"shop"},{"id":"mogumogu-kawagoe","title":"ちいかわもぐもぐ本舗 川越店","detail":"埼玉・川越。和をテーマにしたお菓子や雑貨のお店。","region":"埼玉","badge":"常設店","button":"川越店の案内","url":"https://www.chiikawamogumogu.jp/stores/kawagoe/","category":"shop"},{"id":"mogumogu-fushimi","title":"ちいかわもぐもぐ本舗 京都伏見店","detail":"京都・伏見。和をテーマにしたお菓子や雑貨のお店。","region":"京都","badge":"常設店","button":"京都伏見店の案内","url":"https://www.chiikawamogumogu.jp/stores/fushimi/","category":"shop"},{"id":"cafe","title":"コラボカフェ","detail":"開催中の会場や期間を確認。","region":"全国","badge":"飲食","button":"カフェ情報を見る","url":"https://chiikawa-info.jp/cafe.html","category":"shop"},{"id":"harajuku","title":"ちいかわらんど 原宿店","detail":"東京・原宿。来店前に入店方法を確認。","region":"東京","badge":"常設店","button":"原宿店の公式ページ","url":"https://chiikawa-info.jp/chiikawaland/harajuku/index.html","category":"shop"},{"id":"tokyo-station","title":"ちいかわらんど TOKYO Station","detail":"東京駅周辺の常設店。","region":"東京","badge":"常設店","button":"東京駅店の公式ページ","url":"https://chiikawa-info.jp/chiikawaland/tokyo/index.html","category":"shop"},{"id":"shinjuku","title":"ちいかわらんど 新宿店","detail":"東京・新宿の常設店。","region":"東京","badge":"常設店","button":"新宿店の公式ページ","url":"https://chiikawa-info.jp/chiikawaland/shinjuku/index.html","category":"shop"},{"id":"osaka","title":"ちいかわらんど 大阪梅田店","detail":"大阪・梅田の常設店。","region":"大阪","badge":"常設店","button":"大阪梅田店の公式ページ","url":"https://chiikawa-info.jp/chiikawaland/osaka/index.html","category":"shop"},{"id":"nagoya","title":"ちいかわらんど 名古屋パルコ店","detail":"愛知・名古屋の常設店。","region":"愛知","badge":"常設店","button":"名古屋店の公式ページ","url":"https://chiikawa-info.jp/chiikawaland/nagoya/index.html","category":"shop"},{"id":"market","title":"ちいかわマーケット","detail":"公式グッズショップ。価格・在庫は販売ページで確認。","region":"オンライン","badge":"公式ショップ","button":"ショップを開く","url":"https://chiikawamarket.jp/","category":"goods"},{"id":"plush-chiikawa","title":"ぬいぐるみS（ちいかわ）","detail":"公式の商品ページ。売り切れの場合は入荷のお知らせを確認。","region":"オンライン","badge":"商品ページ","button":"ぬいぐるみを見る","url":"https://chiikawamarket.jp/products/4589468435181","category":"goods"},{"id":"pen-hachiware","title":"ドクターグリップ 4+1（ハチワレ）","detail":"公式の商品ページ。価格・在庫は販売元で確認。","region":"オンライン","badge":"商品ページ","button":"文房具を見る","url":"https://chiikawamarket.jp/products/4901770775784","category":"goods"},{"id":"mug-chiikawa","title":"フェイスマグ（ちいかわ）","detail":"公式の商品ページ。売り切れの場合は入荷のお知らせを確認。","region":"オンライン","badge":"商品ページ","button":"マグカップを見る","url":"https://chiikawamarket.jp/products/4979274905471","category":"goods"},{"id":"restock","title":"再入荷商品","detail":"再入荷の一覧。個別商品の入荷通知は販売元で設定。","region":"オンライン","badge":"再入荷","button":"再入荷商品を見る","url":"https://chiikawamarket.jp/collections/restock","category":"goods"},{"id":"movie-goods","title":"映画ちいかわのグッズ","detail":"取扱店と販売情報を確認。","region":"全国","badge":"作品別","button":"取扱い情報を見る","url":"https://chiikawa-info.jp/p26/ck_movie/","category":"goods"},{"id":"new-goods","title":"新着商品","detail":"新しく掲載された商品を公式ショップで確認。","region":"オンライン","badge":"新着","button":"新着商品を見る","url":"https://chiikawamarket.jp/collections/newitems","category":"goods"},{"id":"preorder","title":"予約商品","detail":"発送予定や注文条件は各商品ページで確認。","region":"オンライン","badge":"予約","button":"予約商品を見る","url":"https://chiikawamarket.jp/collections/preorder","category":"goods"},{"id":"plush","title":"ぬいぐるみ・マスコット","detail":"公式ショップのカテゴリーから探す。","region":"オンライン","badge":"カテゴリー","button":"一覧を見る","url":"https://chiikawamarket.jp/collections/nuigurumi","category":"goods"},{"id":"fuji-tv","title":"フジテレビｅ!ショップ","detail":"アニメ関連グッズを販売元の一覧で確認。","region":"オンライン","badge":"販売サイト","button":"商品一覧を見る","url":"https://eshop.fujitv.co.jp/c/g_anime/B007088?sort=latest","category":"goods"},{"id":"sapporo-autumnfest","title":"さっぽろオータムフェスト","detail":"北海道各地の食を楽しむ秋の催し。","region":"北海道","venue":"札幌市・大通公園","startsOn":"2026-09-11","endsOn":"2026-10-03","period":"2026年9月11日〜10月3日","category":"event","eventType":"food","badge":"開催予定","button":"公式情報を見る","url":"https://www.sapporo.travel/autumnfest/"},{"id":"sapporo-kokusai-autumn","title":"札幌国際スキー場 秋祭り","detail":"紅葉ゴンドラと秋の味覚。","region":"北海道","venue":"札幌国際スキー場","startsOn":"2026-10-01","endsOn":"2026-10-20","period":"2026年10月1日〜10月20日","category":"event","eventType":"festival","badge":"開催予定","button":"公式情報を見る","url":"https://www.sapporo-kokusai.jp/autumn/"},{"id":"expo-futures-tokyo","title":"EXPO2025 Futures Tour 東京","detail":"大阪・関西万博の展示や作品を紹介する巡回イベント。","region":"東京","venue":"東京会場（詳細は公式ページ）","startsOn":"2026-10-10","endsOn":"2026-10-11","period":"2026年10月10日〜10月11日","category":"event","eventType":"exhibition","badge":"開催予定","button":"公式情報を見る","url":"https://www.expo2025.or.jp/officialblog/expo2025-f-tour1010/"},{"id":"hololive-tour-tokyo","title":"hololive Grand Reception 東京・前半","detail":"全国巡回展示会の東京会場。","region":"東京","venue":"TOKYO DREAM PARK 7階","startsOn":"2026-10-10","endsOn":"2026-10-28","period":"2026年10月10日〜10月28日","category":"event","eventType":"character","badge":"開催予定","button":"公式情報を見る","url":"https://hololivepro.com/news/20260821-01-298/"},{"id":"imo-fes-nagoya","title":"芋フェス！ IN 名古屋オアシス21","detail":"さつまいもグルメが集まる催し。","region":"愛知","venue":"オアシス21","startsOn":"2026-10-10","endsOn":"2026-10-12","period":"2026年10月10日〜10月12日","category":"event","eventType":"food","badge":"開催予定","button":"公式情報を見る","url":"https://www.sakaepark.co.jp/events/8010/"},{"id":"koishiwara-pottery","title":"小石原 秋の民陶むら祭","detail":"小石原焼・高取焼の窯元を巡る陶器市。","region":"福岡","venue":"福岡県東峰村・小石原地区","startsOn":"2026-10-10","endsOn":"2026-10-12","period":"2026年10月10日〜10月12日","category":"event","eventType":"craft","badge":"開催予定","button":"公式情報を見る","url":"https://www.crossroadfukuoka.jp/event/13730"},{"id":"hetalia-exhibition","title":"ヘタリア20周年原画展 WorldFesta","detail":"原画や記念グッズを楽しめる展覧会。","region":"東京","venue":"池袋・サンシャインシティ 展示ホールA","startsOn":"2026-10-17","endsOn":"2026-10-28","period":"2026年10月17日〜10月28日","category":"event","eventType":"exhibition","badge":"開催予定","button":"公式情報を見る","url":"https://www.hetalia-20thex.com/"},{"id":"shizuoka-marche","title":"静岡ハンドメイドマルシェ2026","detail":"全国の作家による作品や手作りフードが集まる催し。","region":"静岡","venue":"ツインメッセ静岡","startsOn":"2026-10-31","endsOn":"2026-11-01","period":"2026年10月31日〜11月1日","category":"event","eventType":"craft","badge":"開催予定","button":"公式情報を見る","url":"https://szo.handmade-marche.jp/"},{"id":"izumi-machiterasu","title":"いずみマチ・テラス","detail":"竹灯籠で街を彩る秋の催し。開催概要は県公式の一覧から確認。","region":"鹿児島","venue":"出水麓武家屋敷群地区","startsOn":"2026-10-31","endsOn":"2026-11-03","period":"2026年10月31日〜11月3日","category":"event","eventType":"festival","badge":"開催予定","button":"公式情報を見る","url":"https://www.kagoshima-kankou.com/event"},{"id":"creema","title":"Creema","detail":"作家によるハンドメイド作品を探せる販売サイト。","region":"オンライン","badge":"販売サイト","button":"Creemaで探す","url":"https://www.creema.jp/","category":"goods"},{"id":"minne","title":"minne","detail":"雑貨やクラフト作品を探せる販売サイト。","region":"オンライン","badge":"販売サイト","button":"minneで探す","url":"https://minne.com/","category":"goods"},{"id":"hololive-tour-tokyo-late","title":"hololive Grand Reception 東京・後半","detail":"全国巡回展示会の東京会場。前半と内容の一部が異なります。","region":"東京","venue":"TOKYO DREAM PARK 7階","startsOn":"2026-10-31","endsOn":"2026-11-23","period":"2026年10月31日〜11月23日","category":"event","eventType":"character","badge":"開催予定","button":"公式情報を見る","url":"https://hololivepro.com/news/20260821-01-298/"},{"id":"hetalia-exhibition-osaka","title":"ヘタリア20周年原画展 WorldFesta 大阪","detail":"原画や記念グッズを楽しめる展覧会。","region":"大阪","venue":"なんばパークスミュージアム","startsOn":"2026-11-07","endsOn":"2026-11-23","period":"2026年11月7日〜11月23日","category":"event","eventType":"exhibition","badge":"開催予定","button":"公式情報を見る","url":"https://www.hetalia-20thex.com/"},{"id":"rose-akirudai","title":"ローズフェスタ2026秋","detail":"秋留台公園のバラと、工作・雑貨販売などを楽しめます。","region":"東京","venue":"秋留台公園","startsOn":"2026-10-05","endsOn":"2026-10-12","period":"2026年10月5日〜12日","category":"event","eventType":"nature","badge":"開催予定","button":"公式情報を見る","url":"https://www.tokyo-park.or.jp/park/akirudai/news/2026/2026_3.html","keywords":"花 バラ 公園 体験 手作り"},{"id":"rikugien-autumn","title":"秋の六義園","detail":"庭園で秋の景色と日本文化に触れる催しです。","region":"東京","venue":"六義園","startsOn":"2026-10-17","endsOn":"2026-12-06","period":"2026年10月17日〜12月6日","category":"event","eventType":"nature","badge":"開催予定","button":"公式情報を見る","url":"https://www.tokyo-park.or.jp/event_search/rikugien_autumn.html","keywords":"紅葉 庭園 和文化 散歩"},{"id":"bay-walk-market-2026","title":"BAY WALK MARKET 2026","detail":"横浜の海辺を歩きながら、マーケットやグルメを楽しめます。","region":"神奈川","venue":"横浜みなとみらい新港地区","startsOn":"2026-10-09","endsOn":"2026-10-12","period":"2026年10月9日〜12日","category":"event","eventType":"market","badge":"開催予定","button":"公式情報を見る","url":"https://www.welcome.city.yokohama.jp/eventinfo/ev_detail.php?bid=yw12200","keywords":"ハロウィン 雑貨 ペット 海辺 マルシェ"},{"id":"enlightenment-osaka","title":"ENLIGHTENMENT JAPAN 大阪市立美術館","detail":"美術館の中央ホールを使った光と音の映像体験です。除外日があります。","region":"大阪","venue":"大阪市立美術館","startsOn":"2026-10-10","endsOn":"2026-11-29","period":"2026年10月10日〜11月29日（一部除外日）","category":"event","eventType":"exhibition","badge":"開催予定","button":"公式情報を見る","url":"https://osaka-info.jp/event/enlightenment-osaka/","keywords":"光 アート 映像 プロジェクションマッピング"},{"id":"yokohama-yorunoyo-2026","title":"ヨルノヨ2026","detail":"横浜の都心臨海部で開催する冬のイルミネーションです。","region":"神奈川","venue":"横浜都心臨海部","startsOn":"2026-12-04","endsOn":"2026-12-30","period":"2026年12月4日〜30日","category":"event","eventType":"festival","badge":"開催予定","button":"公式情報を見る","url":"https://www.welcome.city.yokohama.jp/eventinfo/ev_detail.php?bid=yw9092","keywords":"夜景 イルミネーション 冬 光"},{"id":"old-furukawa-rose","title":"旧古河庭園 秋のバラフェスティバル","detail":"秋のバラを楽しめる庭園の催しです。","region":"東京","venue":"旧古河庭園","startsOn":"2026-10-10","endsOn":"2026-11-06","period":"2026年10月10日〜11月6日","category":"event","eventType":"nature","badge":"開催予定","button":"公式情報を見る","url":"https://www.tokyo-park.or.jp/park/kyu-furukawa/news/2026/10_10_11_6.html","keywords":"花 バラ 庭園 散歩"}],"sources":[{"title":"北海道のイベント","region":"北海道","detail":"HOKKAIDO LOVE! 公式観光情報","url":"https://www.visit-hokkaido.jp/event/","types":["food","festival","nature","experience"],"keywords":"札幌 雪まつり グルメ 自然 冬"},{"title":"東北のイベント","region":"東北","detail":"旅東北のイベント検索","url":"https://www.tohokukanko.jp/festivals/","types":["festival","nature","food"],"keywords":"青森 岩手 秋田 宮城 山形 福島 祭り"},{"title":"東京の公園・庭園","region":"東京","detail":"都立公園のイベント検索","url":"https://www.tokyo-park.or.jp/event_search/","types":["nature","experience","festival"],"keywords":"花 バラ 紅葉 桜 公園"},{"title":"横浜のイベント","region":"神奈川","detail":"横浜市の観光イベント一覧","url":"https://www.welcome.city.yokohama.jp/eventinfo/","types":["market","food","exhibition","festival","character"],"keywords":"マーケット グルメ 花火 夜景"},{"title":"愛知のイベント","region":"愛知","detail":"愛知県観光協会のイベント検索","url":"https://www.aichinow.pref.aichi.jp/events","types":["festival","food","nature"],"keywords":"名古屋 祭り グルメ 花"},{"title":"京都の行事・催し","region":"京都","detail":"京都市公式のイベント情報","url":"https://ja.kyoto.travel/event/","types":["festival","exhibition","food","market"],"keywords":"伝統 工芸 紅葉 グルメ"},{"title":"大阪のイベント","region":"大阪","detail":"大阪公式観光情報のイベント一覧","url":"https://osaka-info.jp/event/","types":["festival","exhibition","food","experience"],"keywords":"展示 グルメ 体験 お祭り"},{"title":"福岡のイベント","region":"福岡","detail":"クロスロードふくおかのイベント検索","url":"https://www.crossroadfukuoka.jp/event","types":["craft","food","festival","nature"],"keywords":"陶器市 小石原 グルメ 花"},{"title":"沖縄のイベント","region":"沖縄","detail":"おきなわ物語のイベント検索","url":"https://www.okinawastory.jp/event/","types":["festival","nature","experience","food"],"keywords":"海 祭り 文化 体験"},{"title":"ハンドメイドの催し","region":"全国","detail":"Creemaのイベント・フェス情報","url":"https://www.creema.jp/event","types":["craft","market","experience"],"keywords":"雑貨 マルシェ 陶器市 ものづくり"}]}
"""#
        guard let data = text.data(using: .utf8),
              let feed = try? JSONDecoder().decode(GuideFeed.self, from: data),
              isValid(feed) else { return nil }
        return feed
    }()
    static var bundledItems: [GuideItem] { bundledFeed?.items ?? events + shops + goods }
    static var bundledSources: [GuideSource] { bundledFeed?.sources ?? [] }
    static let events: [GuideItem] = [
        .init(id: "skytree", category: .event,
              title: "ちいかわ☆星ふるスカイツリー®とひみつの島",
              detail: "東京スカイツリー／10月31日まで。展示や限定メニューなど。",
              region: "東京", badge: "開催中", button: "公式のイベント詳細",
              url: URL(string: "https://www.tokyo-skytree.jp/event/special/chiikawa/")!,
              period: "2026年7月10日〜10月31日", venue: "東京スカイツリー", endsOn: "2026-10-31"),
        .init(id: "park-autumn", category: .event,
              title: "ちいかわパーク 秋の限定企画",
              detail: "池袋。開催内容・営業時間・チケット情報を公式のお知らせで確認。",
              region: "東京", badge: "公式情報", button: "公式のお知らせ",
              url: URL(string: "https://chiikawapark-tokyo.jp/news/")!),
        .init(id: "cafe-osaka", category: .event,
              title: "映画ちいかわ コラボレーションカフェ",
              detail: "心斎橋PARCO／9月28日まで。予約や利用条件を会場ページで確認。",
              region: "大阪", badge: "9月28日まで", button: "会場の詳細",
              url: URL(string: "https://cafe.parco.jp/event/information/chiikawamovie_cafe_osaka?area=029441")!,
              period: "2026年7月24日〜9月28日", venue: "心斎橋PARCO", endsOn: "2026-09-28"),
        .init(id: "machida-popup", category: .event,
              title: "ちいかわ POP UP STORE 町田モディ",
              detail: "町田駅近くの期間限定店。入店方法は公式ページで確認。",
              region: "東京", badge: "期間限定", button: "町田の公式ページ",
              url: URL(string: "https://chiikawa-info.jp/p26/pus_matd/")!,
              period: "2026年10月9日〜11月1日", venue: "町田モディ 4F イベントスペース",
              startsOn: "2026-10-09", endsOn: "2026-11-01"),
        .init(id: "popup", category: .event,
              title: "POP UP STORE・催事",
              detail: "開催地と期間を公式の催事一覧から確認。",
              region: "全国", badge: "随時更新", button: "公式の催事一覧",
              url: URL(string: "https://chiikawa-info.jp/pus.html")!),
        .init(id: "tachikawa-magical", category: .event,
              title: "まじかるちいかわ POP UP STORE 立川",
              detail: "グランデュオ立川の期間限定店。入店方法は公式ページで確認。",
              region: "東京", badge: "期間限定", button: "立川の公式ページ",
              url: URL(string: "https://chiikawa-info.jp/p26/mg_tckw/index.html")!,
              period: "2026年9月30日〜11月8日", venue: "グランデュオ立川 2F",
              startsOn: "2026-09-30", endsOn: "2026-11-08"),
        .init(id: "sapporo-magical", category: .event,
              title: "まじかるちいかわ POP UP SHOP 札幌",
              detail: "期間限定店。入店方法は公式ページで確認。",
              region: "北海道", badge: "期間限定", button: "札幌の公式ページ",
              url: URL(string: "https://chiikawa-info.jp/magical_store/kd_spr/index.html")!,
              period: "2026年10月2日〜11月3日", venue: "キデイランド POP UP SHOP",
              startsOn: "2026-10-02", endsOn: "2026-11-03"),
        .init(id: "oita-land", category: .event,
              title: "ちいかわらんど POP UP SHOP 大分",
              detail: "期間限定店。入店方法は公式ページで確認。",
              region: "大分", badge: "期間限定", button: "大分の公式ページ",
              url: URL(string: "https://chiikawa-info.jp/chiikawaland/oita/index.html")!,
              period: "2026年9月11日〜10月12日", venue: "アミュプラザおおいた 2F",
              startsOn: "2026-09-11", endsOn: "2026-10-12")
    ]
    static let shops: [GuideItem] = [
        .init(id: "land", category: .shop, title: "ちいかわらんど",
              detail: "全国の常設店。営業時間・入店方法は各店舗の案内を確認。",
              region: "全国", badge: "常設店", button: "店舗一覧を見る",
              url: URL(string: "https://chiikawa-info.jp/ck_land.html")!),
        .init(id: "park", category: .shop, title: "ちいかわパーク",
              detail: "東京・池袋。チケット販売と利用案内。",
              region: "東京", badge: "施設", button: "チケット案内",
              url: URL(string: "https://chiikawapark-tokyo.jp/ticket")!),
        .init(id: "bakery-tokyo", category: .shop, title: "ちいかわベーカリー 表参道",
              detail: "オモカド3階。入店方法と営業時間を公式案内で確認。",
              region: "東京", badge: "飲食", button: "表参道店の案内",
              url: URL(string: "https://chiikawabakery.jp/information/")!),
        .init(id: "bakery-osaka", category: .shop, title: "ちいかわベーカリー OSAKA",
              detail: "KITTE大阪3階。入店方法と営業時間を公式案内で確認。",
              region: "大阪", badge: "飲食", button: "大阪店の案内",
              url: URL(string: "https://chiikawabakery.jp/information-osaka/")!),
        .init(id: "ramen-ikebukuro", category: .shop, title: "ちいかわラーメン 豚 池袋",
              detail: "池袋PARCO本館8階。予約・入店方法は公式案内で確認。",
              region: "東京", badge: "飲食", button: "池袋店の案内",
              url: URL(string: "https://cafe.parco.jp/event/chiikawaramenbuta_ikebukuro?area=029688")!),
        .init(id: "ramen-shibuya", category: .shop, title: "ちいかわラーメン 豚 渋谷",
              detail: "渋谷PARCO地下1階。予約・入店方法は公式案内で確認。",
              region: "東京", badge: "飲食", button: "渋谷店の案内",
              url: URL(string: "https://cafe.parco.jp/event/chiikawaramenbuta_shibuya?area=029979")!),
        .init(id: "mogumogu-kawagoe", category: .shop, title: "ちいかわもぐもぐ本舗 川越店",
              detail: "埼玉・川越。和をテーマにしたお菓子や雑貨のお店。",
              region: "埼玉", badge: "常設店", button: "川越店の案内",
              url: URL(string: "https://www.chiikawamogumogu.jp/stores/kawagoe/")!),
        .init(id: "mogumogu-fushimi", category: .shop, title: "ちいかわもぐもぐ本舗 京都伏見店",
              detail: "京都・伏見。和をテーマにしたお菓子や雑貨のお店。",
              region: "京都", badge: "常設店", button: "京都伏見店の案内",
              url: URL(string: "https://www.chiikawamogumogu.jp/stores/fushimi/")!),
        .init(id: "cafe", category: .shop, title: "コラボカフェ",
              detail: "開催中の会場や期間を確認。",
              region: "全国", badge: "飲食", button: "カフェ情報を見る",
              url: URL(string: "https://chiikawa-info.jp/cafe.html")!),
        .init(id: "harajuku", category: .shop, title: "ちいかわらんど 原宿店",
              detail: "東京・原宿。来店前に入店方法を確認。",
              region: "東京", badge: "常設店", button: "原宿店の公式ページ",
              url: URL(string: "https://chiikawa-info.jp/chiikawaland/harajuku/index.html")!),
        .init(id: "tokyo-station", category: .shop, title: "ちいかわらんど TOKYO Station",
              detail: "東京駅周辺の常設店。",
              region: "東京", badge: "常設店", button: "東京駅店の公式ページ",
              url: URL(string: "https://chiikawa-info.jp/chiikawaland/tokyo/index.html")!),
        .init(id: "shinjuku", category: .shop, title: "ちいかわらんど 新宿店",
              detail: "東京・新宿の常設店。",
              region: "東京", badge: "常設店", button: "新宿店の公式ページ",
              url: URL(string: "https://chiikawa-info.jp/chiikawaland/shinjuku/index.html")!),
        .init(id: "osaka", category: .shop, title: "ちいかわらんど 大阪梅田店",
              detail: "大阪・梅田の常設店。",
              region: "大阪", badge: "常設店", button: "大阪梅田店の公式ページ",
              url: URL(string: "https://chiikawa-info.jp/chiikawaland/osaka/index.html")!),
        .init(id: "nagoya", category: .shop, title: "ちいかわらんど 名古屋パルコ店",
              detail: "愛知・名古屋の常設店。",
              region: "愛知", badge: "常設店", button: "名古屋店の公式ページ",
              url: URL(string: "https://chiikawa-info.jp/chiikawaland/nagoya/index.html")!)
    ]
    static let goods: [GuideItem] = [
        .init(id: "market", category: .goods, title: "ちいかわマーケット",
              detail: "公式グッズショップ。価格・在庫は販売ページで確認。",
              region: "オンライン", badge: "公式ショップ", button: "ショップを開く",
              url: URL(string: "https://chiikawamarket.jp/")!),
        .init(id: "plush-chiikawa", category: .goods, title: "ぬいぐるみS（ちいかわ）",
              detail: "公式の商品ページ。売り切れの場合は入荷のお知らせを確認。",
              region: "オンライン", badge: "商品ページ", button: "ぬいぐるみを見る",
              url: URL(string: "https://chiikawamarket.jp/products/4589468435181")!),
        .init(id: "pen-hachiware", category: .goods, title: "ドクターグリップ 4+1（ハチワレ）",
              detail: "公式の商品ページ。価格・在庫は販売元で確認。",
              region: "オンライン", badge: "商品ページ", button: "文房具を見る",
              url: URL(string: "https://chiikawamarket.jp/products/4901770775784")!),
        .init(id: "mug-chiikawa", category: .goods, title: "フェイスマグ（ちいかわ）",
              detail: "公式の商品ページ。売り切れの場合は入荷のお知らせを確認。",
              region: "オンライン", badge: "商品ページ", button: "マグカップを見る",
              url: URL(string: "https://chiikawamarket.jp/products/4979274905471")!),
        .init(id: "restock", category: .goods, title: "再入荷商品",
              detail: "再入荷の一覧。個別商品の入荷通知は販売元で設定。",
              region: "オンライン", badge: "再入荷", button: "再入荷商品を見る",
              url: URL(string: "https://chiikawamarket.jp/collections/restock")!),
        .init(id: "movie-goods", category: .goods, title: "映画ちいかわのグッズ",
              detail: "取扱店と販売情報を確認。",
              region: "全国", badge: "作品別", button: "取扱い情報を見る",
              url: URL(string: "https://chiikawa-info.jp/p26/ck_movie/")!),
        .init(id: "new-goods", category: .goods, title: "新着商品",
              detail: "新しく掲載された商品を公式ショップで確認。",
              region: "オンライン", badge: "新着", button: "新着商品を見る",
              url: URL(string: "https://chiikawamarket.jp/collections/newitems")!),
        .init(id: "preorder", category: .goods, title: "予約商品",
              detail: "発送予定や注文条件は各商品ページで確認。",
              region: "オンライン", badge: "予約", button: "予約商品を見る",
              url: URL(string: "https://chiikawamarket.jp/collections/preorder")!),
        .init(id: "plush", category: .goods, title: "ぬいぐるみ・マスコット",
              detail: "公式ショップのカテゴリーから探す。",
              region: "オンライン", badge: "カテゴリー", button: "一覧を見る",
              url: URL(string: "https://chiikawamarket.jp/collections/nuigurumi")!),
        .init(id: "fuji-tv", category: .goods, title: "フジテレビｅ!ショップ",
              detail: "アニメ関連グッズを販売元の一覧で確認。",
              region: "オンライン", badge: "販売サイト", button: "商品一覧を見る",
              url: URL(string: "https://eshop.fujitv.co.jp/c/g_anime/B007088?sort=latest")!)
    ]
}

private enum GuideTab: String, CaseIterable {
    case events = "イベント"
    case shops = "お店・施設"
    case goods = "グッズ"
    var symbol: String {
        switch self {
        case .events: return "calendar"
        case .shops: return "mappin.and.ellipse"
        case .goods: return "bag"
        }
    }
}

private enum EventDateFilter: String, CaseIterable {
    case upcoming = "これから", today = "今日", weekend = "今週末", chosen = "日付を選ぶ"
}

private enum EventTypeFilter: String, CaseIterable {
    case all = "すべての種類", character = "キャラクター", craft = "雑貨・ハンドメイド"
    case exhibition = "展示・アート", food = "グルメ", festival = "季節のお祭り"
    case nature = "花・自然", market = "マーケット", experience = "体験"
    var dataValue: String {
        switch self {
        case .all: return "all"
        case .character: return "character"
        case .craft: return "craft"
        case .exhibition: return "exhibition"
        case .food: return "food"
        case .festival: return "festival"
        case .nature: return "nature"
        case .market: return "market"
        case .experience: return "experience"
        }
    }
}

struct GuideRootView: View {
    @State private var selection: GuideTab = .events
    @State private var region = "全国"
    @State private var dateFilter: EventDateFilter = .upcoming
    @State private var eventType: EventTypeFilter = .all
    @State private var chosenDate = Date()
    @State private var shopRegion = "全国"
    @State private var today = GuideData.localToday()
    @State private var savedOnly = false
    @State private var searchText = ""
    @State private var remoteItems: [GuideItem]? = nil
    @State private var remoteSources: [GuideSource]? = nil
    @State private var checkedOn = GuideData.checkedOn
    @State private var isRefreshing = false
    @State private var isOffline = false
    @AppStorage("savedGuideItemIDs") private var savedItemIDs = ""
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        page(for: selection)
        .tint(GuideStyle.yellow)
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                today = GuideData.localToday()
                Task { await refreshFeed() }
            }
        }
        .onChange(of: selection) { _ in searchText = "" }
        .task {
            await loadCachedFeed()
            await refreshFeed()
        }
    }

    private var availableItems: [GuideItem] {
        remoteItems ?? GuideData.bundledItems
    }
    private var availableSources: [GuideSource] {
        remoteSources ?? GuideData.bundledSources
    }

    private func regions(for category: GuideItem.Category) -> [String] {
        ["全国"] + Set(availableItems.filter { $0.category == category &&
            $0.region != "全国" && $0.region != "オンライン"
        }.map(\.region)).sorted()
    }

    @MainActor
    private func loadCachedFeed() {
        guard let data = UserDefaults.standard.data(forKey: "cachedGuideFeedV1"),
              let feed = try? JSONDecoder().decode(GuideFeed.self, from: data),
              GuideData.isValid(feed) else { return }
        remoteItems = feed.items
        remoteSources = feed.sources
        checkedOn = feed.checkedOn
    }

    @MainActor
    private func refreshFeed() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            var request = URLRequest(url: GuideData.feedURL)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 15
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  data.count <= 500_000 else { throw URLError(.badServerResponse) }
            let feed = try JSONDecoder().decode(GuideFeed.self, from: data)
            guard GuideData.isValid(feed) else { throw URLError(.cannotParseResponse) }
            remoteItems = feed.items
            remoteSources = feed.sources
            checkedOn = feed.checkedOn
            isOffline = false
            UserDefaults.standard.set(data, forKey: "cachedGuideFeedV1")
            if !regions(for: .event).contains(region) { region = "全国" }
            if !regions(for: .shop).contains(shopRegion) { shopRegion = "全国" }
        } catch {
            isOffline = true
        }
    }

    private var filteredEvents: [GuideItem] {
        let selected = GuideData.dateString(chosenDate)
        let weekend: (String, String) = {
            let calendar = Calendar(identifier: .gregorian)
            let weekday = calendar.component(.weekday, from: Date())
            let saturday = calendar.date(byAdding: .day, value: weekday == 1 ? -1 : (7 - weekday + 7) % 7, to: Date()) ?? Date()
            let sunday = calendar.date(byAdding: .day, value: 1, to: saturday) ?? saturday
            return (GuideData.dateString(saturday), GuideData.dateString(sunday))
        }()
        return availableItems.filter { item in
            guard item.category == .event, let start = item.startsOn, let end = item.endsOn,
                  end >= today else { return false }
            let inRegion = region == "全国" || item.region == region || item.region == "全国"
            let inType = eventType == .all || item.eventType == eventType.dataValue
            let inDate: Bool
            switch dateFilter {
            case .upcoming: inDate = true
            case .today: inDate = start <= today && end >= today
            case .weekend: inDate = start <= weekend.1 && end >= weekend.0
            case .chosen: inDate = start <= selected && end >= selected
            }
            return inRegion && inType && inDate
        }.sorted {
            max($0.startsOn ?? today, today) < max($1.startsOn ?? today, today)
        }
    }

    @ViewBuilder
    private func page(for tab: GuideTab) -> some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    header
                    HStack(spacing: 7) {
                        ForEach(GuideTab.allCases, id: \.self) { option in
                            Button {
                                selection = option
                            } label: {
                                Text(option.rawValue)
                                    .font(.subheadline.bold())
                                    .frame(maxWidth: .infinity, minHeight: 50)
                                    .foregroundStyle(selection == option ? GuideStyle.navy : .white)
                                    .background(selection == option ? GuideStyle.yellow : GuideStyle.panel,
                                                in: RoundedRectangle(cornerRadius: 11))
                                    .overlay(RoundedRectangle(cornerRadius: 11)
                                        .stroke(selection == option ? GuideStyle.yellow : GuideStyle.border))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if tab == .events {
                        NavigationLink {
                            OutingPlanView(items: availableItems, today: today)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "sparkles.rectangle.stack")
                                    .font(.title2)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("今日のプランを作る").font(.headline)
                                    Text("日付・気分・長さから組み立てる").font(.subheadline)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                            }
                            .foregroundStyle(GuideStyle.navy)
                            .padding(16)
                            .background(GuideStyle.yellow, in: RoundedRectangle(cornerRadius: 16))
                        }
                    }
                    searchPanel(for: tab)
                    let allItems = tab == .events ? filteredEvents :
                        (tab == .shops ? availableItems.filter {
                            $0.category == .shop &&
                            (shopRegion == "全国" || $0.region == shopRegion || $0.region == "全国")
                        } : availableItems.filter { $0.category == .goods })
                    let term = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                    let matchingItems = term.isEmpty ? allItems : allItems.filter {
                        let text = [$0.title, $0.detail, $0.region, $0.venue ?? "",
                                    $0.keywords ?? "", $0.eventType ?? ""].joined(separator: " ")
                        return term.split(whereSeparator: \.isWhitespace)
                            .allSatisfy { text.localizedStandardContains(String($0)) }
                    }
                    let savedIDs = Set(savedItemIDs.split(separator: ",").map(String.init))
                    let items = savedOnly ? matchingItems.filter { savedIDs.contains($0.id) } : matchingItems
                    HStack {
                        Text(tab == .events ? "これからのおでかけ" : tab.rawValue)
                            .font(.title3.bold())
                        Spacer()
                        Text("\(items.count)件").foregroundStyle(GuideStyle.muted)
                    }
                    .padding(.top, 2)
                    if items.isEmpty {
                        Text("この条件に合う掲載情報はありません。条件を変えるか、下の各地の案内から探してください。")
                            .foregroundStyle(GuideStyle.muted)
                            .padding(18)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(GuideStyle.panel, in: RoundedRectangle(cornerRadius: 14))
                    }
                    if tab == .goods {
                        let productPages = items.filter { $0.url.path.contains("/products/") }
                        let salesPages = items.filter { !$0.url.path.contains("/products/") }
                        if !productPages.isEmpty {
                            Text("商品ページ").font(.headline)
                            ForEach(productPages) { item in
                                GuideCard(item: item, today: today, savedItemIDs: $savedItemIDs)
                            }
                        }
                        if !salesPages.isEmpty {
                            Text("販売先から探す").font(.headline)
                            ForEach(salesPages) { item in
                                GuideCard(item: item, today: today, savedItemIDs: $savedItemIDs)
                            }
                        }
                    } else {
                        ForEach(items.indices, id: \.self) { index in
                            GuideCard(item: items[index], today: today, savedItemIDs: $savedItemIDs,
                                      showAutumn: tab == .events && index == 0)
                        }
                    }
                    if tab == .events { sourcePanel(term: term) }
                    Text("掲載情報：\(checkedOn)確認。日時・在庫・予約条件はリンク先でご確認ください。")
                        .font(.footnote).foregroundStyle(GuideStyle.muted)
                    if isOffline {
                        Text("通信できないため、端末内の案内を表示しています。")
                            .font(.footnote).foregroundStyle(GuideStyle.muted)
                    }
                    Text("掲載先の権利者・販売元による運営ではありません。")
                        .font(.footnote).foregroundStyle(GuideStyle.muted)
                    Link("プライバシーについて", destination: GuideData.privacyURL)
                        .font(.footnote)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 36)
            }
            .background(GuideStyle.background)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var header: some View {
        ZStack(alignment: .topTrailing) {
            GuideStyle.header
            SeasonArt(name: "spring")
                .frame(width: 158, height: 146)
                .offset(x: 9, y: -17)
            VStack(alignment: .leading, spacing: 12) {
                Text("おでかけガイド")
                    .font(.system(size: 29, weight: .bold))
                    .foregroundStyle(.white)
                Text("全国のイベントと個性的なお店を探そう")
                    .font(.subheadline)
                    .foregroundStyle(GuideStyle.muted)
                    .frame(maxWidth: 230, alignment: .leading)
                    .padding(.top, 20)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(17)
        }
        .frame(height: 145)
        .clipShape(RoundedRectangle(cornerRadius: 15))
    }

    private func searchPanel(for tab: GuideTab) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            VStack(alignment: .leading, spacing: 0) {
                Text("どんなおでかけを探しますか？")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                SeasonArt(name: "summer")
                    .frame(width: 180, height: 124)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            if tab == .events {
                Text("日付").font(.subheadline.bold()).foregroundStyle(GuideStyle.muted)
                HStack(spacing: 6) {
                    ForEach(EventDateFilter.allCases, id: \.self) { choice in
                        Button(choice.rawValue) { dateFilter = choice }
                            .font(.caption.bold())
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(dateFilter == choice ? GuideStyle.yellow : GuideStyle.header,
                                        in: RoundedRectangle(cornerRadius: 9))
                            .foregroundStyle(dateFilter == choice ? GuideStyle.navy : .white)
                            .overlay(RoundedRectangle(cornerRadius: 9).stroke(GuideStyle.border))
                    }
                }
                if dateFilter == .chosen {
                    DatePicker("探したい日", selection: $chosenDate, displayedComponents: .date)
                        .tint(GuideStyle.yellow)
                }
                HStack(spacing: 10) {
                    menuField("地域", selection: $region, values: regions(for: .event))
                    VStack(alignment: .leading, spacing: 7) {
                        Text("種類").font(.subheadline.bold()).foregroundStyle(GuideStyle.muted)
                        Picker("種類", selection: $eventType) {
                            ForEach(EventTypeFilter.allCases, id: \.self) { choice in
                                Text(choice.rawValue).tag(choice)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(GuideStyle.header, in: RoundedRectangle(cornerRadius: 9))
                        .foregroundStyle(.white)
                        .tint(.white)
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(GuideStyle.border))
                    }
                }
            } else if tab == .shops {
                menuField("地域", selection: $shopRegion, values: regions(for: .shop))
            }
            Text("キーワード").font(.subheadline.bold()).foregroundStyle(GuideStyle.muted)
            TextField("", text: $searchText,
                      prompt: Text("イベント名・場所・好きなもの")
                        .foregroundColor(GuideStyle.muted))
                .textFieldStyle(.plain)
                .foregroundStyle(.white)
                .tint(.white)
                .padding(12)
                .frame(minHeight: 48)
                .background(GuideStyle.header, in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(GuideStyle.border))
                .autocorrectionDisabled()
            HStack(spacing: 8) {
                Button("おでかけを探す →") {
                    searchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(GuideStyle.yellow, in: RoundedRectangle(cornerRadius: 9))
                .foregroundStyle(GuideStyle.navy)
                .fontWeight(.bold)
                Button(savedOnly ? "★ 保存中" : "☆ 保存済み") { savedOnly.toggle() }
                    .frame(minHeight: 48).padding(.horizontal, 10)
                    .background(GuideStyle.header, in: RoundedRectangle(cornerRadius: 9))
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(GuideStyle.border))
            }
            .buttonStyle(.plain)
            if tab == .events {
                HStack(spacing: 6) {
                    ForEach(["紅葉", "陶器", "マーケット"], id: \.self) { topic in
                        Button(topic) { searchText = topic; eventType = .all }
                            .font(.caption.bold())
                            .padding(.horizontal, 11).padding(.vertical, 8)
                            .background(GuideStyle.header, in: Capsule())
                            .overlay(Capsule().stroke(GuideStyle.border))
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(15)
        .background(GuideStyle.panel, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(GuideStyle.border))
    }

    private func menuField(_ title: String, selection: Binding<String>, values: [String]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.subheadline.bold()).foregroundStyle(GuideStyle.muted)
            Picker(title, selection: selection) {
                ForEach(values, id: \.self) { Text($0) }
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(GuideStyle.header, in: RoundedRectangle(cornerRadius: 9))
            .foregroundStyle(.white)
            .tint(.white)
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(GuideStyle.border))
        }
    }

    private func sourcePanel(term: String) -> some View {
        let matching = availableSources.filter { source in
            let regionMatches = region == "全国" || source.region == region || source.region == "全国"
            let typeMatches = eventType == .all || source.types.contains(eventType.dataValue)
            let text = [source.title, source.detail, source.region, source.keywords].joined(separator: " ")
            return regionMatches && typeMatches &&
                (term.isEmpty || text.localizedStandardContains(term))
        }
        let fallback = availableSources.filter {
            (region == "全国" || $0.region == region || $0.region == "全国") &&
            (eventType == .all || $0.types.contains(eventType.dataValue))
        }
        let display = matching.isEmpty ? fallback : matching
        return VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text("全国の開催情報をもっと探す").font(.headline)
                Spacer(minLength: 8)
                SeasonArt(name: "winter").frame(width: 90, height: 75)
            }
            Text("各地の観光・イベント案内から探せます。")
                .font(.subheadline).foregroundStyle(GuideStyle.muted)
            ForEach(display) { source in
                Link(destination: source.url) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(source.title + " ↗").font(.subheadline.bold())
                        Text(source.detail).font(.caption).foregroundStyle(GuideStyle.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(GuideStyle.header, in: RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(15)
        .background(GuideStyle.panel, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(GuideStyle.border))
    }
}

private enum PlanDay: String, CaseIterable {
    case today = "今日", weekend = "今週末", chosen = "日付を選ぶ"
}

private enum PlanMood: String, CaseIterable {
    case seasonal = "季節を感じたい"
    case cute = "かわいいものを見たい"
    case food = "食べ歩きたい"
    case calm = "静かに過ごしたい"

    func score(_ item: GuideItem) -> Int {
        switch self {
        case .seasonal:
            return ["festival", "food", "nature", "market"].contains(item.eventType ?? "") ? 3 : 0
        case .cute:
            return item.eventType == "character" ? 3 : 0
        case .food:
            return item.eventType == "food" ? 3 : 0
        case .calm:
            return ["exhibition", "craft", "nature"].contains(item.eventType ?? "") ? 3 : 0
        }
    }
}

private enum PlanLength: String, CaseIterable {
    case short = "2時間", half = "半日", full = "1日"
    var shopCount: Int {
        switch self {
        case .short: return 0
        case .half: return 1
        case .full: return 2
        }
    }
}

private struct OutingPlanView: View {
    let items: [GuideItem]
    let today: String
    @State private var day: PlanDay = .weekend
    @State private var chosenDate = Date()
    @State private var mood: PlanMood = .seasonal
    @State private var length: PlanLength = .half
    @State private var region = "全国"
    @State private var planIndex = 0
    @AppStorage("savedGuideItemIDs") private var savedItemIDs = ""

    private var dates: [String] {
        switch day {
        case .today: return [today]
        case .chosen: return [GuideData.dateString(chosenDate)]
        case .weekend:
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
            let now = Date()
            let weekday = calendar.component(.weekday, from: now)
            let daysUntilSaturday = weekday == 1 ? -1 : (7 - weekday + 7) % 7
            let saturday = calendar.date(byAdding: .day, value: daysUntilSaturday, to: now) ?? now
            let sunday = calendar.date(byAdding: .day, value: 1, to: saturday) ?? saturday
            return [GuideData.dateString(saturday), GuideData.dateString(sunday)]
        }
    }

    private var regions: [String] {
        ["全国"] + Set(items.filter { $0.category == .event && $0.region != "全国" }
            .map(\.region)).sorted()
    }

    private var events: [GuideItem] {
        items.filter { item in
            guard item.category == .event, let start = item.startsOn,
                  let end = item.endsOn, end >= today else { return false }
            return mood.score(item) > 0 &&
                (region == "全国" || item.region == region) &&
                dates.contains { start <= $0 && $0 <= end && $0 >= today }
        }.sorted { left, right in
            if mood.score(left) != mood.score(right) {
                return mood.score(left) > mood.score(right)
            }
            return (left.startsOn ?? "") < (right.startsOn ?? "")
        }
    }

    private var selectedEvent: GuideItem? {
        events.isEmpty ? nil : events[planIndex % events.count]
    }

    private var selectedDateLabel: String {
        guard let event = selectedEvent, let start = event.startsOn, let end = event.endsOn,
              let date = dates.first(where: { start <= $0 && $0 <= end }) else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        guard let parsed = formatter.date(from: date) else { return date }
        formatter.dateFormat = "M月d日（E）"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: parsed)
    }

    private var stops: [GuideItem] {
        guard let event = selectedEvent else { return [] }
        // 住所・営業時間が未収録のため、同じ都道府県の候補だけを組み合わせる。
        let shops = items.filter { $0.category == .shop && $0.region == event.region &&
            $0.region != "全国" && !$0.title.contains("一覧") && !$0.title.contains("コラボカフェ") }
        let rotated = shops.isEmpty ? [] : Array(shops.dropFirst(planIndex % shops.count)) +
            Array(shops.prefix(planIndex % shops.count))
        return [event] + Array(rotated.prefix(length.shopCount))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("四季から見つける、あなたの一日")
                        .font(.subheadline.bold())
                        .foregroundStyle(GuideStyle.yellow)
                    Text("今日のプランを作る")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                    Text("気分に合うイベントと、同じ都道府県の立ち寄り候補を組み合わせます。")
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(22)
                .background(GuideStyle.header, in: RoundedRectangle(cornerRadius: 24))

                VStack(alignment: .leading, spacing: 14) {
                    Picker("いつ行きますか", selection: $day) {
                        ForEach(PlanDay.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    if day == .chosen {
                        DatePicker("行きたい日", selection: $chosenDate, in: Date()..., displayedComponents: .date)
                    }
                    Picker("地域", selection: $region) {
                        ForEach(regions, id: \.self) { Text($0).tag($0) }
                    }
                    Picker("気分", selection: $mood) {
                        ForEach(PlanMood.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    Picker("おでかけの長さ", selection: $length) {
                        ForEach(PlanLength.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                .tint(GuideStyle.yellow)
                .padding(18)
                .background(GuideStyle.panel, in: RoundedRectangle(cornerRadius: 20))

                if selectedEvent != nil {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(selectedDateLabel)の\(length.rawValue)プラン")
                                .font(.title3.bold())
                            Text("\(planIndex % events.count + 1)／\(events.count)案目")
                                .font(.footnote)
                        }
                        Spacer()
                        Button("別のプラン") { planIndex += 1 }
                            .buttonStyle(.borderedProminent)
                            .tint(GuideStyle.yellow)
                    }
                    ForEach(stops.indices, id: \.self) { index in
                        let item = stops[index]
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(index + 1)　\(index == 0 ? "メインのイベント" : "同じ地域の立ち寄り候補")")
                                .font(.subheadline.bold())
                                .foregroundStyle(GuideStyle.yellow)
                            GuideCard(item: item, today: today, savedItemIDs: $savedItemIDs)
                        }
                    }
                    Text("同じ都道府県の候補です。移動順・所要時間・営業時間は未計算です。出発前に各公式ページで開催日、予約条件、営業時間を確認してください。")
                        .font(.footnote)
                        .foregroundStyle(GuideStyle.muted)
                } else {
                    Text("この条件で開催中のイベントはありません。日付・地域・気分を変えてみてください。")
                        .foregroundStyle(.white)
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(GuideStyle.panel, in: RoundedRectangle(cornerRadius: 20))
                }
            }
            .padding(18)
        }
        .background(GuideStyle.background)
        .navigationTitle("おでかけプラン")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .onChange(of: day) { _ in planIndex = 0 }
        .onChange(of: chosenDate) { _ in planIndex = 0 }
        .onChange(of: region) { _ in planIndex = 0 }
        .onChange(of: mood) { _ in planIndex = 0 }
        .onChange(of: length) { _ in planIndex = 0 }
    }
}

private struct SeasonArt: View {
    let name: String
    var body: some View {
        AsyncImage(url: URL(string: "https://chiikawa-odekake-guide.shu-tok39.chatgpt.site/assets/\(name).webp")) { phase in
            if let image = phase.image { image.resizable().scaledToFit() }
            else { Color.clear }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

private struct GuideCard: View {
    let item: GuideItem
    let today: String
    @Binding var savedItemIDs: String
    var showAutumn = false
    @Environment(\.openURL) private var openURL

    private var isSaved: Bool {
        savedItemIDs.split(separator: ",").contains(Substring(item.id))
    }

    private func toggleSaved() {
        var ids = Set(savedItemIDs.split(separator: ",").map(String.init))
        if ids.contains(item.id) { ids.remove(item.id) }
        else { ids.insert(item.id) }
        savedItemIDs = ids.sorted().joined(separator: ",")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(item.category == .event ?
                     (item.startsOn.map { $0 > today } == true ? "開催予定" : "開催中") : item.badge)
                    .foregroundStyle(GuideStyle.navy)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(GuideStyle.yellow, in: Capsule())
                Text(item.region).foregroundStyle(GuideStyle.muted)
                Spacer()
                Button(action: toggleSaved) {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                        .font(.title3)
                        .frame(width: 42, height: 42)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isSaved ? "保存を解除" : "後で見るために保存")
            }
            .font(.caption.bold())
            Text(item.title)
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.trailing, showAutumn ? 70 : 0)
            if let period = item.period {
                Label(period, systemImage: "calendar")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
            }
            if let venue = item.venue {
                Label(venue, systemImage: "mappin")
                    .font(.subheadline)
                    .foregroundStyle(GuideStyle.muted)
            }
            Text(item.detail).font(.subheadline).foregroundStyle(GuideStyle.muted)
            Button {
                openURL(item.url)
            } label: {
                HStack {
                    Text(item.button)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }
                .font(.subheadline.bold())
                .foregroundStyle(GuideStyle.navy)
                .padding(13)
                .background(GuideStyle.yellow, in: RoundedRectangle(cornerRadius: 12))
            }
            .accessibilityHint("外部の公式ページを開きます")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(17)
        .background {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 17).fill(GuideStyle.panel)
                if showAutumn {
                    SeasonArt(name: "autumn")
                        .frame(width: 116, height: 112)
                }
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 20)
            .stroke(GuideStyle.border, lineWidth: 1))
    }
}
