import SwiftUI

// iPhoneアプリの最初の土台。Xcodeでこのファイルを追加する場合は、
// 既存の @main App ファイルと重複しないよう、どちらか一方だけを使います。
@main
struct ChiikawaGuideApp: App {
    var body: some Scene {
        WindowGroup {
            GuideRootView()
                .preferredColorScheme(.light)
        }
    }
}

private enum GuideStyle {
    static let navy = Color(red: 0.15, green: 0.22, blue: 0.30)
    static let yellow = Color(red: 1.00, green: 0.86, blue: 0.48)
    static let background = Color(red: 0.985, green: 0.978, blue: 0.953)
    static let blush = Color(red: 1.00, green: 0.92, blue: 0.83)
    static let muted = Color(red: 0.36, green: 0.39, blue: 0.42)
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
}

private struct GuideFeed: Decodable {
    let schemaVersion: Int
    let checkedOn: String
    let items: [GuideItem]
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
        "www.kagoshima-kankou.com", "www.creema.jp", "minne.com"
    ]
    static func isValid(_ feed: GuideFeed) -> Bool {
        feed.schemaVersion == 2 && !feed.checkedOn.isEmpty &&
        (1...500).contains(feed.items.count) &&
        Set(feed.items.map(\.id)).count == feed.items.count &&
        feed.items.allSatisfy { item in
            item.url.scheme == "https" &&
            item.url.host.map { allowedHosts.contains($0) } == true &&
            !item.title.isEmpty && !item.button.isEmpty
        }
    }
    static func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        return formatter.string(from: date)
    }
    static func localToday() -> String { dateString(Date()) }
    static let bundledItems: [GuideItem] = {
        let text = #"""
{"schemaVersion":2,"checkedOn":"2026年9月28日","items":[{"id":"skytree","title":"ちいかわ☆星ふるスカイツリー®とひみつの島","detail":"東京スカイツリー／10月31日まで。展示や限定メニューなど。","region":"東京","badge":"開催中","button":"公式のイベント詳細","url":"https://www.tokyo-skytree.jp/event/special/chiikawa/","period":"2026年7月10日〜10月31日","venue":"東京スカイツリー","endsOn":"2026-10-31","category":"event","eventType":"character","startsOn":"2026-07-10"},{"id":"cafe-osaka","title":"映画ちいかわ コラボレーションカフェ","detail":"心斎橋PARCO／9月28日まで。予約や利用条件を会場ページで確認。","region":"大阪","badge":"9月28日まで","button":"会場の詳細","url":"https://cafe.parco.jp/event/information/chiikawamovie_cafe_osaka?area=029441","period":"2026年7月24日〜9月28日","venue":"心斎橋PARCO","endsOn":"2026-09-28","category":"event","eventType":"character","startsOn":"2026-07-24"},{"id":"machida-popup","title":"ちいかわ POP UP STORE 町田モディ","detail":"町田駅近くの期間限定店。入店方法は公式ページで確認。","region":"東京","badge":"期間限定","button":"町田の公式ページ","url":"https://chiikawa-info.jp/p26/pus_matd/","period":"2026年10月9日〜11月1日","venue":"町田モディ 4F イベントスペース","startsOn":"2026-10-09","endsOn":"2026-11-01","category":"event","eventType":"character"},{"id":"popup","title":"期間限定ショップの催事一覧","detail":"開催地と期間は公式の催事一覧で確認できます。","region":"全国","badge":"随時更新","button":"公式の催事一覧","url":"https://chiikawa-info.jp/pus.html","category":"shop"},{"id":"tachikawa-magical","title":"まじかるちいかわ POP UP STORE 立川","detail":"グランデュオ立川の期間限定店。入店方法は公式ページで確認。","region":"東京","badge":"期間限定","button":"立川の公式ページ","url":"https://chiikawa-info.jp/p26/mg_tckw/index.html","period":"2026年9月30日〜11月8日","venue":"グランデュオ立川 2F","startsOn":"2026-09-30","endsOn":"2026-11-08","category":"event","eventType":"character"},{"id":"sapporo-magical","title":"まじかるちいかわ POP UP SHOP 札幌","detail":"期間限定店。入店方法は公式ページで確認。","region":"北海道","badge":"期間限定","button":"札幌の公式ページ","url":"https://chiikawa-info.jp/magical_store/kd_spr/index.html","period":"2026年10月2日〜11月3日","venue":"キデイランド POP UP SHOP","startsOn":"2026-10-02","endsOn":"2026-11-03","category":"event","eventType":"character"},{"id":"oita-land","title":"ちいかわらんど POP UP SHOP 大分","detail":"期間限定店。入店方法は公式ページで確認。","region":"大分","badge":"期間限定","button":"大分の公式ページ","url":"https://chiikawa-info.jp/chiikawaland/oita/index.html","period":"2026年9月11日〜10月12日","venue":"アミュプラザおおいた 2F","startsOn":"2026-09-11","endsOn":"2026-10-12","category":"event","eventType":"character"},{"id":"land","title":"ちいかわらんど","detail":"全国の常設店。営業時間・入店方法は各店舗の案内を確認。","region":"全国","badge":"常設店","button":"店舗一覧を見る","url":"https://chiikawa-info.jp/ck_land.html","category":"shop"},{"id":"park","title":"ちいかわパーク","detail":"東京・池袋。チケット販売と利用案内。","region":"東京","badge":"施設","button":"チケット案内","url":"https://chiikawapark-tokyo.jp/ticket","category":"shop"},{"id":"bakery-tokyo","title":"ちいかわベーカリー 表参道","detail":"オモカド3階。入店方法と営業時間を公式案内で確認。","region":"東京","badge":"飲食","button":"表参道店の案内","url":"https://chiikawabakery.jp/information/","category":"shop"},{"id":"bakery-osaka","title":"ちいかわベーカリー OSAKA","detail":"KITTE大阪3階。入店方法と営業時間を公式案内で確認。","region":"大阪","badge":"飲食","button":"大阪店の案内","url":"https://chiikawabakery.jp/information-osaka/","category":"shop"},{"id":"ramen-ikebukuro","title":"ちいかわラーメン 豚 池袋","detail":"池袋PARCO本館8階。予約・入店方法は公式案内で確認。","region":"東京","badge":"飲食","button":"池袋店の案内","url":"https://cafe.parco.jp/event/chiikawaramenbuta_ikebukuro?area=029688","category":"shop"},{"id":"ramen-shibuya","title":"ちいかわラーメン 豚 渋谷","detail":"渋谷PARCO地下1階。予約・入店方法は公式案内で確認。","region":"東京","badge":"飲食","button":"渋谷店の案内","url":"https://cafe.parco.jp/event/chiikawaramenbuta_shibuya?area=029979","category":"shop"},{"id":"mogumogu-kawagoe","title":"ちいかわもぐもぐ本舗 川越店","detail":"埼玉・川越。和をテーマにしたお菓子や雑貨のお店。","region":"埼玉","badge":"常設店","button":"川越店の案内","url":"https://www.chiikawamogumogu.jp/stores/kawagoe/","category":"shop"},{"id":"mogumogu-fushimi","title":"ちいかわもぐもぐ本舗 京都伏見店","detail":"京都・伏見。和をテーマにしたお菓子や雑貨のお店。","region":"京都","badge":"常設店","button":"京都伏見店の案内","url":"https://www.chiikawamogumogu.jp/stores/fushimi/","category":"shop"},{"id":"cafe","title":"コラボカフェ","detail":"開催中の会場や期間を確認。","region":"全国","badge":"飲食","button":"カフェ情報を見る","url":"https://chiikawa-info.jp/cafe.html","category":"shop"},{"id":"harajuku","title":"ちいかわらんど 原宿店","detail":"東京・原宿。来店前に入店方法を確認。","region":"東京","badge":"常設店","button":"原宿店の公式ページ","url":"https://chiikawa-info.jp/chiikawaland/harajuku/index.html","category":"shop"},{"id":"tokyo-station","title":"ちいかわらんど TOKYO Station","detail":"東京駅周辺の常設店。","region":"東京","badge":"常設店","button":"東京駅店の公式ページ","url":"https://chiikawa-info.jp/chiikawaland/tokyo/index.html","category":"shop"},{"id":"shinjuku","title":"ちいかわらんど 新宿店","detail":"東京・新宿の常設店。","region":"東京","badge":"常設店","button":"新宿店の公式ページ","url":"https://chiikawa-info.jp/chiikawaland/shinjuku/index.html","category":"shop"},{"id":"osaka","title":"ちいかわらんど 大阪梅田店","detail":"大阪・梅田の常設店。","region":"大阪","badge":"常設店","button":"大阪梅田店の公式ページ","url":"https://chiikawa-info.jp/chiikawaland/osaka/index.html","category":"shop"},{"id":"nagoya","title":"ちいかわらんど 名古屋パルコ店","detail":"愛知・名古屋の常設店。","region":"愛知","badge":"常設店","button":"名古屋店の公式ページ","url":"https://chiikawa-info.jp/chiikawaland/nagoya/index.html","category":"shop"},{"id":"market","title":"ちいかわマーケット","detail":"公式グッズショップ。価格・在庫は販売ページで確認。","region":"オンライン","badge":"公式ショップ","button":"ショップを開く","url":"https://chiikawamarket.jp/","category":"goods"},{"id":"plush-chiikawa","title":"ぬいぐるみS（ちいかわ）","detail":"公式の商品ページ。売り切れの場合は入荷のお知らせを確認。","region":"オンライン","badge":"商品ページ","button":"ぬいぐるみを見る","url":"https://chiikawamarket.jp/products/4589468435181","category":"goods"},{"id":"pen-hachiware","title":"ドクターグリップ 4+1（ハチワレ）","detail":"公式の商品ページ。価格・在庫は販売元で確認。","region":"オンライン","badge":"商品ページ","button":"文房具を見る","url":"https://chiikawamarket.jp/products/4901770775784","category":"goods"},{"id":"mug-chiikawa","title":"フェイスマグ（ちいかわ）","detail":"公式の商品ページ。売り切れの場合は入荷のお知らせを確認。","region":"オンライン","badge":"商品ページ","button":"マグカップを見る","url":"https://chiikawamarket.jp/products/4979274905471","category":"goods"},{"id":"restock","title":"再入荷商品","detail":"再入荷の一覧。個別商品の入荷通知は販売元で設定。","region":"オンライン","badge":"再入荷","button":"再入荷商品を見る","url":"https://chiikawamarket.jp/collections/restock","category":"goods"},{"id":"movie-goods","title":"映画ちいかわのグッズ","detail":"取扱店と販売情報を確認。","region":"全国","badge":"作品別","button":"取扱い情報を見る","url":"https://chiikawa-info.jp/p26/ck_movie/","category":"goods"},{"id":"new-goods","title":"新着商品","detail":"新しく掲載された商品を公式ショップで確認。","region":"オンライン","badge":"新着","button":"新着商品を見る","url":"https://chiikawamarket.jp/collections/newitems","category":"goods"},{"id":"preorder","title":"予約商品","detail":"発送予定や注文条件は各商品ページで確認。","region":"オンライン","badge":"予約","button":"予約商品を見る","url":"https://chiikawamarket.jp/collections/preorder","category":"goods"},{"id":"plush","title":"ぬいぐるみ・マスコット","detail":"公式ショップのカテゴリーから探す。","region":"オンライン","badge":"カテゴリー","button":"一覧を見る","url":"https://chiikawamarket.jp/collections/nuigurumi","category":"goods"},{"id":"fuji-tv","title":"フジテレビｅ!ショップ","detail":"アニメ関連グッズを販売元の一覧で確認。","region":"オンライン","badge":"販売サイト","button":"商品一覧を見る","url":"https://eshop.fujitv.co.jp/c/g_anime/B007088?sort=latest","category":"goods"},{"id":"sapporo-autumnfest","title":"さっぽろオータムフェスト","detail":"北海道各地の食を楽しむ秋の催し。","region":"北海道","venue":"札幌市・大通公園","startsOn":"2026-09-11","endsOn":"2026-10-03","period":"2026年9月11日〜10月3日","category":"event","eventType":"food","badge":"開催予定","button":"公式情報を見る","url":"https://www.sapporo.travel/autumnfest/"},{"id":"sapporo-kokusai-autumn","title":"札幌国際スキー場 秋祭り","detail":"紅葉ゴンドラと秋の味覚。","region":"北海道","venue":"札幌国際スキー場","startsOn":"2026-10-01","endsOn":"2026-10-20","period":"2026年10月1日〜10月20日","category":"event","eventType":"festival","badge":"開催予定","button":"公式情報を見る","url":"https://www.sapporo-kokusai.jp/autumn/"},{"id":"expo-futures-tokyo","title":"EXPO2025 Futures Tour 東京","detail":"大阪・関西万博の展示や作品を紹介する巡回イベント。","region":"東京","venue":"東京会場（詳細は公式ページ）","startsOn":"2026-10-10","endsOn":"2026-10-11","period":"2026年10月10日〜10月11日","category":"event","eventType":"exhibition","badge":"開催予定","button":"公式情報を見る","url":"https://www.expo2025.or.jp/officialblog/expo2025-f-tour1010/"},{"id":"hololive-tour-tokyo","title":"hololive Grand Reception 東京・前半","detail":"全国巡回展示会の東京会場。","region":"東京","venue":"TOKYO DREAM PARK 7階","startsOn":"2026-10-10","endsOn":"2026-10-28","period":"2026年10月10日〜10月28日","category":"event","eventType":"character","badge":"開催予定","button":"公式情報を見る","url":"https://hololivepro.com/news/20260821-01-298/"},{"id":"imo-fes-nagoya","title":"芋フェス！ IN 名古屋オアシス21","detail":"さつまいもグルメが集まる催し。","region":"愛知","venue":"オアシス21","startsOn":"2026-10-10","endsOn":"2026-10-12","period":"2026年10月10日〜10月12日","category":"event","eventType":"food","badge":"開催予定","button":"公式情報を見る","url":"https://www.sakaepark.co.jp/events/8010/"},{"id":"koishiwara-pottery","title":"小石原 秋の民陶むら祭","detail":"小石原焼・高取焼の窯元を巡る陶器市。","region":"福岡","venue":"福岡県東峰村・小石原地区","startsOn":"2026-10-10","endsOn":"2026-10-12","period":"2026年10月10日〜10月12日","category":"event","eventType":"craft","badge":"開催予定","button":"公式情報を見る","url":"https://www.crossroadfukuoka.jp/event/13730"},{"id":"hetalia-exhibition","title":"ヘタリア20周年原画展 WorldFesta","detail":"原画や記念グッズを楽しめる展覧会。","region":"東京","venue":"池袋・サンシャインシティ 展示ホールA","startsOn":"2026-10-17","endsOn":"2026-10-28","period":"2026年10月17日〜10月28日","category":"event","eventType":"exhibition","badge":"開催予定","button":"公式情報を見る","url":"https://www.hetalia-20thex.com/"},{"id":"shizuoka-marche","title":"静岡ハンドメイドマルシェ2026","detail":"全国の作家による作品や手作りフードが集まる催し。","region":"静岡","venue":"ツインメッセ静岡","startsOn":"2026-10-31","endsOn":"2026-11-01","period":"2026年10月31日〜11月1日","category":"event","eventType":"craft","badge":"開催予定","button":"公式情報を見る","url":"https://szo.handmade-marche.jp/"},{"id":"izumi-machiterasu","title":"いずみマチ・テラス","detail":"竹灯籠で街を彩る秋の催し。開催概要は県公式の一覧から確認。","region":"鹿児島","venue":"出水麓武家屋敷群地区","startsOn":"2026-10-31","endsOn":"2026-11-03","period":"2026年10月31日〜11月3日","category":"event","eventType":"festival","badge":"開催予定","button":"公式情報を見る","url":"https://www.kagoshima-kankou.com/event"},{"id":"creema","title":"Creema","detail":"作家によるハンドメイド作品を探せる販売サイト。","region":"オンライン","badge":"販売サイト","button":"Creemaで探す","url":"https://www.creema.jp/","category":"goods"},{"id":"minne","title":"minne","detail":"雑貨やクラフト作品を探せる販売サイト。","region":"オンライン","badge":"販売サイト","button":"minneで探す","url":"https://minne.com/","category":"goods"},{"id":"hololive-tour-tokyo-late","title":"hololive Grand Reception 東京・後半","detail":"全国巡回展示会の東京会場。前半と内容の一部が異なります。","region":"東京","venue":"TOKYO DREAM PARK 7階","startsOn":"2026-10-31","endsOn":"2026-11-23","period":"2026年10月31日〜11月23日","category":"event","eventType":"character","badge":"開催予定","button":"公式情報を見る","url":"https://hololivepro.com/news/20260821-01-298/"},{"id":"hetalia-exhibition-osaka","title":"ヘタリア20周年原画展 WorldFesta 大阪","detail":"原画や記念グッズを楽しめる展覧会。","region":"大阪","venue":"なんばパークスミュージアム","startsOn":"2026-11-07","endsOn":"2026-11-23","period":"2026年11月7日〜11月23日","category":"event","eventType":"exhibition","badge":"開催予定","button":"公式情報を見る","url":"https://www.hetalia-20thex.com/"}]}
"""#
        guard let data = text.data(using: .utf8),
              let feed = try? JSONDecoder().decode(GuideFeed.self, from: data),
              isValid(feed) else { return events + shops + goods }
        return feed.items
    }()
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
    case exhibition = "展示", food = "グルメ", festival = "季節のお祭り"
    var dataValue: String {
        switch self {
        case .all: return "all"
        case .character: return "character"
        case .craft: return "craft"
        case .exhibition: return "exhibition"
        case .food: return "food"
        case .festival: return "festival"
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
    @State private var checkedOn = GuideData.checkedOn
    @State private var isRefreshing = false
    @State private var isOffline = false
    @AppStorage("savedGuideItemIDs") private var savedItemIDs = ""
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView(selection: $selection) {
            page(for: .events)
                .tabItem { Label(GuideTab.events.rawValue, systemImage: GuideTab.events.symbol) }
                .tag(GuideTab.events)
            page(for: .shops)
                .tabItem { Label(GuideTab.shops.rawValue, systemImage: GuideTab.shops.symbol) }
                .tag(GuideTab.shops)
            page(for: .goods)
                .tabItem { Label(GuideTab.goods.rawValue, systemImage: GuideTab.goods.symbol) }
                .tag(GuideTab.goods)
        }
        .tint(GuideStyle.navy)
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
            let saturday = calendar.date(byAdding: .day, value: (7 - weekday + 7) % 7, to: Date()) ?? Date()
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
                    header(for: tab)
                    if tab == .events {
                        Picker("地域", selection: $region) {
                            ForEach(regions(for: .event), id: \.self) { Text($0) }
                        }
                        .pickerStyle(.menu)
                        .accessibilityLabel("イベントの地域")
                        Picker("日付", selection: $dateFilter) {
                            ForEach(EventDateFilter.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.menu)
                        if dateFilter == .chosen {
                            DatePicker("探したい日", selection: $chosenDate, displayedComponents: .date)
                        }
                        Picker("イベントの種類", selection: $eventType) {
                            ForEach(EventTypeFilter.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.menu)
                    }
                    if tab == .shops {
                        Picker("地域", selection: $shopRegion) {
                            ForEach(regions(for: .shop), id: \.self) { Text($0) }
                        }
                        .pickerStyle(.menu)
                        .accessibilityLabel("店舗の地域")
                    }
                    let allItems = tab == .events ? filteredEvents :
                        (tab == .shops ? availableItems.filter {
                            $0.category == .shop &&
                            (shopRegion == "全国" || $0.region == shopRegion || $0.region == "全国")
                        } : availableItems.filter { $0.category == .goods })
                    let term = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                    let matchingItems = term.isEmpty ? allItems : allItems.filter {
                        $0.title.localizedStandardContains(term) ||
                        $0.detail.localizedStandardContains(term) ||
                        $0.region.localizedStandardContains(term)
                    }
                    let savedIDs = Set(savedItemIDs.split(separator: ",").map(String.init))
                    let items = savedOnly ? matchingItems.filter { savedIDs.contains($0.id) } : matchingItems
                    if items.isEmpty {
                        Text(!term.isEmpty ? "一致する案内はありません。別の言葉でお試しください。" :
                             savedOnly ? "この画面で保存した項目はありません。" :
                             "この地域の掲載情報はまだありません。")
                            .foregroundStyle(.secondary)
                            .padding()
                    }
                    if tab == .goods {
                        let productPages = items.filter { $0.url.path.contains("/products/") }
                        let salesPages = items.filter { !$0.url.path.contains("/products/") }
                        if !productPages.isEmpty {
                            Text("商品ページの例")
                                .font(.headline)
                                .foregroundStyle(GuideStyle.navy)
                                .padding(.top, 6)
                            Text("売り切れの場合もあります。在庫はリンク先で確認してください。")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            ForEach(productPages) { item in
                                GuideCard(item: item, today: today, savedItemIDs: $savedItemIDs)
                            }
                        }
                        if !salesPages.isEmpty {
                            Text("販売サイト・一覧から探す")
                                .font(.headline)
                                .foregroundStyle(GuideStyle.navy)
                                .padding(.top, 6)
                            ForEach(salesPages) { item in
                                GuideCard(item: item, today: today, savedItemIDs: $savedItemIDs)
                            }
                        }
                    } else {
                        ForEach(items) { item in
                            GuideCard(item: item, today: today, savedItemIDs: $savedItemIDs)
                        }
                    }
                    Text("掲載情報：\(checkedOn)確認。日時・在庫・予約条件はリンク先でご確認ください。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                    if isOffline {
                        Text("通信できないため、端末内の案内を表示しています。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Text("掲載先の権利者・販売元による運営ではありません。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Link("プライバシーについて", destination: GuideData.privacyURL)
                        .font(.footnote)
                }
                .padding(18)
            }
            .background(GuideStyle.background)
            .navigationTitle("おでかけガイド")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "名前・地域で探す")
            .toolbar {
                Button {
                    Task { await refreshFeed() }
                } label: {
                    Label("最新情報を確認", systemImage: "arrow.clockwise")
                }
                .disabled(isRefreshing)
                Button {
                    savedOnly.toggle()
                } label: {
                    Label(savedOnly ? "すべて表示" : "保存した項目だけ表示",
                          systemImage: savedOnly ? "bookmark.fill" : "bookmark")
                }
            }
        }
    }

    private func header(for tab: GuideTab) -> some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 9) {
                Text("おでかけを、もっと楽しく")
                    .font(.caption.bold())
                    .foregroundStyle(GuideStyle.muted)
                Text(tab.rawValue)
                    .font(.title2.bold())
                    .foregroundStyle(GuideStyle.navy)
                Text(tab == .events ? "日付・地域・種類から探す" :
                        tab == .shops ? "行ってみたいお店や施設" : "個性的な商品を探す")
                    .font(.subheadline)
                    .foregroundStyle(GuideStyle.muted)
            }
            Spacer(minLength: 0)
            Image(systemName: tab.symbol)
                .font(.title2.weight(.semibold))
                .foregroundStyle(GuideStyle.navy)
                .frame(width: 54, height: 54)
                .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 18))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(GuideStyle.blush, in: RoundedRectangle(cornerRadius: 22))
    }
}

private struct GuideCard: View {
    let item: GuideItem
    let today: String
    @Binding var savedItemIDs: String
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
                .foregroundStyle(GuideStyle.navy)
            if let period = item.period {
                Label(period, systemImage: "calendar")
                    .font(.subheadline.bold())
                    .foregroundStyle(GuideStyle.navy)
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
                .background(GuideStyle.background, in: RoundedRectangle(cornerRadius: 12))
            }
            .accessibilityHint("外部の公式ページを開きます")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(17)
        .background(.white, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20)
            .stroke(GuideStyle.navy.opacity(0.08), lineWidth: 1))
    }
}
