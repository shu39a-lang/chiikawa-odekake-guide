import SwiftUI
import Foundation
import MapKit
import CoreLocation

private struct Venue: Decodable {
    let name: String
    let detail: String
    let url: String
    let cuisine: String?

    init(from decoder: Decoder) throws {
        var values = try decoder.unkeyedContainer()
        name = try values.decode(String.self)
        detail = try values.decode(String.self)
        url = try values.decode(String.self)
        cuisine = values.isAtEnd ? nil : try values.decode(String.self)
    }
}

private struct Stop: Decodable {
    let type: String
    let duration: Int
    let choices: [Venue]
}

private struct DayRoute: Decodable, Identifiable {
    let id: String
    let prefecture: String?
    let label: String
    let title: String
    let description: String
    let area: String
    let gap: Int
    let stops: [Stop]
}

private struct GuideData: Decodable {
    let routes: [DayRoute]
    let notes: [String: String]
    let visitMinutes: [String: Int]

    static let bundled: GuideData = {
        let json = #"""
{"routes":[{"id":"asakusa","label":"Tokyo · Asakusa to Skytree","title":"Old Tokyo, new skyline","description":"Temples, local food and a view across the city.","area":"Asakusa & Oshiage","gap":18,"stops":[{"type":"sight","duration":65,"choices":[["Sensoji Temple","Tokyo’s best-known historic temple","https://www.senso-ji.jp/"],["Asakusa Culture Tourist Information Center","Start with a view and local travel advice","https://www.gotokyo.org/en/story/walks-and-tours/asakusa/"]]},{"type":"walk","duration":55,"choices":[["Nakamise Shopping Street","Snacks and traditional souvenirs","https://www.gotokyo.org/en/spot/73/"],["Sumida Park","Riverside views on the way east","https://www.gotokyo.org/en/destinations/eastern-tokyo/asakusa/index.html"]]},{"type":"food","duration":65,"choices":[["Ramen Yoroiya","Japanese-style ramen near Sensoji","https://yoroiya.jp/","ramen"],["Sushizanmai Asakusa Kaminarimon","Sushi near Kaminarimon Gate","https://www.kiyomura.co.jp/store/detail/33","sushi"],["Asakusa Imahan","Sukiyaki and Japanese dining","https://www.asakusaimahan.co.jp/en/kokusai","japanese"]]},{"type":"sight","duration":75,"choices":[["Tokyo Skytree","Observation decks and a panorama","https://www.tokyo-skytree.jp/en/ticket/"],["Sumida Aquarium","Aquatic life inside Skytree Town","https://www.sumida-aquarium.com/en/"],["Postal Museum Japan","Discover the postal museum in Skytree Town","https://www.gotokyo.org/en/spot/903/index.html"]]},{"type":"break","duration":55,"choices":[["Tokyo Solamachi","Shops and a relaxed finish","https://www.tokyo-solamachi.jp/en/"],["Sumida Aquarium","An indoor finale beside Skytree","https://www.sumida-aquarium.com/en/"],["Tokyo Mizumachi","Riverside shops between Asakusa and Skytree","https://www.gotokyo.org/en/spot/1795/index.html"]]}]},{"id":"ueno","label":"Tokyo · Ueno culture and food","title":"Art, park and a good lunch","description":"A compact culture day with a choice of ramen, sushi or classic dining.","area":"Ueno","gap":15,"stops":[{"type":"sight","duration":75,"choices":[["Tokyo National Museum","Japanese and Asian art and archaeology","https://www.tnm.jp/?lang=en"],["National Museum of Nature and Science","Science, nature and Japanese discoveries","https://www.kahaku.go.jp/english/"],["National Museum of Western Art","Art collections in Ueno Park","https://www.gotokyo.org/en/spot/120/"]]},{"type":"walk","duration":50,"choices":[["Ueno Park","Gardens and cultural landmarks","https://www.gotokyo.org/en/spot/482/"],["Ameyoko Shopping Street","A lively market-style street","https://www.gotokyo.org/en/spot/71/"]]},{"type":"food","duration":65,"choices":[["Inshotei","Japanese seasonal dining in Ueno Park","https://www.innsyoutei.jp/en/","japanese"],["Sushizanmai Ueno","Sushi around Ueno Station","https://www.kiyomura.co.jp/store/detail/20","sushi"],["IPPUDO Ueno-hirokoji","Ramen near the shopping streets","https://stores.ippudo.com/en/1826","ramen"]]},{"type":"sight","duration":75,"choices":[["National Museum of Nature and Science","Explore the permanent galleries","https://www.kahaku.go.jp/english/"],["Tokyo National Museum","Choose a gallery or exhibition","https://www.tnm.jp/?lang=en"],["Tokyo Metropolitan Art Museum","Explore an exhibition in Ueno Park","https://www.gotokyo.org/en/spot/1746/index.html"]]},{"type":"break","duration":55,"choices":[["Shinobazu Pond","A relaxed walk by the water","https://www.gotokyo.org/en/spot/400/index.html"],["Ueno Toshogu Shrine","A historic shrine within Ueno Park","https://www.gotokyo.org/en/spot/399/index.html"]]}]},{"id":"kyoto","label":"Kyoto · Kiyomizu to Gion","title":"Kyoto lanes and temple gates","description":"A walking day through Higashiyama, with lunch choices on the way to Gion.","area":"Higashiyama & Gion","gap":20,"stops":[{"type":"sight","duration":70,"choices":[["Kiyomizu-dera Temple","A classic hillside temple and city views","https://kyoto.travel/en/destinations/kiyomizudera-temple/"],["Kodai-ji Temple","Gardens and historic temple halls nearby","https://kyoto.travel/en/destinations/kodaiji-temple/"]]},{"type":"walk","duration":60,"choices":[["Sannenzaka and Ninenzaka","Walk historic slopes and shopfronts","https://kyoto.travel/en/itineraries/higashiyama-at-dawn/"],["Yasaka Pagoda streets","A landmark framed by old Kyoto lanes","https://kyoto.travel/en/destinations/hokanji-templeyasaka-pagoda/"]]},{"type":"food","duration":75,"choices":[["Gion Tempura Endo","Tempura near Yasaka Pagoda; reservations advised","https://www.gion-endo.com/en/","japanese"],["Gion Izuju","Traditional Kyoto-style sushi beside Yasaka Shrine","https://gion-izuju.com/english-page/","sushi"],["ICHIRAN Kyoto Kawaramachi","Tonkotsu ramen across the river from Gion","https://en.ichiran.com/shop/kinki/kyoto-kawaramachi/","ramen"]]},{"type":"sight","duration":60,"choices":[["Yasaka-jinja Shrine","A bright landmark at the edge of Gion","https://kyoto.travel/en/destinations/yasakajinja-shrine/"],["Kennin-ji Temple","Zen temple and gardens in the Gion area","https://kyoto.travel/en/destinations/kenninjitemple/"]]},{"type":"break","duration":55,"choices":[["Gion lanes","Explore public streets and traditional architecture","https://kyoto.travel/en/areas/gion-kiyomizu/"],["Kamo River promenade","Finish by the river near Gion-Shijo","https://kyoto.travel/en/getting-around/comfortable-access-to-gion-yasaka-jinja-shrine/"]]}]},{"id":"osaka","label":"Osaka · Namba and Dotonbori","title":"Osaka street food and neon","description":"Markets, cookware streets and a lively canal-side finish.","area":"Namba & Dotonbori","gap":17,"stops":[{"type":"sight","duration":65,"choices":[["Kuromon Market","Browse stalls in Osaka’s historic food market","https://osaka-info.jp/en/spot/kuromon-market/"],["Namba Yasaka Shrine","A striking lion-head shrine in Namba","https://osaka-info.jp/en/spot/nanbayasakajinja/"]]},{"type":"walk","duration":55,"choices":[["Sennichimae Doguyasuji","Cooking tools and food replicas","https://osaka-info.jp/en/spot/sennichimae-doguyasuji-shopping-street/"],["Hozenji Yokocho","Stone-paved lane and neighborhood atmosphere","https://www.osaka-info.jp/en/spot/hozenji-yokocho/"],["Namba Parks","Shopping and a rooftop garden in Namba","https://osaka-info.jp/experience/en/osaka/spot/240"]]},{"type":"food","duration":70,"choices":[["Chibo Dotonbori","Osaka-style okonomiyaki in Dotonbori","https://shop.chibo.com/detail/28/","japanese"],["Sushizanmai Ebisubashi","Sushi close to Ebisubashi","https://www.kiyomura.co.jp/store/detail/76","sushi"],["ICHIRAN Dotonbori South","Tonkotsu ramen by the canal district","https://en.ichiran.com/shop/kinki/dotonbori-south/","ramen"]]},{"type":"sight","duration":60,"choices":[["Dotonbori","Canal-side signs and busy streets","https://osaka-info.jp/en/spot/dotonbori/"],["Hozenji Yokocho","A quieter stone-paved detour nearby","https://www.osaka-info.jp/en/spot/hozenji-yokocho/"],["Ebisu Bridge","See the canal and landmark signs from the bridge","https://osaka-info.jp/experience/en/osaka/spot/551"]]},{"type":"break","duration":55,"choices":[["Shinsaibashi-suji","End with a stroll through the shopping arcade","https://osaka-info.jp/en/spot/shinsaibashi-suji-shopping-street/"],["Ebisubashi-suji","Shop and snack near Namba Station","https://osaka-info.jp/en/spot/ebisubashisuji-shopping-street/"]]}]},{"id":"nara","label":"Nara · Great Buddha and old town","title":"Nara temples and old streets","description":"The Great Buddha, a garden and a local food break on a walk toward Naramachi.","area":"Nara Park & Naramachi","gap":19,"stops":[{"type":"sight","duration":75,"choices":[["Todai-ji Temple","Visit the Great Buddha Hall","https://www.visitnara.jp/venues/A00485/"],["Nara National Museum","Explore Nara’s Buddhist art collection","https://www.narahaku.go.jp/english/"]]},{"type":"walk","duration":55,"choices":[["Isuien Garden","Stroll through a landscaped garden near Todai-ji","https://www.visitnara.jp/venues/A00493/"],["Nara Park","Walk among the park’s historic temples and deer","https://www.visitnara.jp/venues/A00489/"]]},{"type":"food","duration":65,"choices":[["Kamaiki Honten","Fresh udon near Kintetsu Nara Station","https://www.visitnara.jp/venues/D00082/","japanese"],["Kakinohazushi Tanaka","Local persimmon-leaf sushi and a light lunch","https://www.visitnara.jp/venues/D00067/","sushi"],["Genkishin","Ramen near Kintetsu Nara Station","https://www.visitnara.jp/venues/D00109/","ramen"]]},{"type":"sight","duration":60,"choices":[["Kohfukuji Temple","Temple grounds near the shopping streets","https://www.visitnara.jp/venues/A00486/"],["Sarusawa Pond","A short pause with a view toward Kohfukuji","https://www.visitnara.jp/venues/A01559/"]]},{"type":"break","duration":55,"choices":[["Naramachi","Browse old lanes and local crafts","https://www.visitnara.jp/destinations/area/naramachi/"],["Gangoji Temple","Explore a historic temple in Naramachi","https://www.visitnara.jp/venues/A00495/"]]}]},{"id":"hiroshima","label":"Hiroshima · Peace Park and gardens","title":"Hiroshima, reflection and renewal","description":"Time for the memorial sites, local lunch, castle grounds and a garden.","area":"Central Hiroshima","gap":23,"stops":[{"type":"sight","duration":85,"choices":[["Hiroshima Peace Memorial Museum","Allow unhurried time for the exhibits","https://dive-hiroshima.com/en/explore/2675/"],["National Peace Memorial Hall","Remember the victims through testimony and remembrance","https://dive-hiroshima.com/en/explore/2679/"]]},{"type":"walk","duration":55,"choices":[["Peace Memorial Park","Walk respectfully through the memorial grounds","https://dive-hiroshima.com/en/explore/2621/"],["Atomic Bomb Dome","Visit the preserved landmark on the park’s north side","https://dive-hiroshima.com/en/explore/2687/"]]},{"type":"food","duration":70,"choices":[["Nagata-ya","Hiroshima-style okonomiyaki near Peace Park","https://nagataya-okonomi.com/en/access.html","japanese"],["Sushitei Hondori","Sushi in the nearby Hondori arcade","https://www.hondori.or.jp/shop/detail?shop_id=55","sushi"],["IPPUDO Hiroshima Fukuromachi","Ramen in the central Fukuromachi area","https://stores.ippudo.com/en/1048","ramen"]]},{"type":"sight","duration":60,"choices":[["Hiroshima Castle grounds","Walk the castle site; the main keep is closed","https://dive-hiroshima.com/en/explore/3318/"],["Hiroshima Hondori","Explore the covered shopping street","https://dive-hiroshima.com/en/explore/3502/"]]},{"type":"break","duration":60,"choices":[["Shukkeien Garden","Finish among ponds and garden paths","https://dive-hiroshima.com/en/explore/306/"],["Hiroshima Prefectural Art Museum","Art beside Shukkeien Garden","https://dive-hiroshima.com/en/explore/312/"]]}]}],"notes":{"Sensoji Temple":"The temple grounds and worship areas have different rhythms. Follow signs and leave time for the approach.","Asakusa Culture Tourist Information Center":"Ask for an area map or current local advice before heading into the lanes.","Nakamise Shopping Street":"Browse before buying snacks; individual shop hours can differ from the temple grounds.","Sumida Park":"This is an outdoor riverside stop. Keep a weather alternative in mind.","Ramen Yoroiya":"A compact ramen lunch suits a quicker schedule; allow extra time if there is a queue.","Sushizanmai Asakusa Kaminarimon":"Choose sushi near Kaminarimon; check the current menu and wait at the store.","Asakusa Imahan":"Sukiyaki is a slower meal. Check reservations and allow time to sit down.","Tokyo Skytree":"Check observation deck tickets before crossing over from Asakusa.","Sumida Aquarium":"The aquarium is inside Skytree Town and requires its own admission.","Postal Museum Japan":"The museum is in Skytree Town. Check its opening day before choosing this indoor stop.","Tokyo Solamachi":"Shops and food are in the same complex as Skytree, making this an easy flexible finish.","Tokyo Mizumachi":"This riverside complex is between Asakusa and Skytree; check your walking direction after a swap.","Tokyo National Museum":"The museum has multiple galleries. Choose a collection before you arrive.","National Museum of Nature and Science":"Pick a few galleries rather than trying to see everything in one stop.","National Museum of Western Art":"This museum is in Ueno Park. Check the exhibition and ticket details for your day.","Ueno Park":"Outdoor paths connect several museums; the experience changes with the weather.","Ameyoko Shopping Street":"Expect a busy street of small shops and food stalls near Ueno Station.","Inshotei":"A sit-down seasonal meal in the park can take longer than a quick noodle stop.","Sushizanmai Ueno":"Check the store menu and any wait before committing to a timed museum visit.","IPPUDO Ueno-hirokoji":"A quicker ramen stop around the shopping streets; check the store hours.","Tokyo Metropolitan Art Museum":"Exhibitions change. Confirm what is on and whether a ticket is needed.","Shinobazu Pond":"A flexible outdoor finish; take the paths that suit your remaining time.","Ueno Toshogu Shrine":"Check access to the inner grounds if you plan to see more than the approach.","Kiyomizu-dera Temple":"The approach is uphill. Leave time for the walk as well as the temple.","Kodai-ji Temple":"A quieter temple and garden option; check admission and special opening times.","Sannenzaka and Ninenzaka":"These sloping streets have steps and crowds. Wear comfortable shoes.","Yasaka Pagoda streets":"The pagoda is best viewed from public streets; leave the roadway clear.","Gion Tempura Endo":"A longer sit-down meal. Check lunch reservations before setting out.","Gion Izuju":"Kyoto-style sushi differs from typical nigiri; browse the menu before deciding.","ICHIRAN Kyoto Kawaramachi":"This ramen choice is farther west of the Gion sights. Allow more walking time.","Yasaka-jinja Shrine":"A convenient landmark on the way into Gion; respect worshippers and signs.","Kennin-ji Temple":"Check the temple visit hours and allow time for its garden areas.","Gion lanes":"Stay on public streets, respect private property and follow local photography rules.","Kamo River promenade":"An outdoor riverside finish; the path can be a pleasant change from Gion lanes.","Kuromon Market":"Stalls vary by day and time. Browse first and eat only where the shop permits.","Namba Yasaka Shrine":"This option lies farther west than Kuromon; allow extra time to reach the next stop.","Sennichimae Doguyasuji":"Look for cookware and food replicas; many shops close earlier than nightlife venues.","Hozenji Yokocho":"A small stone-paved lane offers a quieter pause near busy Dotonbori.","Namba Parks":"The rooftop garden offers an outdoor break above the shops.","Chibo Dotonbori":"Okonomiyaki is cooked to order. Allow more time than for a quick ramen bowl.","Sushizanmai Ebisubashi":"Sushi is close to the bridge; check the store menu and queue.","ICHIRAN Dotonbori South":"This is the South Building; the former Dotonbori Main Building has closed.","Dotonbori":"A busy canal-side area. Move beyond the main photo spot to explore the streets.","Ebisu Bridge":"A short photo stop over the canal; keep space for other pedestrians.","Shinsaibashi-suji":"A long shopping arcade, so choose a turnaround point for your schedule.","Ebisubashi-suji":"A covered route back toward Namba Station with shops and snacks.","Todai-ji Temple":"Check Great Buddha Hall admission and keep time for the walk through the park.","Nara National Museum":"Exhibitions and opening days vary. Confirm the galleries you want to see.","Isuien Garden":"A garden near Todai-ji; check admission and opening days before your visit.","Nara Park":"The deer are wild. Feed them only the special deer crackers sold in the park.","Kamaiki Honten":"A fresh udon stop near Kintetsu Nara Station; allow for a lunchtime queue.","Kakinohazushi Tanaka":"A light local sushi meal and tea-room stop, rather than a long restaurant lunch.","Genkishin":"A ramen option near the station; confirm current opening times.","Kohfukuji Temple":"Near the main shopping area; decide whether to enter the paid museum hall.","Sarusawa Pond":"An easy outdoor pause with a view toward Kohfukuji.","Naramachi":"These old-town streets reward a slow walk; individual shops keep their own hours.","Gangoji Temple":"A quieter cultural stop in Naramachi; check its admission hours.","Hiroshima Peace Memorial Museum":"The exhibits can be emotionally demanding. Give yourself enough unhurried time.","National Peace Memorial Hall":"A space for remembrance and testimony; approach it respectfully.","Peace Memorial Park":"Leave time to reflect at the monuments rather than treating this as a quick crossing.","Atomic Bomb Dome":"View the preserved exterior from the public paths and respect the memorial setting.","Nagata-ya":"Hiroshima-style okonomiyaki close to Peace Park; queues can add time.","Sushitei Hondori":"Sushi in the Hondori arcade; confirm today’s opening and menu.","IPPUDO Hiroshima Fukuromachi":"A ramen choice in Fukuromachi; allow walking time from the park.","Hiroshima Castle grounds":"The main keep is closed to entry. The exterior and grounds can still be viewed.","Hiroshima Hondori":"A covered central shopping street, useful as a flexible indoor finish.","Shukkeien Garden":"Allow time to follow the paths around the ponds; check garden admission.","Hiroshima Prefectural Art Museum":"Beside Shukkeien; check current exhibitions and tickets."},"visitMinutes":{"Tokyo Skytree":80,"Sumida Aquarium":65,"Postal Museum Japan":50,"Tokyo Mizumachi":45,"Tokyo National Museum":85,"National Museum of Nature and Science":85,"Tokyo Metropolitan Art Museum":70,"National Museum of Western Art":75,"Kiyomizu-dera Temple":75,"Kodai-ji Temple":60,"Yasaka Pagoda streets":40,"Kennin-ji Temple":70,"Kamo River promenade":40,"Namba Yasaka Shrine":40,"Hozenji Yokocho":40,"Ebisu Bridge":25,"Namba Parks":50,"Nara National Museum":85,"Nara Park":45,"Sarusawa Pond":35,"Kakinohazushi Tanaka":40,"Kamaiki Honten":50,"National Peace Memorial Hall":65,"Atomic Bomb Dome":35,"Hiroshima Hondori":45,"Hiroshima Prefectural Art Museum":75,"Nagata-ya":65}}
"""#
        guard let guide = try? JSONDecoder().decode(GuideData.self, from: Data(json.utf8)) else {
            fatalError("Embedded guide data is invalid")
        }
        return GuideData(routes: guide.routes + NationwideRoutes.routes + FeaturedRoutes.routes, notes: guide.notes, visitMinutes: guide.visitMinutes)
    }()
}

@main
struct JapanDayPlannerApp: App {
    var body: some Scene {
        WindowGroup { PlannerView() }
    }
}

private struct PlannerView: View {
    private let guide = GuideData.bundled
    @AppStorage("japanDay.route") private var routeID = "asakusa"
    @AppStorage("japanDay.region") private var regionID = "kanto"
    @AppStorage("japanDay.prefecture") private var prefectureID = "tokyo"
    @AppStorage("japanDay.start") private var startMinutes = 600
    @AppStorage("japanDay.choices") private var savedChoices = "{}"
    @State private var swapIndex: Int?
    @AppStorage("japanDay.language") private var languageCode = "ja"
    @State private var showingGuide = false
    @AppStorage("japanDay.hotels") private var savedHotels = "{}"
    @AppStorage("japanDay.customHotels") private var savedCustomHotels = "{}"
    @AppStorage("japanDay.dinnerArea") private var dinnerArea = "auto"
    @State private var journeyIndex = 0
    @State private var journeyCompleted = false
    @State private var dinnerResults: [DinnerPlace] = []
    @State private var dinnerSelection: DinnerPlace?
    @State private var dinnerSearching = false
    @State private var dinnerSearchError = false
    @State private var dinnerSearchID = UUID()
    @State private var lunchResults: [DinnerPlace] = []
    @State private var lunchSelection: DinnerPlace?
    @State private var lunchSearching = false
    @State private var lunchSearchError = false
    @State private var lunchSearchID = UUID()
    @State private var hotelResults: [HotelSuggestion] = []
    @State private var hotelSearching = false
    @State private var hotelSearchError = false
    @State private var hotelSearchID = UUID()
    @AppStorage("japanDay.suggestedHotels") private var savedSuggestedHotels = "{}"

    private var language: GuideLanguage { GuideLanguage(rawValue: languageCode) ?? .ja }
    private func text(_ key: String) -> String { GuideTranslations.ui[key]?[language.index] ?? key }
    private func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: language.locale, arguments: arguments)
    }
    private func routeText(_ item: DayRoute, _ field: Int) -> String {
        if let featured = FeaturedRoutes.info[item.id] { return featured.fields[language.index][field] }
        if let standard = GuideTranslations.routes[item.id]?[language.index] { return standard[field] }
        if field == 2 { return NationwideRoutes.summary[language.index] }
        if language == .ja {
            if field == 3 { return NationwideRoutes.japaneseAreas[item.id] ?? item.area }
            return NationwideRoutes.japaneseLabels[item.id] ?? item.label
        }
        return [item.label, item.title, item.description, item.area][field]
    }
    private func venueText(_ venue: Venue, _ field: Int) -> String {
        if let names = FeaturedRoutes.names[venue.name] {
            return field == 0 ? names[language.index] : FeaturedRoutes.ui["visitNote"]![language.index]
        }
        if venue.name.hasPrefix("Lunch near ") {
            return field == 0 ? journeyText("lunchSearch") : journeyText("lunchNote")
        }
        if NationwideRoutes.japanesePlaces[venue.name] != nil {
            return field == 0 ? (language == .ja ? NationwideRoutes.japanesePlaces[venue.name]! : venue.name) : NationwideRoutes.venueDetails[language.index]
        }
        if language == .en { return field == 0 ? venue.name : venue.detail }
        let index = language == .th ? 3 : language.index
        return GuideTranslations.venues[venue.name]?[index][field] ?? (field == 0 ? venue.name : venue.detail)
    }
    private var finishTime: String {
        guard let last = route.stops.indices.last else { return time(startMinutes) }
        return time(startOfStop(last) + duration(route.stops[last], venue: selectedVenue(last)))
    }
    private var languageButtons: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 125), spacing: 12)], spacing: 12) {
            ForEach(GuideLanguage.allCases) { item in
                Button {
                    swapIndex = nil
                    languageCode = item.rawValue
                    showingGuide = true
                } label: {
                    HStack(spacing: 6) {
                        Text(item.title).font(.headline)
                        if language == item { Image(systemName: "checkmark.circle.fill") }
                    }
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .padding(.horizontal, 8)
                    .foregroundStyle(language == item ? Color.black : Color.white)
                    .background(language == item ? Color.yellow : Color(red: 0.08, green: 0.24, blue: 0.29), in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
        }
    }
    private var languageHome: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: "globe.asia.australia.fill")
                    .font(.system(size: 54)).foregroundStyle(.yellow)
                Text("Japan Day Planner").font(.largeTitle.bold())
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(GuideLanguage.allCases) { item in
                        Text(GuideTranslations.ui["welcome"]?[item.index] ?? item.title)
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                languageButtons
            }
            .padding(24).frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.black)
    }

    private var route: DayRoute { guide.routes.first(where: { $0.id == routeID }) ?? guide.routes[0] }
    private var routePrefecture: String {
        route.prefecture ?? NationwideRoutes.existingPrefectures[route.id] ?? "tokyo"
    }
    private var prefecturesInRegion: [PrefectureOption] {
        NationwideRoutes.prefectures.filter { $0.region == regionID }
    }
    private var routesInPrefecture: [DayRoute] {
        guide.routes.filter { ($0.prefecture ?? NationwideRoutes.existingPrefectures[$0.id]) == prefectureID }
    }
    private func selectRegion(_ value: String) {
        guard value != regionID else { return }
        regionID = value
        if let first = NationwideRoutes.prefectures.first(where: { $0.region == value }) {
            selectPrefecture(first.id)
        }
    }
    private func selectPrefecture(_ value: String) {
        guard value != prefectureID else { return }
        prefectureID = value
        if let first = guide.routes.first(where: { ($0.prefecture ?? NationwideRoutes.existingPrefectures[$0.id]) == value }) {
            routeID = first.id
        }
        clearHotelSearch()
        resetJourney()
    }
    private func label(_ japanese: String, _ english: String) -> String {
        language == .ja ? japanese : english
    }
    private var selections: [String: [Int]] {
        guard let data = savedChoices.data(using: .utf8) else { return [:] }
        return (try? JSONDecoder().decode([String: [Int]].self, from: data)) ?? [:]
    }

    private func selectedIndex(_ index: Int) -> Int {
        let value = selections[route.id]?[safe: index] ?? 0
        return route.stops[index].choices.indices.contains(value) ? value : 0
    }

    private func selectedVenue(_ index: Int) -> Venue { route.stops[index].choices[selectedIndex(index)] }

    private func duration(_ stop: Stop, venue: Venue) -> Int {
        if let specific = guide.visitMinutes[venue.name] { return specific }
        if stop.type == "food" {
            return ["ramen": 45, "sushi": 60, "japanese": 80][venue.cuisine ?? ""] ?? stop.duration
        }
        return stop.duration
    }

    private func startOfStop(_ index: Int) -> Int {
        var clock = startMinutes
        for previous in 0..<index {
            clock += duration(route.stops[previous], venue: selectedVenue(previous)) + route.gap
        }
        return clock
    }

    private func time(_ minutes: Int) -> String {
        let normalized = ((minutes % 1440) + 1440) % 1440
        let formatter = DateFormatter()
        formatter.locale = language.locale
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = language == .en ? "h:mm a" : "HH:mm"
        return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(normalized * 60)))
    }

    private func choose(_ choice: Int, at index: Int) {
        var all = selections
        var current = all[route.id] ?? Array(repeating: 0, count: route.stops.count)
        if current.count != route.stops.count { current = Array(repeating: 0, count: route.stops.count) }
        current[index] = choice
        all[route.id] = current
        if let data = try? JSONEncoder().encode(all), let string = String(data: data, encoding: .utf8) {
            savedChoices = string
        }
        swapIndex = nil
    }

    private var sharedPlan: String {
        var lines = ["Japan Day Planner · \(routeText(route, 0))"]
        for index in route.stops.indices {
            let venue = selectedVenue(index)
            if venue.name.hasPrefix("Lunch near "), let place = lunchSelection {
                lines.append("\(time(startOfStop(index))) · \(place.name) · \(place.address)")
            } else {
                let url = URL(string: venue.url).flatMap { translatedGuideURL($0) }?.absoluteString ?? venue.url
                lines.append("\(time(startOfStop(index))) · \(venueText(venue, 0)) · \(url)")
            }
        }
        if !hotelQuery.isEmpty { lines.insert("\(journeyText("chooseHotel")) · \(hotelName)", at: 1) }
        lines.append(journeyText(dinnerNearHotel ? "earlyNote" : "lateNote"))
        if let place = dinnerSelection {
            lines.append("\(journeyText("selectedDinner")) · \(place.name) · \(place.address)")
            if !hotelQuery.isEmpty, let url = mapURL(origin: place.query, destination: hotelQuery, mode: "transit") {
                lines.append("\(journeyText("afterDinner")) · \(url.absoluteString)")
            }
        }
        lines.append(text("sharedNote"))
        return lines.joined(separator: "\n")
    }

    var body: some View {
        NavigationStack {
            if showingGuide {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            controls
                            Text(routeText(route, 0)).font(.title2.bold())
                            Text(journeyText("opening")).font(.subheadline).foregroundStyle(.secondary)
                            if language != .ja {
                                Text(journeyText("webTranslationNote")).font(.footnote).foregroundStyle(.secondary)
                            }
                            journeyHotelPicker
                            dinnerAreaPicker
                            journeyOverview
                            journeyCurrent.id("currentStage")
                            Text(text("footer")).font(.footnote).foregroundStyle(.secondary).padding(.bottom)
                        }.padding()
                    }
                    .background(journeyBackground)
                    .onChange(of: journeyIndex) { _ in
                        withAnimation { proxy.scrollTo("currentStage", anchor: .top) }
                    }
                }
                .navigationTitle("Japan Day Planner")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(text("home")) { showingGuide = false }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        ShareLink(item: sharedPlan) { Image(systemName: "square.and.arrow.up") }
                            .accessibilityLabel(text("share"))
                    }
                }
                .sheet(isPresented: Binding(get: { swapIndex != nil }, set: { if !$0 { swapIndex = nil } })) {
                    if let index = swapIndex { swapSheet(index) }
                }
                .onChange(of: routeID) { _ in clearHotelSearch(); resetJourney() }
                .onAppear {
                    let oldPrefecture = routePrefecture
                    if prefectureID != oldPrefecture {
                        prefectureID = oldPrefecture
                        regionID = NationwideRoutes.prefectures.first(where: { $0.id == oldPrefecture })?.region ?? "kanto"
                    }
                }
                .onChange(of: startMinutes) { _ in resetJourney() }
                .onChange(of: dinnerArea) { _ in resetJourney() }
                .onChange(of: savedChoices) { _ in resetDinner(); resetLunch() }
                .onChange(of: dinnerNearHotel) { _ in resetJourney() }
            } else {
                languageHome
            }
        }
        .environment(\.locale, language.locale)
        .preferredColorScheme(.dark)
        .tint(journeyGold)
    }


    // Each destination and transfer has its own visible stage.
    private enum JourneyStage {
        case departure, stop(Int), hotelBeforeDinner, dinner, hotelAfterDinner
    }
    private let journeyBackground = Color(red: 0.06, green: 0.11, blue: 0.18)
    private let journeySurface = Color(red: 0.11, green: 0.17, blue: 0.26)
    private let journeyGold = Color(red: 0.94, green: 0.80, blue: 0.45)

    private func journeyText(_ key: String) -> String {
        JourneyTranslations.ui[key]?[language.index] ?? key
    }
    private func storedValues(_ value: String) -> [String: String] {
        guard let data = value.data(using: .utf8) else { return [:] }
        return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
    }
    private func saveHotelValue(_ value: String, custom: Bool = false) {
        var values = storedValues(custom ? savedCustomHotels : savedHotels)
        values[route.id] = value
        guard let data = try? JSONEncoder().encode(values), let string = String(data: data, encoding: .utf8) else { return }
        if custom { savedCustomHotels = string } else { savedHotels = string }
        resetJourney()
    }
    private var availableHotels: [NearbyHotel] { TravelExtras.hotels[route.id] ?? [] }
    private var selectedSuggestedHotel: HotelSuggestion? {
        guard let data = savedSuggestedHotels.data(using: .utf8),
              let values = try? JSONDecoder().decode([String: HotelSuggestion].self, from: data) else { return nil }
        return values[route.id]
    }
    private func chooseSuggestedHotel(_ hotel: HotelSuggestion) {
        var values = (try? JSONDecoder().decode([String: HotelSuggestion].self, from: Data(savedSuggestedHotels.utf8))) ?? [:]
        values[route.id] = hotel
        if let data = try? JSONEncoder().encode(values), let string = String(data: data, encoding: .utf8) {
            savedSuggestedHotels = string
            saveHotelValue("suggested")
        }
    }
    private var hotelChoice: String {
        let value = storedValues(savedHotels)[route.id] ?? ""
        if value == "custom" || availableHotels.contains(where: { $0.id == value }) { return value }
        if value == "suggested" && selectedSuggestedHotel != nil { return value }
        return availableHotels.first?.id ?? "custom"
    }
    private var chosenHotel: NearbyHotel? { availableHotels.first(where: { $0.id == hotelChoice }) }
    private var customHotel: String { storedValues(savedCustomHotels)[route.id] ?? "" }
    private var hotelName: String {
        chosenHotel?.names[language.index] ?? (hotelChoice == "suggested" ? selectedSuggestedHotel?.name : nil) ?? (customHotel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? journeyText("enterHotel") : customHotel)
    }
    private var hotelQuery: String {
        if let hotel = chosenHotel { return "\(hotel.names[0]), \(hotel.addressJP), Japan" }
        if hotelChoice == "suggested", let hotel = selectedSuggestedHotel { return hotel.query }
        let value = customHotel.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefecture = NationwideRoutes.prefectures.first(where: { $0.id == routePrefecture })?.ja ?? cityQuery
        return value.isEmpty ? "" : "\(value), \(prefecture), Japan"
    }
    private var finishMinutes: Int {
        guard let index = route.stops.indices.last else { return startMinutes }
        return startOfStop(index) + duration(route.stops[index], venue: selectedVenue(index))
    }
    private var dinnerNearHotel: Bool {
        if dinnerArea == "hotel" { return true }
        if dinnerArea == "last" { return false }
        return finishMinutes < 18 * 60
    }
    private var lastVenue: Venue { selectedVenue(route.stops.count - 1) }
    private var dinnerAnchorQuery: String { dinnerNearHotel ? hotelQuery : venueQuery(lastVenue) }
    private var dinnerAnchorName: String { dinnerNearHotel ? hotelName : venueText(lastVenue, 0) }
    private var stages: [JourneyStage] {
        var items: [JourneyStage] = [.departure]
        items.append(contentsOf: route.stops.indices.map { .stop($0) })
        if dinnerNearHotel { items.append(.hotelBeforeDinner) }
        items.append(.dinner)
        items.append(.hotelAfterDinner)
        return items
    }
    private var currentStage: JourneyStage { stages[min(max(0, journeyIndex), stages.count - 1)] }
    private func stageTitle(_ item: JourneyStage) -> String {
        switch item {
        case .departure: return journeyText("depart")
        case .stop(let index):
            if selectedVenue(index).name.hasPrefix("Lunch near "), let place = lunchSelection { return place.name }
            return venueText(selectedVenue(index), 0)
        case .hotelBeforeDinner: return journeyText("hotelFirst")
        case .dinner: return journeyText(dinnerNearHotel ? "dinnerHotel" : "dinnerLast")
        case .hotelAfterDinner: return journeyText("returnHotel")
        }
    }
    private func stageSymbol(_ item: JourneyStage) -> String {
        switch item {
        case .departure, .hotelBeforeDinner, .hotelAfterDinner: return "bed.double.fill"
        case .dinner: return "fork.knife"
        case .stop(let index): return route.stops[index].type == "food" ? "fork.knife" : "mappin.and.ellipse"
        }
    }
    private func stageTime(_ item: JourneyStage) -> String? {
        switch item {
        case .stop(let index): return time(startOfStop(index))
        default: return nil
        }
    }
    private func resetJourney() {
        journeyIndex = 0
        journeyCompleted = false
        resetDinner()
        resetLunch()
    }
    private func resetLunch() {
        lunchSearchID = UUID()
        lunchResults = []
        lunchSelection = nil
        lunchSearching = false
        lunchSearchError = false
    }
    private func resetDinner() {
        dinnerSearchID = UUID()
        dinnerResults = []
        dinnerSelection = nil
        dinnerSearchError = false
        dinnerSearching = false
    }
    private func journeyPanel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14, content: content)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(journeySurface, in: RoundedRectangle(cornerRadius: 16))
    }
    private func journeyAction(_ title: String, systemImage: String = "arrow.right", action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Image(systemName: systemImage)
            }
            .font(.headline).padding(14).frame(maxWidth: .infinity, minHeight: 48)
            .foregroundStyle(Color.black)
            .background(journeyGold, in: RoundedRectangle(cornerRadius: 11))
        }
        .buttonStyle(.plain)
    }
    private var targetWebLanguage: String {
        switch language {
        case .ja: return "ja"
        case .ko: return "ko"
        case .zh: return "zh-CN"
        case .en: return "en"
        case .th: return "th"
        }
    }
    private func translatedGuideURL(_ original: URL) -> URL? {
        guard language != .ja, let scheme = original.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              let host = original.host?.lowercased(),
              host != "translate.google.com", host != "translate.google.co.jp",
              !host.hasSuffix("google.com"), !host.hasSuffix("google.co.jp") else { return nil }
        var parts = URLComponents(string: "https://translate.google.com/translate")
        parts?.queryItems = [
            URLQueryItem(name: "sl", value: "auto"),
            URLQueryItem(name: "tl", value: targetWebLanguage),
            URLQueryItem(name: "hl", value: targetWebLanguage),
            URLQueryItem(name: "u", value: original.absoluteString)
        ]
        return parts?.url
    }
    private func localizedMapURL(_ original: URL) -> URL {
        guard language != .ja, let host = original.host?.lowercased(),
              (host == "www.google.com" || host == "maps.google.com"),
              original.path.hasPrefix("/maps/") else { return original }
        var parts = URLComponents(url: original, resolvingAgainstBaseURL: false)
        var items = parts?.queryItems ?? []
        items.removeAll(where: { $0.name == "hl" })
        items.append(URLQueryItem(name: "hl", value: targetWebLanguage))
        parts?.queryItems = items
        return parts?.url ?? original
    }
    private func translatedGuideLink(_ title: String, url: URL) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            if let translated = translatedGuideURL(url) {
                journeyLink("\(title) · \(journeyText("translatedPage"))", url: translated, systemImage: "character.book.closed")
                journeyLink(journeyText("originalPage"), url: url, systemImage: "globe")
            } else {
                journeyLink(title, url: url, systemImage: "globe")
            }
        }
    }
    private func journeyLink(_ title: String, url: URL, systemImage: String = "magnifyingglass") -> some View {
        Link(destination: localizedMapURL(url)) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.bold()).fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .padding(.horizontal, 12)
                .foregroundStyle(journeyGold)
                .background(Color(red: 0.15, green: 0.22, blue: 0.33), in: RoundedRectangle(cornerRadius: 10))
        }
    }
    private var journeyHotelPicker: some View {
        journeyPanel {
            Label(journeyText("chooseHotel"), systemImage: "bed.double.fill").font(.headline)
            ForEach(availableHotels) { hotel in
                visibleChoice(hotel.names[language.index], selected: hotelChoice == hotel.id) { saveHotelValue(hotel.id) }
            }
            if let hotel = selectedSuggestedHotel {
                visibleChoice(hotel.name, selected: hotelChoice == "suggested") { saveHotelValue("suggested") }
            }
            visibleChoice(journeyText("ownHotel"), selected: hotelChoice == "custom") { saveHotelValue("custom") }
            if hotelChoice == "suggested", let hotel = selectedSuggestedHotel {
                Text(hotel.address).font(.subheadline).foregroundStyle(.secondary)
                if let url = hotel.website.flatMap(URL.init(string:)) {
                    translatedGuideLink(extra("rate"), url: url)
                }
                if let url = locationURL(hotel.query) { journeyLink(extra("hotelMap"), url: url, systemImage: "mappin.and.ellipse") }
                if let phone = hotel.phone, let url = URL(string: "tel:\(phone)") {
                    journeyLink("\(extra("call")) · \(phone)", url: url, systemImage: "phone")
                }
                Text(extra("rateNote")).font(.footnote).foregroundStyle(.secondary)
            } else if hotelChoice == "custom" {
                TextField(journeyText("hotelInput"), text: Binding(get: { customHotel }, set: { saveHotelValue($0, custom: true) }))
                    .textFieldStyle(.roundedBorder)
                Text(journeyText("hotelInputNote")).font(.footnote).foregroundStyle(.secondary)
            } else if let hotel = chosenHotel {
                Text(language == .ja ? hotel.addressJP : hotel.addressEN).font(.subheadline).foregroundStyle(.secondary)
                if let url = URL(string: hotel.rateURL) { translatedGuideLink(extra("rate"), url: url) }
                if let url = locationURL(hotelQuery) { journeyLink(extra("hotelMap"), url: url, systemImage: "mappin.and.ellipse") }
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 10) {
                        if let url = URL(string: "tel:\(hotel.phone)") {
                            journeyLink("\(extra("call")) · \(hotel.phoneDisplay)", url: url, systemImage: "phone")
                        }
                        if let url = URL(string: hotel.contactURL) { translatedGuideLink(extra("contact"), url: url) }
                        Text(extra("rateNote")).font(.footnote).foregroundStyle(.secondary)
                    }.padding(.top, 10)
                }
            }
            if !hotelSearching {
                journeyAction(journeyText("findHotels"), systemImage: "magnifyingglass") { searchHotels() }
            } else {
                ProgressView(journeyText("searchingHotels"))
            }
            if hotelSearchError { Text(journeyText("hotelsUnavailable")).font(.footnote) }
            ForEach(hotelResults) { hotel in
                VStack(alignment: .leading, spacing: 10) {
                    Text(hotel.name).font(.headline)
                    Text(hotel.address).font(.subheadline).foregroundStyle(.secondary)
                    Text(String(format: journeyText("distance"), locale: language.locale, arguments: [Int(hotel.distance.rounded())]))
                        .font(.caption).foregroundStyle(.secondary)
                    if let url = locationURL(hotel.query) { journeyLink(extra("hotelMap"), url: url, systemImage: "mappin.and.ellipse") }
                    if let url = hotel.website.flatMap(URL.init(string:)) { translatedGuideLink(extra("rate"), url: url) }
                    if let phone = hotel.phone, let url = URL(string: "tel:\(phone)") { journeyLink("\(extra("call")) · \(phone)", url: url, systemImage: "phone") }
                    journeyAction(journeyText("chooseThisHotel"), systemImage: "checkmark.circle") { chooseSuggestedHotel(hotel) }
                }
                .padding(12)
                .background(Color(red: 0.15, green: 0.22, blue: 0.33), in: RoundedRectangle(cornerRadius: 10))
            }
            Text(journeyText("hotelChoiceNote")).font(.footnote).foregroundStyle(.secondary)
        }
    }
    private func clearHotelSearch() {
        hotelSearchID = UUID()
        hotelResults = []
        hotelSearching = false
        hotelSearchError = false
    }
    @MainActor
    private func searchHotels() {
        guard !hotelSearching else { return }
        let start = venueQuery(selectedVenue(0))
        let token = UUID()
        hotelSearchID = token
        hotelSearching = true
        hotelSearchError = false
        hotelResults = []
        Task { @MainActor in
            do {
                let anchorRequest = MKLocalSearch.Request()
                anchorRequest.naturalLanguageQuery = start
                let anchor = try await MKLocalSearch(request: anchorRequest).start()
                guard hotelSearchID == token else { return }
                guard let first = anchor.mapItems.first else {
                    hotelSearching = false; hotelSearchError = true; return
                }
                let coordinate = first.placemark.coordinate
                let center = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = "ホテル"
                request.resultTypes = .pointOfInterest
                request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.hotel])
                request.region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 5000, longitudinalMeters: 5000)
                let response = try await MKLocalSearch(request: request).start()
                guard hotelSearchID == token else { return }
                var seen = Set<String>()
                hotelResults = Array(response.mapItems.compactMap { item -> HotelSuggestion? in
                    let point = item.placemark.coordinate
                    let distance = center.distance(from: CLLocation(latitude: point.latitude, longitude: point.longitude))
                    guard distance <= 3500, let name = item.name, !name.isEmpty else { return nil }
                    let id = "\(name)|\(point.latitude)|\(point.longitude)"
                    guard seen.insert(id).inserted else { return nil }
                    return HotelSuggestion(id: id, name: name, address: item.placemark.title ?? name,
                                           latitude: point.latitude, longitude: point.longitude,
                                           phone: item.phoneNumber, website: item.url?.absoluteString, distance: distance)
                }.sorted { $0.distance < $1.distance }.prefix(8))
                hotelSearching = false
                hotelSearchError = hotelResults.isEmpty
            } catch {
                guard hotelSearchID == token else { return }
                hotelSearching = false
                hotelSearchError = true
            }
        }
    }
    private var journeyOverview: some View {
        journeyPanel {
            Text(journeyText("order")).font(.title3.bold())
            Text("\(journeyText("finish")) · \(finishTime)").font(.subheadline)
            Text(journeyText("timeEstimate")).font(.caption).foregroundStyle(.secondary)
            ForEach(stages.indices, id: \.self) { index in
                Button { journeyIndex = index; journeyCompleted = false } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.subheadline.bold()).frame(width: 32, height: 32)
                            .foregroundStyle(index == journeyIndex ? Color.black : Color.white)
                            .background(index == journeyIndex ? journeyGold : Color(red: 0.15, green: 0.22, blue: 0.33), in: Circle())
                        VStack(alignment: .leading, spacing: 4) {
                            Text(stageTitle(stages[index])).font(.subheadline.bold())
                            if let stamp = stageTime(stages[index]) { Text(stamp).font(.caption).monospacedDigit() }
                            if index == journeyIndex { Text(journeyText("current")).font(.caption) }
                        }
                        Spacer(minLength: 0)
                        Image(systemName: stageSymbol(stages[index]))
                    }
                    .foregroundStyle(index == journeyIndex ? journeyGold : Color.white)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }.buttonStyle(.plain)
                if index < stages.count - 1 {
                    Image(systemName: "arrow.down").font(.caption).foregroundStyle(.secondary).padding(.leading, 10)
                }
            }
        }
    }
    private func travelPanel(origin: String?, destination: String, title: String, fromName: String, toName: String) -> some View {
        journeyPanel {
            Label(title, systemImage: "arrow.right.circle.fill").font(.headline).foregroundStyle(journeyGold)
            Text("\(fromName) → \(toName)").font(.headline)
            routeLinks(origin: origin, destination: destination)
            Text(extra("liveNote")).font(.footnote).foregroundStyle(.secondary)
        }
    }
    private var journeyNextEnabled: Bool {
        switch currentStage {
        case .departure, .hotelBeforeDinner: return !hotelQuery.isEmpty
        case .dinner: return dinnerSelection != nil
        case .hotelAfterDinner: return dinnerSelection != nil && !hotelQuery.isEmpty
        case .stop(let index):
            return !selectedVenue(index).name.hasPrefix("Lunch near ") || lunchSelection != nil
        default: return true
        }
    }
    private var journeyCurrent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("\(journeyText("current")) · \(journeyIndex + 1) / \(stages.count)")
                .font(.headline).foregroundStyle(journeyGold)
            switch currentStage {
            case .departure:
                if hotelQuery.isEmpty {
                    journeyPanel { Text(journeyText("enterHotel")) }
                } else {
                    travelPanel(origin: hotelQuery, destination: venueQuery(selectedVenue(0)), title: journeyText("firstDestination"), fromName: hotelName, toName: venueText(selectedVenue(0), 0))
                }
                DisclosureGroup(extra("arrival")) { arrivalCard.padding(.top, 10) }
            case .stop(let index):
                if selectedVenue(index).name.hasPrefix("Lunch near ") {
                    lunchCard(index)
                } else {
                    stopCard(index)
                }
                if index + 1 < route.stops.count &&
                    !selectedVenue(index + 1).name.hasPrefix("Lunch near ") &&
                    (!selectedVenue(index).name.hasPrefix("Lunch near ") || lunchSelection != nil) {
                    transferCard(index + 1)
                } else if index + 1 < route.stops.count && selectedVenue(index + 1).name.hasPrefix("Lunch near ") {
                    journeyPanel { Text(journeyText("lunchNext")).font(.headline).foregroundStyle(journeyGold) }
                } else if dinnerNearHotel && !hotelQuery.isEmpty {
                    travelPanel(origin: venueQuery(lastVenue), destination: hotelQuery, title: journeyText("nextHotel"), fromName: venueText(lastVenue, 0), toName: hotelName)
                } else if !dinnerNearHotel {
                    journeyPanel {
                        Text(journeyText("nextDinner")).font(.headline).foregroundStyle(journeyGold)
                        Text(journeyText("lateNote"))
                        Text(venueText(lastVenue, 0)).font(.subheadline.bold())
                    }
                }
            case .hotelBeforeDinner:
                if !hotelQuery.isEmpty {
                    travelPanel(origin: venueQuery(lastVenue), destination: hotelQuery, title: journeyText("returnHotel"), fromName: venueText(lastVenue, 0), toName: hotelName)
                } else { journeyPanel { Text(journeyText("enterHotel")) } }
                journeyPanel {
                    Text(journeyText("nextDinner")).font(.headline).foregroundStyle(journeyGold)
                    Text(journeyText("earlyNote"))
                }
            case .dinner:
                dinnerCard
            case .hotelAfterDinner:
                if let place = dinnerSelection, !hotelQuery.isEmpty {
                    travelPanel(origin: place.query, destination: hotelQuery, title: journeyText("afterDinner"), fromName: place.name, toName: hotelName)
                } else {
                    journeyPanel { Text(journeyText("selectDinnerHotel")) }
                }
                if journeyCompleted {
                    Label(journeyText("completed"), systemImage: "checkmark.circle.fill").font(.headline).foregroundStyle(journeyGold)
                }
            }
            if !journeyCompleted {
                journeyAction(journeyText(journeyIndex == stages.count - 1 ? "arrived" : "next")) {
                    if journeyIndex < stages.count - 1 { journeyIndex += 1 } else { journeyCompleted = true }
                }.disabled(!journeyNextEnabled).opacity(journeyNextEnabled ? 1 : 0.45)
            }
            if journeyIndex > 0 {
                Button(journeyText("previous")) { journeyIndex -= 1; journeyCompleted = false }
                    .font(.subheadline.bold()).frame(maxWidth: .infinity, minHeight: 44)
            }
        }
    }
    private var dinnerAreaPicker: some View {
        journeyPanel {
            Label(journeyText("dinnerPlan"), systemImage: "fork.knife").font(.headline)
            Text(journeyText("cutoffNote")).font(.footnote).foregroundStyle(.secondary)
            visibleChoice(journeyText("automatic"), selected: dinnerArea == "auto") { dinnerArea = "auto" }
            visibleChoice(journeyText("nearHotel"), selected: dinnerArea == "hotel") { dinnerArea = "hotel" }
            visibleChoice(journeyText("nearLast"), selected: dinnerArea == "last") { dinnerArea = "last" }
            Text(journeyText(dinnerNearHotel ? "earlyNote" : "lateNote")).font(.subheadline)
        }
    }
    private func lunchCard(_ index: Int) -> some View {
        let previous = selectedVenue(index - 1)
        let anchor = venueQuery(previous)
        return journeyPanel {
            Label(journeyText("lunchSearch"), systemImage: "fork.knife").font(.title3.bold())
            Text("\(venueText(previous, 0)) · \(journeyText("nearby"))")
                .font(.subheadline).foregroundStyle(.secondary)
            Text(journeyText("lunchNote")).font(.subheadline)
            journeyAction(journeyText("findLunch"), systemImage: "magnifyingglass") { searchLunch(near: anchor) }
                .disabled(lunchSearching)
            if lunchSearching { ProgressView(journeyText("searching")) }
            if lunchSearchError { Text(journeyText("searchFailure")).font(.subheadline) }
            if let url = locationURL("レストラン \(anchor)") {
                journeyLink(journeyText("moreDinner"), url: url)
            }
            ForEach(lunchResults) { place in
                VStack(alignment: .leading, spacing: 10) {
                    Text(place.name).font(.headline)
                    Text(place.address).font(.subheadline).foregroundStyle(.secondary)
                    if let url = locationURL(place.query) { journeyLink(journeyText("menuHours"), url: url) }
                    journeyAction(journeyText(lunchSelection?.id == place.id ? "selectedLunch" : "selectLunch"), systemImage: "checkmark.circle") {
                        lunchSelection = place
                    }
                }
                .padding(12)
                .background(Color(red: 0.15, green: 0.22, blue: 0.33), in: RoundedRectangle(cornerRadius: 12))
            }
            if let place = lunchSelection {
                Text("\(journeyText("selectedLunch")) · \(place.name)").font(.headline).foregroundStyle(journeyGold)
                routeLinks(origin: anchor, destination: place.query)
            }
            Text(journeyText("dinnerCheck")).font(.footnote).foregroundStyle(.secondary)
        }
    }
    @MainActor
    private func searchLunch(near anchor: String) {
        guard !lunchSearching else { return }
        let token = UUID()
        lunchSearchID = token
        lunchSearching = true
        lunchSearchError = false
        lunchResults = []
        Task { @MainActor in
            do {
                let anchorRequest = MKLocalSearch.Request()
                anchorRequest.naturalLanguageQuery = anchor
                let anchorResponse = try await MKLocalSearch(request: anchorRequest).start()
                guard lunchSearchID == token else { return }
                guard let first = anchorResponse.mapItems.first else {
                    lunchSearching = false; lunchSearchError = true; return
                }
                let coordinate = first.placemark.coordinate
                let center = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = "レストラン"
                request.resultTypes = .pointOfInterest
                request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.restaurant])
                request.region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 3000, longitudinalMeters: 3000)
                let response = try await MKLocalSearch(request: request).start()
                guard lunchSearchID == token else { return }
                var seen = Set<String>()
                lunchResults = Array(response.mapItems.compactMap { item -> DinnerPlace? in
                    let point = item.placemark.coordinate
                    let distance = center.distance(from: CLLocation(latitude: point.latitude, longitude: point.longitude))
                    guard distance <= 2000, let name = item.name, !name.isEmpty else { return nil }
                    let id = "\(name)|\(point.latitude)|\(point.longitude)"
                    guard seen.insert(id).inserted else { return nil }
                    return DinnerPlace(id: id, name: name, address: item.placemark.title ?? name,
                                       latitude: point.latitude, longitude: point.longitude, distance: distance)
                }.sorted { $0.distance < $1.distance }.prefix(8))
                lunchSearching = false
                lunchSearchError = lunchResults.isEmpty
            } catch {
                guard lunchSearchID == token else { return }
                lunchSearching = false
                lunchSearchError = true
            }
        }
    }
    private var dinnerCard: some View {
        journeyPanel {
            Label(journeyText(dinnerNearHotel ? "dinnerHotel" : "dinnerLast"), systemImage: "fork.knife").font(.title3.bold())
            Text(dinnerAnchorName).font(.subheadline.bold())
            Text(journeyText(dinnerNearHotel ? "earlyNote" : "lateNote")).font(.subheadline)
            if dinnerAnchorQuery.isEmpty {
                Text(journeyText("enterHotel")).foregroundStyle(journeyGold)
            } else {
                journeyAction(journeyText("findDinner"), systemImage: "magnifyingglass") { searchDinner() }
                    .disabled(dinnerSearching)
                if dinnerSearching { ProgressView(journeyText("searching")) }
                if dinnerSearchError { Text(journeyText("searchFailure")).font(.subheadline) }
                if let url = locationURL("レストラン \(dinnerAnchorQuery)") {
                    journeyLink(journeyText("moreDinner"), url: url)
                }
            }
            ForEach(dinnerResults) { place in
                VStack(alignment: .leading, spacing: 10) {
                    Text(place.name).font(.headline)
                    Text(place.address).font(.subheadline).foregroundStyle(.secondary)
                    Text(String(format: journeyText("distance"), locale: language.locale, arguments: [Int(place.distance.rounded())])).font(.caption).foregroundStyle(.secondary)
                    if let url = locationURL(place.query) { journeyLink(journeyText("menuHours"), url: url) }
                    journeyAction(journeyText(dinnerSelection?.id == place.id ? "selectedDinner" : "selectDinner"), systemImage: dinnerSelection?.id == place.id ? "checkmark.circle.fill" : "fork.knife") {
                        dinnerSelection = place
                    }
                }
                .padding(14)
                .background(Color(red: 0.15, green: 0.22, blue: 0.33), in: RoundedRectangle(cornerRadius: 12))
            }
            if let place = dinnerSelection {
                Divider()
                Text("\(journeyText("selectedDinner")) · \(place.name)").font(.headline).foregroundStyle(journeyGold)
                routeLinks(origin: dinnerNearHotel ? hotelQuery : venueQuery(lastVenue), destination: place.query)
                Text(journeyText("dinnerThenHotel")).font(.subheadline)
            }
            Text(journeyText("dinnerCheck")).font(.footnote).foregroundStyle(.secondary)
        }
    }
    @MainActor
    private func searchDinner() {
        guard !dinnerAnchorQuery.isEmpty, !dinnerSearching else { return }
        let anchor = dinnerAnchorQuery
        let token = UUID()
        dinnerSearchID = token
        dinnerSearching = true
        dinnerSearchError = false
        dinnerResults = []
        // Keep the previous selected restaurant until a new one is explicitly chosen.
        Task { @MainActor in
            do {
                let anchorRequest = MKLocalSearch.Request()
                anchorRequest.naturalLanguageQuery = anchor
                let anchorResponse = try await MKLocalSearch(request: anchorRequest).start()
                guard dinnerSearchID == token else { return }
                guard let centerItem = anchorResponse.mapItems.first else {
                    dinnerSearchError = true; dinnerSearching = false; return
                }
                let coordinate = centerItem.placemark.coordinate
                let center = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = "レストラン"
                request.resultTypes = .pointOfInterest
                request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.restaurant])
                request.region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 3000, longitudinalMeters: 3000)
                let response = try await MKLocalSearch(request: request).start()
                guard dinnerSearchID == token else { return }
                var seen = Set<String>()
                let places = response.mapItems.compactMap { item -> DinnerPlace? in
                    let point = item.placemark.coordinate
                    let distance = center.distance(from: CLLocation(latitude: point.latitude, longitude: point.longitude))
                    guard distance <= 2000, let name = item.name, !name.isEmpty else { return nil }
                    let id = "\(name)|\(point.latitude)|\(point.longitude)"
                    guard seen.insert(id).inserted else { return nil }
                    return DinnerPlace(id: id, name: name, address: item.placemark.title ?? name, latitude: point.latitude, longitude: point.longitude, distance: distance)
                }.sorted { $0.distance < $1.distance }
                dinnerResults = Array(places.prefix(8))
                dinnerSearchError = dinnerResults.isEmpty
                dinnerSearching = false
            } catch {
                guard dinnerSearchID == token else { return }
                dinnerSearching = false
                dinnerSearchError = true
            }
        }
    }

    private func extra(_ key: String) -> String {
        TravelExtras.ui[key]?[language.index] ?? key
    }
    private var cityQuery: String {
        ["asakusa": "Tokyo", "ueno": "Tokyo", "kyoto": "Kyoto", "osaka": "Osaka", "nara": "Nara", "hiroshima": "Hiroshima"][route.id] ?? "Japan"
    }
    private func venueQuery(_ venue: Venue) -> String {
        if venue.name.hasPrefix("Lunch near "), let place = lunchSelection { return place.query }
        // Japanese names avoid ambiguous translated or romanized businesses.
        let localName = FeaturedRoutes.names[venue.name]?[0] ?? GuideTranslations.venues[venue.name]?[0][0] ?? NationwideRoutes.japanesePlaces[venue.name] ?? venue.name
        let prefecture = NationwideRoutes.prefectures.first(where: { $0.id == routePrefecture })?.ja ?? "日本"
        return "\(localName), \(prefecture), Japan"
    }
    private func mapURL(origin: String? = nil, destination: String, mode: String) -> URL? {
        var parts = URLComponents(string: "https://www.google.com/maps/dir/")
        var items = [URLQueryItem(name: "api", value: "1"), URLQueryItem(name: "destination", value: destination), URLQueryItem(name: "travelmode", value: mode)]
        if let origin = origin { items.append(URLQueryItem(name: "origin", value: origin)) }
        parts?.queryItems = items
        return parts?.url
    }
    private func locationURL(_ query: String) -> URL? {
        var parts = URLComponents(string: "https://www.google.com/maps/search/")
        parts?.queryItems = [URLQueryItem(name: "api", value: "1"), URLQueryItem(name: "query", value: query)]
        return parts?.url
    }
    private func routeLinks(origin: String?, destination: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let url = mapURL(origin: origin, destination: destination, mode: "transit") {
                journeyLink(extra("transitRoute"), url: url, systemImage: "tram.fill")
            }
            if let url = mapURL(origin: origin, destination: destination, mode: "walking") {
                journeyLink(extra("walkRoute"), url: url, systemImage: "figure.walk")
            }
            if let url = mapURL(origin: origin, destination: destination, mode: "driving") {
                journeyLink(extra("driveRoute"), url: url, systemImage: "car.fill")
            }
        }
    }
    private var hotelSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(extra("hotels"), systemImage: "bed.double.fill").font(.title3.bold())
            Text(extra("hotelNote")).font(.footnote).foregroundStyle(.secondary)
            Text(extra("rateNote")).font(.footnote).foregroundStyle(.secondary)
            ForEach(TravelExtras.hotels[route.id] ?? []) { hotel in
                hotelCard(hotel)
            }
            Text(extra("checked")).font(.caption2).foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(red: 0.08, green: 0.17, blue: 0.22), in: RoundedRectangle(cornerRadius: 16))
    }
    private func hotelCard(_ hotel: NearbyHotel) -> some View {
        let first = selectedVenue(0)
        let name = hotel.names[language.index]
        let address = language == .ja ? hotel.addressJP : hotel.addressEN
        let query = "\(hotel.names[0]), \(hotel.addressJP), Japan"
        return VStack(alignment: .leading, spacing: 12) {
            Text(name).font(.headline)
            Text(address).font(.subheadline).foregroundStyle(.secondary)
            if let url = locationURL(query) {
                Link(destination: url) { Label(extra("hotelMap"), systemImage: "mappin.and.ellipse") }
            }
            if let url = URL(string: hotel.rateURL) {
                Link(destination: url) { Label(extra("rate"), systemImage: "yensign.circle.fill") }
                    .font(.subheadline.bold())
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(.black)
                    .background(.yellow, in: RoundedRectangle(cornerRadius: 10))
            }
            if let url = URL(string: "tel:\(hotel.phone)") {
                Link(destination: url) {
                    Label("\(extra("call")) · \(hotel.phoneDisplay)", systemImage: "phone.fill")
                }
            }
            if let url = URL(string: hotel.contactURL) {
                Link(destination: url) { Label(extra("contact"), systemImage: "globe") }
            }
            Divider()
            Text("\(extra("toFirst")) · \(venueText(first, 0))").font(.caption.bold())
            routeLinks(origin: query, destination: venueQuery(first))
        }
        .font(.subheadline)
        .fixedSize(horizontal: false, vertical: true)
        .padding(14)
        .background(journeySurface, in: RoundedRectangle(cornerRadius: 12))
    }
    private var arrivalCard: some View {
        let first = selectedVenue(0)
        return VStack(alignment: .leading, spacing: 12) {
            Label(extra("arrival"), systemImage: "location.fill").font(.headline)
            Text(venueText(first, 0)).font(.subheadline.bold())
            if selectedIndex(0) == 0 {
                Text(TravelExtras.arrivalText[route.id]?[language.index] ?? journeyText("newArrival"))
                    .font(.subheadline)
                if let value = TravelExtras.arrivalSources[route.id], let url = URL(string: value) {
                    translatedGuideLink(extra("officialAccess"), url: url)
                }
            } else {
                Text(extra("customArrival")).font(.subheadline)
            }
            routeLinks(origin: TravelExtras.arrivalOrigins[route.id], destination: venueQuery(first))
            Text(extra("liveNote")).font(.footnote).foregroundStyle(.secondary)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(16)
        .background(Color(red: 0.07, green: 0.20, blue: 0.20), in: RoundedRectangle(cornerRadius: 16))
    }
    private func transferCard(_ index: Int) -> some View {
        let from = selectedVenue(index - 1)
        let to = selectedVenue(index)
        let isOriginalPair = selectedIndex(index - 1) == 0 && selectedIndex(index) == 0
        let west = Set(["Sensoji Temple", "Asakusa Culture Tourist Information Center", "Nakamise Shopping Street", "Ramen Yoroiya", "Sushizanmai Asakusa Kaminarimon", "Asakusa Imahan"])
        let east = Set(["Tokyo Skytree", "Sumida Aquarium", "Postal Museum Japan", "Tokyo Solamachi"])
        return VStack(alignment: .leading, spacing: 12) {
            Label(journeyText("nextDestination"), systemImage: "arrow.down.circle.fill").font(.headline)
            Text("\(venueText(from, 0)) → \(venueText(to, 0))").font(.subheadline.bold())
            if let info = FeaturedRoutes.info[route.id] {
                Text(info.notes[language.index]).font(.subheadline)
            } else if isOriginalPair, let legs = TravelExtras.legs[route.id], legs.indices.contains(index - 1) {
                Text(legs[index - 1][language.index]).font(.subheadline)
            } else {
                Text(extra("walkFallback")).font(.subheadline)
            }
            if route.id == "asakusa" && west.contains(from.name) && east.contains(to.name) {
                Text(extra("asakusaRail")).font(.subheadline)
                if let url = URL(string: "https://www.tobu.co.jp/railway/guide/station/info/1103/") {
                    translatedGuideLink(extra("officialAccess"), url: url)
                }
            }
            Text(String(format: extra("planningGap"), locale: language.locale, arguments: [route.gap]))
                .font(.caption).foregroundStyle(.secondary)
            routeLinks(origin: venueQuery(from), destination: venueQuery(to))
            Text(extra("liveNote")).font(.footnote).foregroundStyle(.secondary)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(16)
        .background(Color(red: 0.07, green: 0.20, blue: 0.20), in: RoundedRectangle(cornerRadius: 16))
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(text("tagline")).font(.caption.bold()).tracking(2).foregroundStyle(.yellow)
            Text(text("headline")).font(.largeTitle.bold()).foregroundStyle(.white)
            Text(text("intro"))
                .foregroundStyle(.white.opacity(0.88))
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(22)
        .background(Color(red: 0.08, green: 0.17, blue: 0.22), in: RoundedRectangle(cornerRadius: 18))
    }

    private func featuredText(_ key: String) -> String { FeaturedRoutes.ui[key]?[language.index] ?? key }

    private func visibleChoice(_ title: String, selected: Bool, subtitle: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 9) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.subheadline.bold())
                    if let subtitle = subtitle { Text(subtitle).font(.caption) }
                }.fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
            }
            .padding(12).frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .foregroundStyle(selected ? Color.black : Color.white)
            .background(selected ? journeyGold : Color(red: 0.15, green: 0.22, blue: 0.33), in: RoundedRectangle(cornerRadius: 12))
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private func selectCourse(_ item: DayRoute) {
        guard routeID != item.id else { return }
        let pref = item.prefecture ?? NationwideRoutes.existingPrefectures[item.id] ?? "tokyo"
        prefectureID = pref
        regionID = NationwideRoutes.prefectures.first(where: { $0.id == pref })?.region ?? "kanto"
        routeID = item.id
        swapIndex = nil
        clearHotelSearch()
        resetJourney()
    }

    private func courseButton(_ item: DayRoute) -> some View {
        let outline = item.stops.filter { $0.type != "food" }.compactMap { $0.choices.first }.map { venueText($0, 0) }.joined(separator: " → ")
        return visibleChoice(routeText(item, 0), selected: routeID == item.id, subtitle: outline) { selectCourse(item) }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(featuredText("featured"), systemImage: "sparkles").font(.headline).foregroundStyle(journeyGold)
            Text(featuredText("featuredNote")).font(.caption).foregroundStyle(.secondary)
            ForEach(FeaturedRoutes.routes) { item in courseButton(item) }
            Divider()
            Text(journeyText("region")).font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 105), spacing: 8)], spacing: 8) {
                ForEach(NationwideRoutes.regions) { item in
                    visibleChoice(label(item.japanese, item.english), selected: regionID == item.id) { selectRegion(item.id) }
                }
            }
            Text(journeyText("prefecture")).font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 105), spacing: 8)], spacing: 8) {
                ForEach(prefecturesInRegion) { item in
                    visibleChoice(label(item.ja, item.en), selected: prefectureID == item.id) { selectPrefecture(item.id) }
                }
            }
            Text(text("route")).font(.headline)
            ForEach(routesInPrefecture) { item in courseButton(item) }
            Text(String(format: journeyText("courseCount"), locale: language.locale, arguments: [routesInPrefecture.count]))
                .font(.footnote).foregroundStyle(.secondary)
            Text(text("start")).font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 85), spacing: 8)], spacing: 8) {
                ForEach(Array(stride(from: 540, through: 840, by: 60)), id: \.self) { value in
                    visibleChoice(time(value), selected: startMinutes == value) { startMinutes = value }
                }
            }
            if let info = FeaturedRoutes.info[route.id] {
                Text(info.fields[language.index][2]).font(.subheadline)
                Text(info.notes[language.index]).font(.footnote).foregroundStyle(journeyGold)
                if let url = URL(string: info.accessURL) { translatedGuideLink(featuredText("access"), url: url) }
                if let url = URL(string: info.sourceURL) { translatedGuideLink(featuredText("source"), url: url) }
            }
        }
        .padding(14).background(journeySurface, in: RoundedRectangle(cornerRadius: 15))
    }

    private func stopCard(_ index: Int) -> some View {
        let stop = route.stops[index]
        let venue = selectedVenue(index)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(time(startOfStop(index))).font(.subheadline.bold()).monospacedDigit()
                Spacer()
                Text(text(stop.type == "food" ? "lunch" : stop.type == "walk" ? "walk" : stop.type == "break" ? "break" : "sight"))
                    .font(.caption2.bold()).tracking(1).foregroundStyle(.orange)
            }
            Text(venueText(venue, 0)).font(.title3.bold())
            Text(venueText(venue, 1)).font(.subheadline).foregroundStyle(.secondary)
            if language == .en {
                Text(guide.notes[venue.name] ?? text("check"))
                    .font(.footnote).padding(10).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 9))
            }
            HStack {
                Text(format("duration", duration(stop, venue: venue))).font(.caption).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 10) {
                if let url = URL(string: venue.url) {
                    translatedGuideLink(NationwideRoutes.japanesePlaces[venue.name] == nil ? text("details") : journeyText("placeMap"), url: url)
                }
                if stop.choices.count > 1 {
                    ForEach(stop.choices.indices, id: \.self) { choice in
                        let option = stop.choices[choice]
                        let used = route.stops.indices.contains { $0 != index && selectedVenue($0).name == option.name }
                        if !used {
                            visibleChoice(venueText(option, 0), selected: selectedIndex(index) == choice) { choose(choice, at: index) }
                        }
                    }
                }
            }
        }
        .padding(16).background(journeySurface, in: RoundedRectangle(cornerRadius: 16))
    }

    private func swapSheet(_ index: Int) -> some View {
        let stop = route.stops[index]
        let used = Set(route.stops.indices.filter { $0 != index }.map { selectedVenue($0).name })
        return NavigationStack {
            List(stop.choices.indices.filter { !used.contains(stop.choices[$0].name) }, id: \.self) { choice in
                let venue = stop.choices[choice]
                Button {
                    choose(choice, at: index)
                } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(venueText(venue, 0)).font(.headline)
                            if choice == selectedIndex(index) { Image(systemName: "checkmark.circle.fill") }
                        }
                        Text(venueText(venue, 1)).font(.subheadline).foregroundStyle(.secondary)
                        Text(format("duration", duration(stop, venue: venue)))
                            .font(.caption).foregroundStyle(.secondary)
                    }.padding(.vertical, 5)
                }.foregroundStyle(.primary)
            }
            .navigationTitle(text(stop.type == "food" ? "chooseLunch" : "chooseStop"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button(text("done")) { swapIndex = nil } }
        }
        .presentationDetents([.medium, .large])
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? { indices.contains(index) ? self[index] : nil }
}

// Language order: Japanese, Korean, simplified Chinese, English, Thai.
private enum GuideLanguage: String, CaseIterable, Identifiable {
    case ja, ko, zh, en, th
    var id: String { rawValue }
    var index: Int { Self.allCases.firstIndex(of: self) ?? 0 }
    var title: String {
        switch self {
        case .ja: return "日本語"
        case .ko: return "한국어"
        case .zh: return "中文"
        case .en: return "English"
        case .th: return "ไทย"
        }
    }
    var locale: Locale {
        Locale(identifier: ["ja_JP", "ko_KR", "zh_CN", "en_US", "th_TH"][index])
    }
}

private enum GuideTranslations {
    static let ui: [String: [String]] = [
        "welcome": ["案内の言語を選んでください", "안내 언어를 선택하세요", "请选择导览语言", "Choose your guide language", "เลือกภาษาสำหรับคู่มือ"],
        "home": ["言語選択", "언어 선택", "选择语言", "Languages", "เลือกภาษา"],
        "tagline": ["日本を見る・日本を味わう", "일본을 보고, 일본을 맛보다", "看日本・品味日本", "SEE JAPAN · TASTE JAPAN", "ชมญี่ปุ่น · ชิมญี่ปุ่น"],
        "headline": ["あなたに合わせて変わる、一日の旅。", "당신에게 맞춰 바뀌는 하루 여행.", "随你心意调整的一日旅行。", "A day that changes with you.", "ทริปหนึ่งวันที่ปรับได้ตามใจคุณ"],
        "intro": ["コースを選び、観光地や昼食を入れ替えると、予定時刻がすぐに更新されます。", "코스를 고르고 관광지나 점심을 바꾸면 예정 시간이 바로 업데이트됩니다.", "选择路线，更换景点或午餐，行程时间即刻更新。", "Pick a route. Swap a sight or lunch. Your times update instantly.", "เลือกเส้นทาง เปลี่ยนสถานที่หรือมื้อกลางวัน เวลาในแผนจะปรับทันที"],
        "route": ["観光コース", "여행 코스", "观光路线", "City route", "เส้นทางท่องเที่ยว"],
        "start": ["出発時刻", "출발 시간", "出发时间", "Start time", "เวลาเริ่ม"],
        "summary": ["%@・%dか所・%@頃に終了", "%@ · %d곳 · %@쯤 종료", "%@・%d站・约%@结束", "%@ · %d stops · around %@ finish", "%@ · %d จุด · เสร็จประมาณ %@"],
        "gap": ["次の場所まで約%d分", "다음 장소까지 약 %d분", "到下一站约%d分钟", "Allow about %d min to the next stop", "เผื่อเวลาประมาณ %d นาทีไปจุดถัดไป"],
        "duration": ["滞在の目安：約%d分", "예상 체류 시간: 약 %d분", "建议停留：约%d分钟", "About %d min", "ใช้เวลาประมาณ %d นาที"],
        "footer": ["時刻と移動時間は計画用の目安です。出発前に営業時間、チケット、予約、移動経路を公式ページで確認してください。リンク先の言語は各施設のサイトによって異なります。", "시간과 이동 간격은 계획용 예상치입니다. 출발 전에 공식 페이지에서 영업시간, 입장권, 예약과 경로를 확인하세요. 링크의 언어는 각 시설 사이트에 따라 다릅니다.", "时间与交通间隔为规划参考。出发前请在官网确认营业时间、门票、预约和路线。链接页面的语言因设施网站而异。", "Times and transfer gaps are planning estimates. Check opening hours, tickets, reservations and routes before travelling. Linked pages use the languages provided by each venue.", "เวลาและช่วงการเดินทางเป็นค่าประมาณสำหรับวางแผน ก่อนออกเดินทางให้ตรวจสอบเวลาเปิด ตั๋ว การจอง และเส้นทางจากเว็บไซต์ทางการ ภาษาของหน้าลิงก์ขึ้นอยู่กับแต่ละสถานที่"],
        "share": ["この旅程を共有", "이 일정 공유", "分享此行程", "Share this itinerary", "แชร์แผนการเดินทางนี้"],
        "details": ["公式情報", "공식 정보", "官方信息", "Official details", "ข้อมูลทางการ"],
        "swap": ["入れ替える", "변경", "更换", "Swap", "เปลี่ยน"],
        "lunch": ["昼食", "점심", "午餐", "LUNCH", "มื้อกลางวัน"],
        "walk": ["散策", "산책", "漫步", "EXPLORE", "เดินสำรวจ"],
        "sight": ["観光", "관광", "观光", "SIGHT", "เที่ยวชม"],
        "break": ["休憩・散策", "휴식·산책", "休息・散步", "AFTERNOON", "พักและเดินเล่น"],
        "chooseLunch": ["昼食を選ぶ", "점심 선택", "选择午餐", "Choose lunch", "เลือกมื้อกลางวัน"],
        "chooseStop": ["立ち寄り先を変更", "방문 장소 변경", "更换景点", "Swap this stop", "เปลี่ยนสถานที่"],
        "done": ["完了", "완료", "完成", "Done", "เสร็จสิ้น"],
        "check": ["訪問前に現地の情報を確認してください。", "방문 전에 현지 정보를 확인하세요.", "参观前请确认当地信息。", "Check local information before visiting.", "ตรวจสอบข้อมูลท้องถิ่นก่อนเยี่ยมชม"],
        "sharedNote": ["時刻は目安です。営業時間と移動経路を確認してください。", "시간은 예상치입니다. 영업시간과 이동 경로를 확인하세요.", "时间为估算，请确认营业时间和路线。", "Timing is an estimate. Confirm hours and travel before visiting.", "เวลาเป็นค่าประมาณ โปรดตรวจสอบเวลาเปิดและเส้นทาง"]
    ]
    static let routes: [String: [[String]]] = [
        "asakusa": [
            ["東京・浅草からスカイツリー", "古い東京、新しい眺め", "寺院、地元の食事、街を見渡す景色を楽しむ一日。", "浅草・押上"],
            ["도쿄 · 아사쿠사에서 스카이트리", "옛 도쿄와 새로운 전망", "사찰, 지역 음식과 도시 전망을 즐기는 하루.", "아사쿠사·오시아게"],
            ["东京・浅草至晴空塔", "古老东京，全新天际线", "寺院、当地美食与城市全景的一日游。", "浅草・押上"],
            ["Tokyo · Asakusa to Skytree", "Old Tokyo, new skyline", "Temples, local food and a view across the city.", "Asakusa & Oshiage"],
            ["โตเกียว · อาซากุสะถึงสกายทรี", "โตเกียวเก่าและวิวเมืองใหม่", "หนึ่งวันกับวัด อาหารท้องถิ่น และวิวทั่วเมือง", "อาซากุสะและโอชิอาเกะ"]
        ],
        "ueno": [
            ["東京・上野の文化と食事", "美術、公園、おいしい昼食", "ラーメン、寿司、日本料理から昼食を選べる文化散策。", "上野"],
            ["도쿄 · 우에노의 문화와 음식", "미술, 공원과 맛있는 점심", "라멘, 초밥 또는 일본 요리를 고르는 문화 산책.", "우에노"],
            ["东京・上野文化与美食", "艺术、公园与美味午餐", "文化漫步，午餐可选择拉面、寿司或传统日本料理。", "上野"],
            ["Tokyo · Ueno culture and food", "Art, park and a good lunch", "A compact culture day with a choice of ramen, sushi or classic dining.", "Ueno"],
            ["โตเกียว · วัฒนธรรมและอาหารในอุเอโนะ", "ศิลปะ สวน และมื้อกลางวันอร่อย", "เที่ยวชมวัฒนธรรมพร้อมเลือกราเมน ซูชิ หรืออาหารญี่ปุ่นสำหรับมื้อกลางวัน", "อุเอโนะ"]
        ],
        "kyoto": [
            ["京都・清水寺から祇園", "京都の路地と寺院", "東山を歩き、祇園へ向かう途中で昼食を選ぶ一日。", "東山・祇園"],
            ["교토 · 기요미즈에서 기온", "교토 골목과 사찰", "히가시야마를 걸으며 기온으로 가는 길에 점심을 고르는 하루.", "히가시야마·기온"],
            ["京都・清水寺至祇园", "京都街巷与寺院", "漫步东山，在前往祇园的途中选择午餐。", "东山・祇园"],
            ["Kyoto · Kiyomizu to Gion", "Kyoto lanes and temple gates", "A walking day through Higashiyama, with lunch choices on the way to Gion.", "Higashiyama & Gion"],
            ["เกียวโต · คิโยมิซุถึงกิอง", "ตรอกและวัดแห่งเกียวโต", "เดินเที่ยวฮิกาชิยามะและเลือกมื้อกลางวันระหว่างทางไปกิอง", "ฮิกาชิยามะและกิอง"]
        ],
        "osaka": [
            ["大阪・難波と道頓堀", "大阪の食と街の明かり", "市場、道具の商店街、川沿いのにぎわいを楽しむ一日。", "難波・道頓堀"],
            ["오사카 · 난바와 도톤보리", "오사카 먹거리와 네온", "시장, 조리 도구 상점가와 활기찬 강변을 즐기는 하루.", "난바·도톤보리"],
            ["大阪・难波与道顿堀", "大阪美食与霓虹", "探索市场、厨具街，在热闹的河岸结束行程。", "难波・道顿堀"],
            ["Osaka · Namba and Dotonbori", "Osaka street food and neon", "Markets, cookware streets and a lively canal-side finish.", "Namba & Dotonbori"],
            ["โอซาก้า · นัมบะและโดทงโบริ", "อาหารและแสงไฟแห่งโอซาก้า", "เที่ยวตลาด ถนนเครื่องครัว และปิดท้ายริมคลองที่คึกคัก", "นัมบะและโดทงโบริ"]
        ],
        "nara": [
            ["奈良・大仏と古い町並み", "奈良の寺院と旧市街", "大仏、庭園、地元の食事を楽しみながら、ならまちへ。", "奈良公園・ならまち"],
            ["나라 · 대불과 옛 거리", "나라 사찰과 구시가지", "대불, 정원과 지역 음식을 즐기며 나라마치로 걷는 하루.", "나라 공원·나라마치"],
            ["奈良・大佛与旧街", "奈良寺院与古老街巷", "参观大佛和庭园，品尝当地美食，漫步至奈良町。", "奈良公园・奈良町"],
            ["Nara · Great Buddha and old town", "Nara temples and old streets", "The Great Buddha, a garden and a local food break on a walk toward Naramachi.", "Nara Park & Naramachi"],
            ["นารา · พระใหญ่และย่านเก่า", "วัดและถนนเก่าของนารา", "ชมพระใหญ่ สวน และชิมอาหารท้องถิ่นระหว่างเดินไปนารามาจิ", "สวนนาราและนารามาจิ"]
        ],
        "hiroshima": [
            ["広島・平和公園と庭園", "広島で考える、再生への歩み", "追悼の場、地元の昼食、城跡、庭園を巡る一日。", "広島中心部"],
            ["히로시마 · 평화공원과 정원", "히로시마, 성찰과 재생", "추모 장소, 지역 점심, 성터와 정원을 돌아보는 하루.", "히로시마 중심부"],
            ["广岛・和平公园与庭园", "广岛，反思与重生", "参观追悼场所，享用当地午餐，游览城址与庭园。", "广岛市中心"],
            ["Hiroshima · Peace Park and gardens", "Hiroshima, reflection and renewal", "Time for the memorial sites, local lunch, castle grounds and a garden.", "Central Hiroshima"],
            ["ฮิโรชิมะ · สวนสันติภาพและสวนญี่ปุ่น", "ฮิโรชิมะ การรำลึกและการฟื้นฟู", "เยี่ยมชมอนุสรณ์ ชิมอาหารท้องถิ่น เดินบริเวณปราสาทและสวน", "ใจกลางฮิโรชิมะ"]
        ]
    ]
    static let venues: [String: [[String]]] = [
        "Sensoji Temple": [
            ["浅草寺", "東京を代表する歴史ある寺院。参道を歩く時間も確保しましょう。"],
            ["센소지", "도쿄를 대표하는 오래된 사찰입니다. 참배길을 걷는 시간도 확보하세요."],
            ["浅草寺", "东京著名的历史寺院。请预留步行参道的时间。"],
            ["วัดเซ็นโซจิ", "วัดเก่าแก่ที่มีชื่อเสียงของโตเกียว เผื่อเวลาเดินตามทางเข้าวัดด้วย"]
        ],
        "Asakusa Culture Tourist Information Center": [
            ["浅草文化観光センター", "浅草の眺めと観光案内。出発前に地図や最新情報を確認できます。"],
            ["아사쿠사 문화관광센터", "전망과 관광 안내를 이용할 수 있습니다. 출발 전에 지도와 최신 정보를 확인하세요."],
            ["浅草文化观光中心", "欣赏景色并获取旅游信息。出发前可查看地图和最新建议。"],
            ["ศูนย์วัฒนธรรมและข้อมูลท่องเที่ยวอาซากุสะ", "ชมวิวและรับข้อมูลท่องเที่ยว ตรวจสอบแผนที่และข้อมูลล่าสุดก่อนออกเดิน"]
        ],
        "Nakamise Shopping Street": [
            ["仲見世商店街", "お菓子や伝統的なお土産を探せます。営業時間は店ごとに異なります。"],
            ["나카미세 상점가", "간식과 전통 기념품을 둘러보세요. 가게마다 영업시간이 다릅니다."],
            ["仲见世商店街", "品尝小吃、选购传统纪念品。各店营业时间不同。"],
            ["ถนนนากามิเสะ", "เลือกซื้อขนมและของฝากแบบดั้งเดิม เวลาเปิดของแต่ละร้านแตกต่างกัน"]
        ],
        "Sumida Park": [
            ["隅田公園", "川沿いの景色を楽しむ屋外スポット。天候に合わせて予定を調整しましょう。"],
            ["스미다 공원", "강변 풍경을 즐기는 야외 코스입니다. 날씨에 맞춰 일정을 조정하세요."],
            ["隅田公园", "欣赏河岸景色的户外景点。请根据天气调整行程。"],
            ["สวนสุมิดะ", "จุดชมวิวริมแม่น้ำกลางแจ้ง ปรับแผนให้เหมาะกับสภาพอากาศ"]
        ],
        "Ramen Yoroiya": [
            ["浅草らーめん 与ろゐ屋", "浅草寺近くの和風ラーメン。行列の待ち時間を見込んでください。"],
            ["요로이야 라멘", "센소지 근처의 일본식 라멘집입니다. 대기 시간을 고려하세요."],
            ["与ろゐ屋拉面", "浅草寺附近的日式拉面店。请预留排队时间。"],
            ["ราเมนโยโรอิยะ", "ราเมนแบบญี่ปุ่นใกล้วัดเซ็นโซจิ เผื่อเวลารอคิว"]
        ],
        "Sushizanmai Asakusa Kaminarimon": [
            ["すしざんまい 浅草雷門店", "雷門近くで寿司を楽しめます。メニューや待ち時間を店頭で確認しましょう。"],
            ["스시잔마이 아사쿠사 가미나리몬점", "가미나리몬 근처에서 초밥을 즐길 수 있습니다. 메뉴와 대기 시간을 확인하세요."],
            ["寿司三昧 浅草雷门店", "雷门附近的寿司店。请在店内确认菜单和等候时间。"],
            ["ซูชิซันไม สาขาอาซากุสะคามินาริมง", "ร้านซูชิใกล้ประตูคามินาริมง ตรวจสอบเมนูและเวลารอที่ร้าน"]
        ],
        "Asakusa Imahan": [
            ["浅草今半", "すき焼きと日本料理。予約の確認と、ゆっくり食事をする時間を確保しましょう。"],
            ["아사쿠사 이마한", "스키야키와 일본 요리를 즐기는 곳입니다. 예약을 확인하고 식사 시간을 넉넉히 잡으세요."],
            ["浅草今半", "提供寿喜烧与日本料理。请确认预约，并留出充足用餐时间。"],
            ["อาซากุสะอิมาฮัน", "สุกี้ยากี้และอาหารญี่ปุ่น ตรวจสอบการจองและเผื่อเวลารับประทานอาหาร"]
        ],
        "Tokyo Skytree": [
            ["東京スカイツリー", "展望台から東京を一望できます。移動前に入場券を確認しましょう。"],
            ["도쿄 스카이트리", "전망대에서 도시를 한눈에 볼 수 있습니다. 이동 전에 입장권을 확인하세요."],
            ["东京晴空塔", "从观景台俯瞰东京。出发前请确认门票。"],
            ["โตเกียวสกายทรี", "ชมเมืองจากจุดชมวิว ตรวจสอบตั๋วเข้าชมก่อนเดินทาง"]
        ],
        "Sumida Aquarium": [
            ["すみだ水族館", "スカイツリータウン内の水族館。別途入場料が必要です。"],
            ["스미다 수족관", "스카이트리 타운 안에 있는 수족관입니다. 별도의 입장료가 필요합니다."],
            ["墨田水族馆", "位于晴空塔城内的水族馆。需另购门票。"],
            ["พิพิธภัณฑ์สัตว์น้ำสุมิดะ", "อยู่ภายในสกายทรีทาวน์ ต้องซื้อตั๋วเข้าชมแยกต่างหาก"]
        ],
        "Postal Museum Japan": [
            ["郵政博物館", "スカイツリータウンで郵便の歴史を学べます。開館日を確認しましょう。"],
            ["우정박물관", "스카이트리 타운에서 우편의 역사를 알아보세요. 개관일을 확인하세요."],
            ["邮政博物馆", "在晴空塔城了解邮政历史。请确认开放日期。"],
            ["พิพิธภัณฑ์ไปรษณีย์ญี่ปุ่น", "เรียนรู้ประวัติไปรษณีย์ในสกายทรีทาวน์ ตรวจสอบวันเปิดให้บริการ"]
        ],
        "Tokyo Solamachi": [
            ["東京ソラマチ", "スカイツリーと同じ施設で買い物や食事。最後の予定を柔軟に調整できます。"],
            ["도쿄 소라마치", "스카이트리와 같은 단지에서 쇼핑과 식사를 즐기며 일정을 마무리하세요."],
            ["东京晴空街道", "与晴空塔同一园区内的购物和餐饮区，适合灵活安排行程末站。"],
            ["โตเกียวโซลามาจิ", "แหล่งช้อปปิ้งและอาหารในบริเวณสกายทรี เหมาะสำหรับปรับแผนช่วงท้ายอย่างยืดหยุ่น"]
        ],
        "Tokyo Mizumachi": [
            ["東京ミズマチ", "浅草とスカイツリーの間にある川沿いの商業施設。徒歩の経路を確認しましょう。"],
            ["도쿄 미즈마치", "아사쿠사와 스카이트리 사이의 강변 상업시설입니다. 도보 경로를 확인하세요."],
            ["东京水町", "浅草与晴空塔之间的河岸商业区。请确认步行路线。"],
            ["โตเกียวมิซุมาจิ", "แหล่งร้านค้าริมแม่น้ำระหว่างอาซากุสะกับสกายทรี ตรวจสอบเส้นทางเดิน"]
        ],
        "Tokyo National Museum": [
            ["東京国立博物館", "日本とアジアの美術・考古資料。見たい展示館を事前に選びましょう。"],
            ["도쿄 국립박물관", "일본과 아시아의 미술 및 고고학 자료를 전시합니다. 보고 싶은 전시관을 미리 고르세요."],
            ["东京国立博物馆", "展示日本及亚洲艺术与考古藏品。请提前选择想看的展馆。"],
            ["พิพิธภัณฑ์แห่งชาติโตเกียว", "ศิลปะและโบราณคดีของญี่ปุ่นและเอเชีย เลือกอาคารจัดแสดงที่อยากชมล่วงหน้า"]
        ],
        "National Museum of Nature and Science": [
            ["国立科学博物館", "自然や科学の展示。見たい展示室を絞ると無理なく回れます。"],
            ["국립과학박물관", "자연과 과학을 탐험하세요. 관심 있는 전시실을 정하면 편하게 둘러볼 수 있습니다."],
            ["国立科学博物馆", "探索自然与科学。选择重点展厅，参观更从容。"],
            ["พิพิธภัณฑ์ธรรมชาติและวิทยาศาสตร์แห่งชาติ", "สำรวจธรรมชาติและวิทยาศาสตร์ เลือกห้องจัดแสดงที่สนใจเพื่อชมอย่างสบาย ๆ"]
        ],
        "National Museum of Western Art": [
            ["国立西洋美術館", "上野公園の西洋美術コレクション。展示内容とチケットを確認しましょう。"],
            ["국립서양미술관", "우에노 공원의 서양 미술 컬렉션입니다. 전시와 입장권 정보를 확인하세요."],
            ["国立西洋美术馆", "上野公园内的西洋艺术收藏。请确认展览和门票。"],
            ["พิพิธภัณฑ์ศิลปะตะวันตกแห่งชาติ", "ชมงานศิลปะตะวันตกในสวนอุเอโนะ ตรวจสอบนิทรรศการและตั๋ว"]
        ],
        "Ueno Park": [
            ["上野公園", "庭園や文化施設をつなぐ散策路。屋外なので天候に合わせて回りましょう。"],
            ["우에노 공원", "정원과 문화시설을 잇는 야외 산책길입니다. 날씨를 고려하세요."],
            ["上野公园", "连接花园与文化设施的户外步道。请考虑天气。"],
            ["สวนอุเอโนะ", "ทางเดินกลางแจ้งเชื่อมสวนและสถานที่ทางวัฒนธรรม คำนึงถึงสภาพอากาศ"]
        ],
        "Ameyoko Shopping Street": [
            ["アメ横商店街", "上野駅近くのにぎやかな商店街。小さな店や飲食店が並びます。"],
            ["아메요코 상점가", "우에노역 근처의 활기찬 거리입니다. 작은 가게와 음식점이 늘어서 있습니다."],
            ["阿美横商店街", "上野站附近热闹的街道，有许多小店和餐饮摊位。"],
            ["ถนนอาเมโยโกะ", "ถนนคึกคักใกล้สถานีอุเอโนะ มีร้านค้าเล็ก ๆ และร้านอาหารมากมาย"]
        ],
        "Inshotei": [
            ["韻松亭", "上野公園で季節の日本料理。ゆっくり食事をする時間を見込みましょう。"],
            ["인쇼테이", "우에노 공원에서 계절 일본 요리를 즐기세요. 식사 시간을 넉넉히 잡으세요."],
            ["韵松亭", "在上野公园享用时令日本料理。请留出充足用餐时间。"],
            ["อินโชเท", "อาหารญี่ปุ่นตามฤดูกาลในสวนอุเอโนะ เผื่อเวลารับประทานอาหารอย่างผ่อนคลาย"]
        ],
        "Sushizanmai Ueno": [
            ["すしざんまい 上野店", "上野駅周辺の寿司店。次の博物館訪問に間に合うよう待ち時間を確認しましょう。"],
            ["스시잔마이 우에노점", "우에노역 주변의 초밥집입니다. 다음 박물관 방문 전에 대기 시간을 확인하세요."],
            ["寿司三昧 上野店", "上野站周边的寿司店。为后续博物馆行程预留等候时间。"],
            ["ซูชิซันไม สาขาอุเอโนะ", "ร้านซูชิใกล้สถานีอุเอโนะ ตรวจสอบเวลารอก่อนเข้าชมพิพิธภัณฑ์ตามแผน"]
        ],
        "IPPUDO Ueno-hirokoji": [
            ["一風堂 上野広小路店", "商店街近くのラーメン店。営業時間を確認しましょう。"],
            ["잇푸도 우에노히로코지점", "상점가 근처의 라멘집입니다. 영업시간을 확인하세요."],
            ["一风堂 上野广小路店", "商店街附近的拉面店。请确认营业时间。"],
            ["อิปปุโด สาขาอุเอโนะฮิโรโคจิ", "ร้านราเมนใกล้ย่านร้านค้า ตรวจสอบเวลาเปิดให้บริการ"]
        ],
        "Tokyo Metropolitan Art Museum": [
            ["東京都美術館", "上野公園で展覧会を楽しめます。展示内容と入場券の要否を確認しましょう。"],
            ["도쿄도 미술관", "우에노 공원에서 전시를 즐길 수 있습니다. 전시 내용과 입장권 필요 여부를 확인하세요."],
            ["东京都美术馆", "在上野公园欣赏展览。请确认展览内容及是否需要门票。"],
            ["พิพิธภัณฑ์ศิลปะมหานครโตเกียว", "ชมนิทรรศการในสวนอุเอโนะ ตรวจสอบรายการจัดแสดงและการใช้ตั๋ว"]
        ],
        "Shinobazu Pond": [
            ["不忍池", "水辺でゆったり散策。残り時間に合わせて歩く道を選べます。"],
            ["시노바즈 연못", "물가에서 여유롭게 걸으세요. 남은 시간에 맞춰 길을 고를 수 있습니다."],
            ["不忍池", "悠闲的水边散步。可根据剩余时间选择步道。"],
            ["บึงชิโนบาซุ", "เดินเล่นริมบึงอย่างผ่อนคลาย เลือกทางเดินตามเวลาที่เหลือ"]
        ],
        "Ueno Toshogu Shrine": [
            ["上野東照宮", "上野公園内の歴史ある神社。内部の拝観を希望する場合は公開範囲を確認しましょう。"],
            ["우에노 도쇼구", "우에노 공원의 역사 깊은 신사입니다. 내부 관람을 원하면 공개 범위를 확인하세요."],
            ["上野东照宫", "上野公园内的历史神社。如需参观内部，请确认开放范围。"],
            ["ศาลเจ้าอุเอโนะโทโชกู", "ศาลเจ้าเก่าแก่ในสวนอุเอโนะ ตรวจสอบพื้นที่ที่เปิดให้เข้าชมหากต้องการชมด้านใน"]
        ],
        "Kiyomizu-dera Temple": [
            ["清水寺", "丘の上の寺院と京都の眺め。上り坂の移動時間も確保しましょう。"],
            ["기요미즈데라", "언덕 위 사찰과 교토 전망을 즐기세요. 오르막 이동 시간도 확보하세요."],
            ["清水寺", "山坡上的寺院与京都景色。请预留上坡步行时间。"],
            ["วัดคิโยมิซุเดระ", "วัดบนเนินเขาพร้อมวิวเกียวโต เผื่อเวลาเดินขึ้นเนินด้วย"]
        ],
        "Kodai-ji Temple": [
            ["高台寺", "歴史ある堂宇と庭園。拝観料や特別公開の時間を確認しましょう。"],
            ["고다이지", "역사 깊은 사찰과 정원입니다. 입장료와 특별 개방 시간을 확인하세요."],
            ["高台寺", "历史殿堂与庭园。请确认参观费用及特别开放时间。"],
            ["วัดโคไดจิ", "อาคารวัดเก่าแก่และสวน ตรวจสอบค่าเข้าชมและช่วงเปิดพิเศษ"]
        ],
        "Sannenzaka and Ninenzaka": [
            ["産寧坂・二寧坂", "歴史ある坂道とお店。階段や混雑があるため歩きやすい靴がおすすめです。"],
            ["산넨자카·니넨자카", "전통 거리와 상점을 둘러보세요. 계단과 인파가 있어 편한 신발이 좋습니다."],
            ["三年坂・二年坂", "历史坡道和街边店铺。台阶多且人流密集，建议穿舒适的鞋。"],
            ["ซันเน็นซากะและนิเน็นซากะ", "ถนนลาดชันเก่าแก่และร้านค้า มีบันไดและคนมาก ควรสวมรองเท้าที่เดินสบาย"]
        ],
        "Yasaka Pagoda streets": [
            ["八坂の塔周辺", "京都の町並みにそびえる塔。公道から見学し、通行を妨げないようにしましょう。"],
            ["야사카의 탑 주변", "교토 골목에 솟은 탑을 공공 도로에서 감상하세요. 통행을 방해하지 마세요."],
            ["八坂之塔周边", "在京都旧街欣赏古塔。请从公共道路观赏，勿妨碍通行。"],
            ["บริเวณเจดีย์ยาซากะ", "ชมเจดีย์ท่ามกลางตรอกเกียวโตจากถนนสาธารณะ อย่ากีดขวางทางเดิน"]
        ],
        "Gion Tempura Endo": [
            ["八坂圓堂", "八坂の塔近くで天ぷら。食事時間を多めに取り、昼の予約を確認しましょう。"],
            ["기온 덴푸라 엔도", "야사카의 탑 근처에서 덴푸라를 즐기세요. 점심 예약과 식사 시간을 확인하세요."],
            ["八坂圆堂", "八坂之塔附近的天妇罗店。请确认午餐预约并留出用餐时间。"],
            ["กิองเท็มปุระเอ็นโด", "เท็มปุระใกล้เจดีย์ยาซากะ ตรวจสอบการจองมื้อกลางวันและเผื่อเวลารับประทาน"]
        ],
        "Gion Izuju": [
            ["祇園いづう", "八坂神社近くの京寿司。一般的な握り寿司とは異なるためメニューを確認しましょう。"],
            ["기온 이즈주", "야사카 신사 옆의 교토식 초밥집입니다. 일반 니기리와 달라 메뉴를 확인하세요."],
            ["祇园伊豆重", "八坂神社旁的京都风味寿司。与常见握寿司不同，请先查看菜单。"],
            ["กิองอิซูจู", "ซูชิแบบเกียวโตข้างศาลเจ้ายาซากะ ต่างจากนิกิริทั่วไป ควรดูเมนูก่อนเลือก"]
        ],
        "ICHIRAN Kyoto Kawaramachi": [
            ["一蘭 京都河原町店", "祇園の川向こうで豚骨ラーメン。観光地からの徒歩時間を多めに見込みましょう。"],
            ["이치란 교토 가와라마치점", "기온의 강 건너편에서 돈코츠 라멘을 즐기세요. 도보 시간을 넉넉히 잡으세요."],
            ["一兰 京都河原町店", "祇园河对岸的豚骨拉面店。请预留较多步行时间。"],
            ["อิจิรัน สาขาเกียวโตคาวารามาจิ", "ราเมนน้ำซุปกระดูกหมูอีกฝั่งแม่น้ำจากกิอง เผื่อเวลาเดินเพิ่ม"]
        ],
        "Yasaka-jinja Shrine": [
            ["八坂神社", "祇園の入口にある神社。参拝者や現地の案内に配慮しましょう。"],
            ["야사카 신사", "기온 입구의 신사입니다. 참배객과 현장 안내를 존중하세요."],
            ["八坂神社", "祇园入口的神社。请尊重参拜者并遵守现场指示。"],
            ["ศาลเจ้ายาซากะ", "ศาลเจ้าตรงทางเข้ากิอง เคารพผู้มาสักการะและปฏิบัติตามป้ายแนะนำ"]
        ],
        "Kennin-ji Temple": [
            ["建仁寺", "祇園の禅寺と庭園。拝観時間を確認し、庭園を見る時間も確保しましょう。"],
            ["겐닌지", "기온의 선종 사찰과 정원입니다. 관람시간을 확인하고 정원도 여유롭게 둘러보세요."],
            ["建仁寺", "祇园的禅寺与庭园。请确认开放时间，并留出庭园参观时间。"],
            ["วัดเค็นนินจิ", "วัดเซนและสวนในกิอง ตรวจสอบเวลาเข้าชมและเผื่อเวลาเดินชมสวน"]
        ],
        "Gion lanes": [
            ["祇園の町並み", "伝統建築と公道の散策。私有地への立入や撮影のルールを守りましょう。"],
            ["기온 골목", "전통 건축과 공공 도로를 산책하세요. 사유지 출입과 촬영 규칙을 지켜주세요."],
            ["祇园街巷", "沿公共街道欣赏传统建筑。请遵守私有区域和拍摄规定。"],
            ["ตรอกกิอง", "ชมสถาปัตยกรรมดั้งเดิมจากถนนสาธารณะ เคารพพื้นที่ส่วนบุคคลและกฎการถ่ายภาพ"]
        ],
        "Kamo River promenade": [
            ["鴨川の遊歩道", "祇園四条近くの川沿いで一日を締めくくる屋外散策。"],
            ["가모강 산책로", "기온시조 근처 강변에서 하루를 마무리하는 야외 산책 코스입니다."],
            ["鸭川步道", "在祇园四条附近的河岸散步，为一天画上句号。"],
            ["ทางเดินริมแม่น้ำคาโมะ", "เดินเล่นกลางแจ้งริมแม่น้ำใกล้กิองชิโจเพื่อปิดท้ายวัน"]
        ],
        "Kuromon Market": [
            ["黒門市場", "大阪の歴史ある食の市場。営業は店ごとに異なり、飲食は指定された場所で。"],
            ["구로몬 시장", "오사카의 역사 깊은 먹거리 시장입니다. 가게별 영업시간과 취식 장소를 확인하세요."],
            ["黑门市场", "大阪历史悠久的美食市场。各摊营业时间不同，请在允许的区域用餐。"],
            ["ตลาดคุโรมง", "ตลาดอาหารเก่าแก่ของโอซาก้า แต่ละร้านเปิดต่างเวลา รับประทานในพื้นที่ที่ร้านอนุญาต"]
        ],
        "Namba Yasaka Shrine": [
            ["難波八阪神社", "大きな獅子殿が特徴の神社。黒門市場より西側なので移動時間を確保しましょう。"],
            ["난바 야사카 신사", "커다란 사자 모양 전각이 특징입니다. 구로몬보다 서쪽이므로 이동 시간을 확보하세요."],
            ["难波八阪神社", "巨大的狮子殿是特色。位于黑门市场以西，请预留交通时间。"],
            ["ศาลเจ้านัมบะยาซากะ", "โดดเด่นด้วยอาคารรูปหัวสิงโต อยู่ทางตะวันตกของคุโรมง ควรเผื่อเวลาเดินทาง"]
        ],
        "Sennichimae Doguyasuji": [
            ["千日前道具屋筋", "調理道具や食品サンプルを探せる商店街。夜の繁華街より早く閉まる店もあります。"],
            ["센니치마에 도구야스지", "조리 도구와 음식 모형을 구경하세요. 밤거리보다 일찍 닫는 가게도 있습니다."],
            ["千日前道具屋筋", "选购厨具和食品模型。部分店铺比夜生活场所更早关门。"],
            ["เซ็นนิจิมาเอะโดกุยาสุจิ", "ชมอุปกรณ์ครัวและอาหารจำลอง บางร้านปิดเร็วกว่าสถานบันเทิงยามค่ำคืน"]
        ],
        "Hozenji Yokocho": [
            ["法善寺横丁", "道頓堀近くの石畳の路地。にぎやかな街から少し離れて散策できます。"],
            ["호젠지 요코초", "도톤보리 근처의 돌길 골목입니다. 번화가에서 잠시 벗어나 걸어보세요."],
            ["法善寺横丁", "道顿堀附近的石板小巷，适合暂时远离繁华街区散步。"],
            ["โฮเซ็นจิโยโกโช", "ตรอกปูหินใกล้โดทงโบริ เหมาะกับการพักจากย่านที่คึกคัก"]
        ],
        "Namba Parks": [
            ["なんばパークス", "買い物と屋上庭園。お店の上で屋外の休憩を楽しめます。"],
            ["난바 파크스", "쇼핑과 옥상 정원을 즐기세요. 상점 위에서 야외 휴식을 취할 수 있습니다."],
            ["难波公园", "购物和屋顶花园。可在商场上方享受户外休息。"],
            ["นัมบะพาร์กส์", "แหล่งช้อปปิ้งและสวนบนดาดฟ้า พักกลางแจ้งเหนือร้านค้าได้"]
        ],
        "Chibo Dotonbori": [
            ["千房 道頓堀店", "大阪のお好み焼き。注文後に調理するため食事時間を多めに見込みましょう。"],
            ["치보 도톤보리점", "오사카식 오코노미야키를 즐기세요. 주문 후 조리하므로 시간을 넉넉히 잡으세요."],
            ["千房 道顿堀店", "品尝大阪风味大阪烧。点单后制作，请留出较多时间。"],
            ["ชิโบ สาขาโดทงโบริ", "โอโคโนมิยากิแบบโอซาก้า ปรุงหลังสั่งจึงควรเผื่อเวลารับประทาน"]
        ],
        "Sushizanmai Ebisubashi": [
            ["すしざんまい 戎橋店", "戎橋近くの寿司店。メニューと待ち時間を確認しましょう。"],
            ["스시잔마이 에비스바시점", "에비스바시 근처의 초밥집입니다. 메뉴와 대기 시간을 확인하세요."],
            ["寿司三昧 戎桥店", "戎桥附近的寿司店。请确认菜单及排队情况。"],
            ["ซูชิซันไม สาขาเอบิสึบาชิ", "ร้านซูชิใกล้สะพานเอบิสึบาชิ ตรวจสอบเมนูและคิว"]
        ],
        "ICHIRAN Dotonbori South": [
            ["一蘭 道頓堀店別館", "道頓堀周辺の豚骨ラーメン。旧本館は閉店しているため店舗を確認しましょう。"],
            ["이치란 도톤보리 별관", "도톤보리의 돈코츠 라멘집입니다. 이전 본관은 폐점했으니 지점을 확인하세요."],
            ["一兰 道顿堀别馆", "道顿堀的豚骨拉面店。原本馆已关闭，请确认分店。"],
            ["อิจิรัน โดทงโบริอาคารใต้", "ราเมนน้ำซุปกระดูกหมูในย่านโดทงโบริ สาขาอาคารหลักเดิมปิดแล้ว ควรตรวจสอบสาขา"]
        ],
        "Dotonbori": [
            ["道頓堀", "川沿いの看板とにぎやかな通り。撮影スポットの周辺も歩いてみましょう。"],
            ["도톤보리", "강변 간판과 활기찬 거리를 즐기세요. 유명 촬영 장소 주변도 둘러보세요."],
            ["道顿堀", "河岸招牌与热闹街道。也可探索热门拍照点周边的街巷。"],
            ["โดทงโบริ", "ชมป้ายริมคลองและถนนคึกคัก ลองเดินสำรวจรอบจุดถ่ายภาพยอดนิยมด้วย"]
        ],
        "Ebisu Bridge": [
            ["戎橋", "川と名物看板を眺める短い撮影スポット。歩行者の通路を空けましょう。"],
            ["에비스바시", "운하와 유명 간판을 보는 짧은 사진 코스입니다. 보행 통로를 비워주세요."],
            ["戎桥", "短暂停留，欣赏运河与地标招牌。请为行人留出通道。"],
            ["สะพานเอบิสึบาชิ", "แวะถ่ายภาพคลองและป้ายสำคัญ เว้นทางให้คนเดินผ่าน"]
        ],
        "Shinsaibashi-suji": [
            ["心斎橋筋商店街", "長いアーケード街。予定に合わせて折り返す場所を決めましょう。"],
            ["신사이바시스지", "긴 아케이드 상점가입니다. 일정에 맞춰 돌아올 지점을 정하세요."],
            ["心斋桥筋商店街", "很长的拱廊商店街。请按行程决定折返点。"],
            ["ชินไซบาชิสุจิ", "ถนนช้อปปิ้งมีหลังคาที่ยาว เลือกจุดกลับตามเวลาของแผน"]
        ],
        "Ebisubashi-suji": [
            ["戎橋筋商店街", "なんば駅方面へ向かう屋根付き商店街。買い物や軽食に便利です。"],
            ["에비스바시스지", "난바역 방향의 지붕 있는 상점가입니다. 쇼핑과 간식에 편리합니다."],
            ["戎桥筋商店街", "通往难波站的有顶商店街，适合购物和品尝小吃。"],
            ["เอบิสึบาชิสุจิ", "ถนนร้านค้ามีหลังคามุ่งไปสถานีนัมบะ สะดวกสำหรับช้อปปิ้งและซื้อของกิน"]
        ],
        "Todai-ji Temple": [
            ["東大寺", "大仏殿を見学。拝観料と公園内を歩く時間を確認しましょう。"],
            ["도다이지", "대불전을 관람하세요. 입장료와 공원 도보 시간을 확인하세요."],
            ["东大寺", "参观大佛殿。请确认门票，并预留穿过公园的时间。"],
            ["วัดโทไดจิ", "เข้าชมหอพระใหญ่ ตรวจสอบค่าเข้าชมและเผื่อเวลาเดินผ่านสวน"]
        ],
        "Nara National Museum": [
            ["奈良国立博物館", "奈良の仏教美術。開館日や見たい展示を確認しましょう。"],
            ["나라 국립박물관", "나라의 불교 미술을 살펴보세요. 개관일과 원하는 전시를 확인하세요."],
            ["奈良国立博物馆", "欣赏奈良佛教艺术。请确认开放日期和想看的展览。"],
            ["พิพิธภัณฑ์แห่งชาตินารา", "ชมศิลปะพุทธของนารา ตรวจสอบวันเปิดและนิทรรศการที่ต้องการชม"]
        ],
        "Isuien Garden": [
            ["依水園", "東大寺近くの庭園。入園料と開園日を確認しましょう。"],
            ["이스이엔", "도다이지 근처의 정원입니다. 입장료와 개원일을 확인하세요."],
            ["依水园", "东大寺附近的庭园。请确认门票与开放日期。"],
            ["สวนอิซุยเอ็น", "สวนใกล้วัดโทไดจิ ตรวจสอบค่าเข้าชมและวันเปิด"]
        ],
        "Nara Park": [
            ["奈良公園", "歴史ある寺院と鹿のいる公園。鹿には園内で販売する鹿せんべいだけを与えましょう。"],
            ["나라 공원", "사찰과 사슴이 있는 공원입니다. 사슴에게는 공원에서 파는 전용 센베이만 주세요."],
            ["奈良公园", "历史寺院与鹿群所在的公园。只喂园内出售的专用鹿仙贝。"],
            ["สวนนารา", "สวนที่มีวัดเก่าแก่และกวาง ให้กวางกินเฉพาะขนมเซ็นเบสำหรับกวางที่ขายในสวน"]
        ],
        "Kamaiki Honten": [
            ["釜粋 本店", "近鉄奈良駅近くのうどん店。昼の行列の時間を見込みましょう。"],
            ["가마이키 본점", "긴테쓰 나라역 근처의 우동집입니다. 점심 대기 시간을 고려하세요."],
            ["釜粋本店", "近铁奈良站附近的乌冬面店。请预留午间排队时间。"],
            ["คามาอิกิ สาขาหลัก", "ร้านอุด้งใกล้สถานีคินเท็ตสึนารา เผื่อเวลารอคิวช่วงกลางวัน"]
        ],
        "Kakinohazushi Tanaka": [
            ["柿の葉すし本舗たなか", "奈良の柿の葉寿司。軽めの昼食や喫茶に向く立ち寄り先です。"],
            ["가키노하즈시 다나카", "나라의 감잎 초밥을 즐기세요. 가벼운 점심과 차를 위한 코스입니다."],
            ["柿叶寿司本铺田中", "品尝奈良的柿叶寿司，适合轻食午餐和饮茶。"],
            ["คาคิโนฮะซูชิทานากะ", "ซูชิห่อใบพลับของนารา เหมาะกับมื้อกลางวันเบา ๆ และดื่มชา"]
        ],
        "Genkishin": [
            ["元喜神", "近鉄奈良駅近くのラーメン店。現在の営業時間を確認しましょう。"],
            ["겐키신", "긴테쓰 나라역 근처의 라멘집입니다. 현재 영업시간을 확인하세요."],
            ["元喜神", "近铁奈良站附近的拉面店。请确认当前营业时间。"],
            ["เก็นคิชิน", "ร้านราเมนใกล้สถานีคินเท็ตสึนารา ตรวจสอบเวลาเปิดปัจจุบัน"]
        ],
        "Kohfukuji Temple": [
            ["興福寺", "商店街近くの寺院。資料館の有料拝観を含めるか決めましょう。"],
            ["고후쿠지", "상점가 근처의 사찰입니다. 유료 박물관 관람 여부를 정하세요."],
            ["兴福寺", "商店街附近的寺院。请决定是否参观收费的博物馆。"],
            ["วัดโคฟุกุจิ", "วัดใกล้ย่านร้านค้า เลือกว่าจะเข้าชมอาคารพิพิธภัณฑ์ที่มีค่าเข้าหรือไม่"]
        ],
        "Sarusawa Pond": [
            ["猿沢池", "興福寺を望む屋外の休憩スポット。短い散策に向いています。"],
            ["사루사와 연못", "고후쿠지를 바라보며 잠시 쉬기 좋은 야외 산책 코스입니다."],
            ["猿泽池", "眺望兴福寺的户外休憩点，适合短暂散步。"],
            ["บึงซารุซาวะ", "จุดพักกลางแจ้งพร้อมวิววัดโคฟุกุจิ เหมาะกับการเดินสั้น ๆ"]
        ],
        "Naramachi": [
            ["ならまち", "古い町並みと工芸品の店。店ごとに営業時間が異なります。"],
            ["나라마치", "옛 거리와 공예품 가게를 천천히 둘러보세요. 가게마다 영업시간이 다릅니다."],
            ["奈良町", "慢慢探索旧街与手工艺店。各店营业时间不同。"],
            ["นารามาจิ", "เดินชมย่านเก่าและร้านงานฝีมืออย่างช้า ๆ แต่ละร้านมีเวลาเปิดต่างกัน"]
        ],
        "Gangoji Temple": [
            ["元興寺", "ならまちにある歴史的な寺院。拝観時間を確認しましょう。"],
            ["간고지", "나라마치의 역사 깊은 사찰입니다. 관람시간을 확인하세요."],
            ["元兴寺", "奈良町的历史寺院。请确认参观时间。"],
            ["วัดกังโกจิ", "วัดเก่าแก่ในนารามาจิ ตรวจสอบเวลาเข้าชม"]
        ],
        "Hiroshima Peace Memorial Museum": [
            ["広島平和記念資料館", "展示を落ち着いて見学できるよう、十分な時間を取りましょう。"],
            ["히로시마 평화기념자료관", "전시를 차분히 관람할 수 있도록 충분한 시간을 확보하세요."],
            ["广岛和平纪念资料馆", "请留出充足时间，从容观看展览。"],
            ["พิพิธภัณฑ์อนุสรณ์สันติภาพฮิโรชิมะ", "เผื่อเวลามากพอเพื่อชมนิทรรศการอย่างสงบและไม่เร่งรีบ"]
        ],
        "National Peace Memorial Hall": [
            ["国立広島原爆死没者追悼平和祈念館", "証言と追悼のための場所。静かに敬意を持って訪れましょう。"],
            ["국립 히로시마 원폭희생자 추도평화기념관", "증언과 추모를 위한 공간입니다. 조용히 존중하며 방문하세요."],
            ["国立广岛原爆死难者追悼和平祈念馆", "保存证言、追悼遇难者的场所。请安静并怀着敬意参观。"],
            ["หอรำลึกสันติภาพแห่งชาติแด่ผู้เสียชีวิตจากระเบิดปรมาณูฮิโรชิมะ", "พื้นที่สำหรับคำบอกเล่าและการรำลึก ควรเยี่ยมชมอย่างสงบและเคารพ"]
        ],
        "Peace Memorial Park": [
            ["平和記念公園", "慰霊碑や記念碑を巡る公園。立ち止まって考える時間を確保しましょう。"],
            ["평화기념공원", "위령비와 기념물을 돌아보세요. 멈춰 생각할 시간을 가지세요."],
            ["和平纪念公园", "参观慰灵碑和纪念设施。请留出驻足思考的时间。"],
            ["สวนอนุสรณ์สันติภาพ", "เดินชมอนุสรณ์ต่าง ๆ และเผื่อเวลาหยุดคิดรำลึก"]
        ],
        "Atomic Bomb Dome": [
            ["原爆ドーム", "保存された建物を公道から見学。追悼の場に配慮しましょう。"],
            ["원폭돔", "보존된 건물을 공공 보행로에서 관람하세요. 추모 공간을 존중해주세요."],
            ["原爆圆顶馆", "从公共步道观看保存的建筑外部。请尊重追悼环境。"],
            ["โดมระเบิดปรมาณู", "ชมภายนอกอาคารที่อนุรักษ์ไว้จากทางเดินสาธารณะ เคารพพื้นที่รำลึก"]
        ],
        "Nagata-ya": [
            ["長田屋", "平和公園近くの広島お好み焼き。行列の待ち時間を見込みましょう。"],
            ["나가타야", "평화공원 근처의 히로시마식 오코노미야키집입니다. 대기 시간을 고려하세요."],
            ["长田屋", "和平公园附近的广岛风味大阪烧店。请预留排队时间。"],
            ["นากาตะยะ", "โอโคโนมิยากิแบบฮิโรชิมะใกล้สวนสันติภาพ เผื่อเวลารอคิว"]
        ],
        "Sushitei Hondori": [
            ["すし亭 本通り店", "本通り商店街の寿司店。当日の営業とメニューを確認しましょう。"],
            ["스시테이 혼도리점", "혼도리 상점가의 초밥집입니다. 당일 영업과 메뉴를 확인하세요."],
            ["寿司亭 本通店", "本通商店街的寿司店。请确认当天营业和菜单。"],
            ["ซูชิเท สาขาฮนโดริ", "ร้านซูชิในถนนร้านค้าฮนโดริ ตรวจสอบการเปิดวันนี้และเมนู"]
        ],
        "IPPUDO Hiroshima Fukuromachi": [
            ["一風堂 広島袋町店", "中心部の袋町にあるラーメン店。公園からの移動時間を確保しましょう。"],
            ["잇푸도 히로시마 후쿠로마치점", "중심부 후쿠로마치의 라멘집입니다. 공원에서의 이동 시간을 확보하세요."],
            ["一风堂 广岛袋町店", "市中心袋町的拉面店。请预留从公园步行的时间。"],
            ["อิปปุโด สาขาฮิโรชิมะฟุคุโรมาจิ", "ร้านราเมนในย่านฟุคุโรมาจิใจกลางเมือง เผื่อเวลาเดินจากสวน"]
        ],
        "Hiroshima Castle grounds": [
            ["広島城跡・城内", "天守への入場はできません。外観や城内の散策を楽しめます。"],
            ["히로시마성 터·성내", "천수각에는 들어갈 수 없습니다. 외관과 성내 산책을 즐길 수 있습니다."],
            ["广岛城遗址・城内", "天守阁不开放入内，仍可欣赏外观和在城内散步。"],
            ["บริเวณปราสาทฮิโรชิมะ", "หอปราสาทหลักไม่เปิดให้เข้า ยังชมภายนอกและเดินรอบบริเวณได้"]
        ],
        "Hiroshima Hondori": [
            ["広島本通商店街", "中心部の屋根付き商店街。最後の予定を柔軟に調整できます。"],
            ["히로시마 혼도리", "도심의 지붕 있는 상점가입니다. 마지막 일정을 유연하게 조정할 수 있습니다."],
            ["广岛本通商店街", "市中心的有顶商店街，适合灵活安排最后一站。"],
            ["ถนนฮนโดริ ฮิโรชิมะ", "ถนนช้อปปิ้งมีหลังคาใจกลางเมือง เหมาะกับการปรับแผนช่วงท้าย"]
        ],
        "Shukkeien Garden": [
            ["縮景園", "池を巡る庭園散策。入園料を確認し、園路を歩く時間を取りましょう。"],
            ["슈케이엔", "연못 주변 정원길을 걸어보세요. 입장료를 확인하고 산책 시간을 확보하세요."],
            ["缩景园", "沿池塘边的园路散步。请确认门票并留出参观时间。"],
            ["สวนชุกเคเอ็น", "เดินตามทางรอบสระน้ำ ตรวจสอบค่าเข้าชมและเผื่อเวลาเดินชมสวน"]
        ],
        "Hiroshima Prefectural Art Museum": [
            ["広島県立美術館", "縮景園に隣接する美術館。現在の展覧会とチケットを確認しましょう。"],
            ["히로시마 현립미술관", "슈케이엔 옆 미술관입니다. 현재 전시와 입장권을 확인하세요."],
            ["广岛县立美术馆", "紧邻缩景园。请确认当前展览和门票。"],
            ["พิพิธภัณฑ์ศิลปะจังหวัดฮิโรชิมะ", "อยู่ข้างสวนชุกเคเอ็น ตรวจสอบนิทรรศการปัจจุบันและตั๋ว"]
        ]
    ]
}


private struct NearbyHotel: Decodable, Identifiable {
    let id: String
    let names: [String]
    let addressJP: String
    let addressEN: String
    let phone: String
    let phoneDisplay: String
    let officialURL: String
    let rateURL: String
    let contactURL: String
    let sourceURL: String
}

private enum TravelExtras {
    static let hotels: [String: [NearbyHotel]] = {
        let json = #"""
{"asakusa":[{"id":"gate-asakusa","names":["ザ・ゲートホテル雷門 by HULIC","더 게이트 호텔 가미나리몬","雷门盖特酒店","THE GATE HOTEL KAMINARIMON by HULIC","เดอะเกตโฮเทล คามินาริมง"],"addressJP":"東京都台東区雷門2-16-11","addressEN":"2-16-11 Kaminarimon, Taito-ku, Tokyo, Japan","phone":"+81358263877","phoneDisplay":"+81 3-5826-3877","officialURL":"https://www.gate-hotel.jp/asakusa-kaminarimon/","rateURL":"https://www.gate-hotel.jp/asakusa-kaminarimon/","contactURL":"https://www.gate-hotel.jp/asakusa-kaminarimon/contact/","sourceURL":"https://www.gate-hotel.jp/asakusa-kaminarimon/access.html"},{"id":"richmond-asakusa","names":["リッチモンドホテルプレミア浅草","리치몬드 호텔 프리미어 아사쿠사","浅草里士满高级酒店","Richmond Hotel Premier Asakusa","ริชมอนด์โฮเทล พรีเมียร์อาซากุสะ"],"addressJP":"東京都台東区浅草2-6-7","addressEN":"2-6-7 Asakusa, Taito-ku, Tokyo, Japan","phone":"+81358063155","phoneDisplay":"+81 3-5806-3155","officialURL":"https://richmondhotel.jp/asakusa-international/","rateURL":"https://richmondhotel.jp/asakusa-international/","contactURL":"https://richmondhotel.jp/asakusa-international/","sourceURL":"https://tokyotouristinfo.com/en/detail/M0609"}],"ueno":[{"id":"resol-ueno","names":["ホテルリソル上野","호텔 리솔 우에노","上野利索尔酒店","HOTEL RESOL UENO","โฮเทลรีโซล อุเอโนะ"],"addressJP":"東京都台東区上野7-2-9","addressEN":"7-2-9 Ueno, Taito-ku, Tokyo, Japan","phone":"+81338449269","phoneDisplay":"+81 3-3844-9269","officialURL":"https://www.resol-hotel.jp/ueno/","rateURL":"https://www.resol-hotel.jp/ueno/","contactURL":"https://www.resol-hotel.jp/ueno/","sourceURL":"https://www.resol-hotel.jp/ueno/access/"},{"id":"nohga-ueno","names":["ノーガホテル 上野 東京","노가 호텔 우에노 도쿄","上野东京诺加酒店","NOHGA HOTEL UENO TOKYO","โนกะโฮเทล อุเอโนะโตเกียว"],"addressJP":"東京都台東区東上野2-21-10","addressEN":"2-21-10 Higashiueno, Taito-ku, Tokyo, Japan","phone":"+81358160211","phoneDisplay":"+81 3-5816-0211","officialURL":"https://www.nohgahotel.com/ueno/","rateURL":"https://www.nohgahotel.com/ueno/en/rooms/","contactURL":"https://www.nohgahotel.com/ueno/","sourceURL":"https://www.nohgahotel.com/ueno/access/"}],"kyoto":[{"id":"nohga-kyoto","names":["ノーガホテル 清水 京都","노가 호텔 기요미즈 교토","京都清水诺加酒店","NOHGA HOTEL KIYOMIZU KYOTO","โนกะโฮเทล คิโยมิซุเกียวโต"],"addressJP":"京都市東山区五条橋東4-450-1","addressEN":"4-450-1 Gojobashi-Higashi, Higashiyama-ku, Kyoto, Japan","phone":"+81753237120","phoneDisplay":"+81 75-323-7120","officialURL":"https://www.nohgahotel.com/kiyomizu/","rateURL":"https://www.nohgahotel.com/kiyomizu/en/rooms/","contactURL":"https://www.nohgahotel.com/kiyomizu/","sourceURL":"https://www.nohgahotel.com/kiyomizu/en/access/"},{"id":"parkhyatt-kyoto","names":["パーク ハイアット 京都","파크 하얏트 교토","京都柏悦酒店","Park Hyatt Kyoto","พาร์คไฮแอท เกียวโต"],"addressJP":"京都市東山区高台寺桝屋町360","addressEN":"360 Kodaiji Masuyacho, Higashiyama-ku, Kyoto, Japan","phone":"+81755311234","phoneDisplay":"+81 75-531-1234","officialURL":"https://www.hyatt.com/park-hyatt/en-US/itmph-park-hyatt-kyoto","rateURL":"https://www.hyatt.com/park-hyatt/en-US/itmph-park-hyatt-kyoto","contactURL":"https://www.hyatt.com/park-hyatt/en-US/itmph-park-hyatt-kyoto/hotel-info","sourceURL":"https://www.hyatt.com/park-hyatt/en-US/itmph-park-hyatt-kyoto/hotel-info"}],"osaka":[{"id":"onefive-kuromon","names":["ザ・ワンファイブ大阪なんば黒門","더 원파이브 오사카 난바 구로몬","大阪难波黑门OneFive酒店","The OneFive Osaka Namba Kuromon","เดอะวันไฟว์ โอซาก้านัมบะคุโรมง"],"addressJP":"大阪市中央区日本橋1-20-6","addressEN":"1-20-6 Nipponbashi, Chuo-ku, Osaka, Japan","phone":"0570014215","phoneDisplay":"0570-014-215","officialURL":"https://onefivehotels.co.jp/hotels/theonefiveosakanambakuromon","rateURL":"https://onefivehotels.co.jp/hotels/theonefiveosakanambakuromon","contactURL":"https://onefivehotels.co.jp/hotels/theonefiveosakanambakuromon","sourceURL":"https://onefivehotels.co.jp/hotels/theonefiveosakanambakuromon"},{"id":"citadines-namba","names":["シタディーンなんば大阪","시타딘 난바 오사카","大阪难波馨乐庭公寓酒店","Citadines Namba Osaka","ซิทาดีนส์ นัมบะโอซาก้า"],"addressJP":"大阪市浪速区日本橋3-5-25","addressEN":"3-5-25 Nippombashi, Naniwa-ku, Osaka, Japan","phone":"+81666957150","phoneDisplay":"+81 6-6695-7150","officialURL":"https://www.discoverasr.com/en/citadines/japan/citadines-namba-osaka","rateURL":"https://www.discoverasr.com/en/citadines/japan/citadines-namba-osaka/offers","contactURL":"https://www.discoverasr.com/en/citadines/japan/citadines-namba-osaka/location","sourceURL":"https://www.discoverasr.com/en/citadines/japan/citadines-namba-osaka/location"}],"nara":[{"id":"newwakasa","names":["ホテルニューわかさ","호텔 뉴 와카사","新若草酒店","Hotel New Wakasa","โฮเทลนิววาคาซะ"],"addressJP":"奈良市北半田東町1","addressEN":"1 Kitahandahigashi-machi, Nara, Japan","phone":"+81742235858","phoneDisplay":"+81 742-23-5858","officialURL":"https://www.n-wakasa.com/","rateURL":"https://www.n-wakasa.com/","contactURL":"https://www.n-wakasa.com/lg_en/access/","sourceURL":"https://www.n-wakasa.com/lg_en/access/"},{"id":"narahotel","names":["奈良ホテル","나라 호텔","奈良酒店","Nara Hotel","นาราโฮเทล"],"addressJP":"奈良市高畑町1096","addressEN":"1096 Takabatake-cho, Nara, Japan","phone":"+81742243011","phoneDisplay":"+81 742-24-3011","officialURL":"https://jrwest-hotels.jp/narahotel/","rateURL":"https://jrwest-hotels.jp/narahotel/","contactURL":"https://jrwest-hotels.jp/narahotel/","sourceURL":"https://jrwest-hotels.jp/narahotel/access/"}],"hiroshima":[{"id":"mitsui-hiroshima","names":["三井ガーデンホテル広島","미쓰이 가든 호텔 히로시마","广岛三井花园酒店","Mitsui Garden Hotel Hiroshima","มิตซุยการ์เดนโฮเทล ฮิโรชิมะ"],"addressJP":"広島市中区中町9-12","addressEN":"9-12 Naka-machi, Naka-ku, Hiroshima, Japan","phone":"+81822401131","phoneDisplay":"+81 82-240-1131","officialURL":"https://www.gardenhotels.co.jp/hiroshima/","rateURL":"https://www.gardenhotels.co.jp/hiroshima/","contactURL":"https://www.gardenhotels.co.jp/hiroshima/","sourceURL":"https://www.gardenhotels.co.jp/hiroshima/eng/access/"},{"id":"rihga-hiroshima","names":["リーガロイヤルホテル広島","리가 로얄 호텔 히로시마","广岛丽嘉皇家酒店","RIHGA Royal Hotel Hiroshima","รีกาโรยัลโฮเทล ฮิโรชิมะ"],"addressJP":"広島市中区基町6-78","addressEN":"6-78 Motomachi, Naka-ku, Hiroshima, Japan","phone":"+81825021121","phoneDisplay":"+81 82-502-1121","officialURL":"https://www.rihga.co.jp/hiroshima/","rateURL":"https://www.rihga.co.jp/hiroshima/stay","contactURL":"https://www.rihga.co.jp/hiroshima/contact","sourceURL":"https://www.rihga.co.jp/hiroshima/contact"}]}
"""#
        guard let hotels = try? JSONDecoder().decode([String: [NearbyHotel]].self, from: Data(json.utf8)) else {
            preconditionFailure("Invalid bundled hotel data")
        }
        return hotels
    }()
    static let ui: [String: [String]] = [
        "hotels": ["出発地点近くのホテル", "출발 지점 주변 호텔", "出发地点附近的酒店", "Hotels near the starting area", "โรงแรมใกล้จุดเริ่มต้น"],
        "hotelNote": ["各コースの出発エリアにあるホテル候補です。下のリンクで、選択中の最初の場所への経路を確認できます。", "각 코스의 출발 지역에 있는 호텔 후보입니다. 아래 링크에서 현재 선택한 첫 장소까지의 경로를 확인할 수 있습니다.", "这些酒店位于路线的出发区域。下方链接可查看前往当前第一站的路线。", "Hotels in this route’s starting area. Links show directions to your currently selected first stop.", "โรงแรมในบริเวณเริ่มต้นของเส้นทาง ลิงก์ด้านล่างแสดงทางไปยังจุดแรกที่เลือกอยู่"],
        "rateNote": ["宿泊料金は日付・人数・部屋・食事条件で変わります。公式サイトで条件を入力すると金額を確認できます。", "숙박 요금은 날짜, 인원, 객실과 식사 조건에 따라 달라집니다. 공식 사이트에 조건을 입력해 금액을 확인하세요.", "住宿价格随日期、人数、房型及餐食条件变化。在官网输入条件即可查看金额。", "Rates depend on dates, guests, room type and meals. Enter your stay details on the official site to see the price.", "ค่าที่พักขึ้นอยู่กับวัน จำนวนผู้เข้าพัก ประเภทห้อง และอาหาร ระบุเงื่อนไขในเว็บไซต์ทางการเพื่อดูราคา"],
        "rate": ["宿泊料金・空室を確認", "숙박 요금·빈 객실 확인", "查看房价与空房", "Check rates & availability", "ตรวจสอบราคาและห้องว่าง"],
        "hotelMap": ["場所を地図で見る", "위치 지도 보기", "在地图查看位置", "View hotel location", "ดูที่ตั้งบนแผนที่"],
        "contact": ["公式情報・お問い合わせ", "공식 정보·문의", "官网信息与联系", "Official information & contact", "ข้อมูลทางการและติดต่อ"],
        "call": ["電話する", "전화하기", "拨打电话", "Call hotel", "โทรหาโรงแรม"],
        "toFirst": ["ホテル→最初の場所", "호텔→첫 장소", "酒店→第一站", "Hotel → first stop", "โรงแรม → จุดแรก"],
        "arrival": ["コースの出発地点への行き方", "코스 출발 지점으로 가는 방법", "如何到达路线起点", "Getting to the first stop", "วิธีไปยังจุดเริ่มต้น"],
        "customArrival": ["最初の場所を変更しています。選択中の目的地までの徒歩・公共交通の経路を下の地図で確認してください。", "첫 장소가 변경되었습니다. 아래 지도에서 현재 목적지까지의 도보 또는 대중교통 경로를 확인하세요.", "第一站已更换。请在下方地图查看前往当前目的地的步行或公共交通路线。", "The first stop has changed. Use the links below for walking or transit directions to the selected destination.", "จุดแรกเปลี่ยนแล้ว ใช้ลิงก์ด้านล่างดูเส้นทางเดินหรือขนส่งสาธารณะไปยังสถานที่ที่เลือก"],
        "officialAccess": ["公式の交通案内", "공식 교통 안내", "官方交通指南", "Official access guide", "ข้อมูลการเดินทางทางการ"],
        "transfer": ["次の場所への移動", "다음 장소로 이동", "前往下一站", "Travel to the next stop", "เดินทางไปจุดถัดไป"],
        "walkRoute": ["徒歩の道順", "도보 경로", "步行路线", "Walking directions", "เส้นทางเดิน"],
        "transitRoute": ["電車・地下鉄・バスの乗換", "전철·지하철·버스 환승", "电车・地铁・公交换乘", "Train / subway / bus routes", "เส้นทางรถไฟ รถไฟใต้ดิน และรถบัส"],
        "driveRoute": ["車・タクシーの経路", "차량·택시 경로", "汽车・出租车路线", "Car / taxi route", "เส้นทางรถยนต์หรือแท็กซี่"],
        "liveNote": ["乗車駅・降車駅・乗換・発車時刻・運賃は「電車・地下鉄・バスの乗換」で確認できます。目的地を入れ替えるとリンクも更新されます。", "승차역, 하차역, 환승, 출발 시간과 요금은 대중교통 링크에서 확인할 수 있습니다. 장소를 바꾸면 링크도 업데이트됩니다.", "点击公共交通链接查看上车站、下车站、换乘、发车时间和票价。更换目的地后链接也会更新。", "Open transit routes for boarding and exit stops, transfers, departures and fares. Links update when you swap a destination.", "เปิดเส้นทางขนส่งสาธารณะเพื่อดูจุดขึ้นลง การต่อรถ เวลาออก และค่าโดยสาร ลิงก์จะเปลี่ยนตามสถานที่ที่เลือก"],
        "walkFallback": ["徒歩でこの2か所を移動できます。細かな曲がり角や横断場所は「徒歩の道順」で確認してください。歩く距離が長い場合は公共交通の候補も比較できます。", "두 장소 사이를 걸어서 이동할 수 있습니다. 자세한 회전 지점과 횡단 위치는 도보 경로에서 확인하세요. 거리가 길면 대중교통도 비교할 수 있습니다.", "这两处可步行前往。转弯与过街位置请查看步行路线；距离较长时也可比较公共交通方案。", "You can walk between these stops. Open walking directions for turns and crossings; compare transit if the walk is long.", "เดินระหว่างสองจุดนี้ได้ ดูทางเลี้ยวและจุดข้ามถนนในเส้นทางเดิน หากระยะไกลสามารถเปรียบเทียบขนส่งสาธารณะได้"],
        "planningGap": ["計画上の移動枠：約%d分（実際の所要時間は経路図で確認）", "계획상 이동 시간: 약 %d분 (실제 시간은 지도에서 확인)", "规划交通时间：约%d分钟（实际时间请查看地图）", "Planning allowance: about %d min (check the map for actual travel time)", "เวลาเผื่อเดินทางในแผนประมาณ %d นาที (ดูเวลาจริงจากแผนที่)"],
        "asakusaRail": ["電車なら、東武浅草駅→東武スカイツリーライン→とうきょうスカイツリー駅→徒歩で目的地へ。地下鉄を使う候補や駅までの徒歩も、乗換リンクで比較できます。", "전철 이용 시 도부 아사쿠사역→도부 스카이트리선→도쿄스카이트리역→목적지까지 도보입니다. 지하철과 역까지의 도보도 환승 링크에서 비교하세요.", "乘电车可从东武浅草站→东武晴空塔线→东京晴空塔站→步行至目的地。地铁及前往车站的步行路线也可在换乘链接比较。", "By train: Tobu Asakusa Station → Tobu Skytree Line → Tokyo Skytree Station → walk to the venue. Compare subway options and station walks through the transit link.", "หากใช้รถไฟ: สถานีโทบุอาซากุสะ → สายโทบุสกายทรี → สถานีโตเกียวสกายทรี → เดินไปสถานที่ เปรียบเทียบรถไฟใต้ดินและทางเดินถึงสถานีได้จากลิงก์"],
        "checked": ["公式情報確認：2026年10月2日", "공식 정보 확인: 2026년 10월 2일", "官方信息核对：2026年10月2日", "Official details checked: 2 Oct 2026", "ตรวจสอบข้อมูลทางการ: 2 ต.ค. 2026"]
    ]
    static let arrivalOrigins: [String: String] = [
        "asakusa": "浅草駅 東京 台東区 日本",
        "ueno": "JR上野駅 公園口 東京 日本",
        "kyoto": "京都駅 京都 日本",
        "osaka": "日本橋駅 大阪 日本",
        "nara": "近鉄奈良駅 奈良 日本",
        "hiroshima": "広島駅 広島 日本"
    ]
    static let arrivalSources: [String: String] = [
        "asakusa": "https://www.senso-ji.jp/access/",
        "ueno": "https://www.tnm.jp/modules/r_free_page/index.php?id=113",
        "kyoto": "https://www.kiyomizudera.or.jp/access.php",
        "osaka": "https://kuromon.com/jp/access/",
        "nara": "https://www.todaiji.or.jp/access/",
        "hiroshima": "https://www.pcf.city.hiroshima.jp/hpcf/access/index.html"
    ]
    static let arrivalText: [String: [String]] = [
        "asakusa": ["東京メトロ銀座線または都営浅草線で浅草駅へ。地上に出て雷門へ進み、仲見世通りを通って浅草寺へ徒歩で向かいます。", "도쿄메트로 긴자선 또는 도에이 아사쿠사선으로 아사쿠사역에 내리세요. 지상에서 가미나리몬으로 가서 나카미세 거리를 지나 센소지까지 걸으세요.", "乘东京地铁银座线或都营浅草线至浅草站。出站到地面，前往雷门，沿仲见世街步行至浅草寺。", "Take the Tokyo Metro Ginza Line or Toei Asakusa Line to Asakusa Station. Walk to Kaminarimon, then through Nakamise to Sensoji Temple.", "นั่งโตเกียวเมโทรสายกินซ่าหรือสายโทเออาซากุสะลงสถานีอาซากุสะ ขึ้นสู่ถนนแล้วเดินไปประตูคามินาริมง ผ่านถนนนากามิเสะไปวัดเซ็นโซจิ"],
        "ueno": ["JRで上野駅へ。公園口から出て上野公園内を通り、東京国立博物館の正門へ徒歩約10分。地下鉄銀座線・日比谷線の上野駅からは徒歩約15分です。", "JR 우에노역 공원 출구에서 우에노 공원을 지나 도쿄 국립박물관 정문까지 도보 약 10분입니다. 지하철 긴자선·히비야선 우에노역에서는 약 15분 걸립니다.", "乘JR至上野站，从公园口穿过上野公园，步行约10分钟到东京国立博物馆正门。地铁银座线或日比谷线上野站步行约15分钟。", "Arrive at JR Ueno Station. From the Park Exit, walk through Ueno Park to the Tokyo National Museum main gate, about 10 minutes. From Ginza or Hibiya Line Ueno Station, allow about 15 minutes on foot.", "ลง JR สถานีอุเอโนะ ออกทางประตูสวน เดินผ่านสวนอุเอโนะถึงประตูหลักพิพิธภัณฑ์แห่งชาติโตเกียวประมาณ 10 นาที จากสถานีอุเอโนะสายกินซ่าหรือฮิบิยะเดินประมาณ 15 นาที"],
        "kyoto": ["JR京都駅→市バス206系統（東山通・北大路バスターミナル方面）→五条坂で下車→坂道を徒歩約10分で清水寺へ。京阪清水五条駅からなら徒歩約25分です。", "JR 교토역→시내버스 206번(히가시오지도리·기타오지 버스터미널 방향)→고조자카 하차→언덕길 도보 약 10분으로 기요미즈데라에 도착합니다. 게이한 기요미즈고조역에서는 도보 약 25분입니다.", "JR京都站→市营公交206路（东山通・北大路巴士总站方向）→五条坂下车→沿坡道步行约10分钟到清水寺。从京阪清水五条站步行约25分钟。", "JR Kyoto Station → city bus 206 toward Higashiyama-dori / Kitaoji Bus Terminal → alight at Gojozaka → walk uphill about 10 minutes to Kiyomizu-dera. From Keihan Kiyomizu-Gojo Station, the walk is about 25 minutes.", "JR สถานีเกียวโต → รถบัสเมืองสาย 206 ไปทางฮิกาชิยามะโดริ/สถานีรถบัสคิตาโอจิ → ลงโกโจซากะ → เดินขึ้นเนินประมาณ 10 นาทีถึงวัดคิโยมิซุเดระ จากสถานีเคฮันคิโยมิซุโกโจเดินประมาณ 25 นาที"],
        "osaka": ["Osaka Metroの千日前線・堺筋線で日本橋駅へ。地上に出て黒門市場へ徒歩で向かいます。近鉄日本橋駅も利用できます。出口と細かな道順は徒歩リンクで確認できます。", "오사카메트로 센니치마에선·사카이스지선으로 닛폰바시역에 내린 뒤 지상에서 구로몬 시장까지 걸으세요. 긴테쓰 닛폰바시역도 이용할 수 있습니다. 출구와 길은 도보 링크에서 확인하세요.", "乘Osaka Metro千日前线或堺筋线至日本桥站，出站到地面步行至黑门市场。也可利用近铁日本桥站。出口和详细路线请查看步行链接。", "Take the Osaka Metro Sennichimae or Sakaisuji Line to Nippombashi Station, then walk to Kuromon Market. Kintetsu-Nippombashi is another option. Check the walking link for exits and turns.", "นั่ง Osaka Metro สายเซ็นนิจิมาเอะหรือซาไกซุจิลงสถานีนิปปงบาชิ แล้วเดินไปตลาดคุโรมง ใช้สถานีคินเท็ตสึนิปปงบาชิได้เช่นกัน ดูทางออกและทางเลี้ยวจากลิงก์เดิน"],
        "nara": ["JR奈良駅または近鉄奈良駅→奈良交通の市内循環バス→「東大寺大仏殿・春日大社前」で下車→徒歩約5分で東大寺へ。近鉄奈良駅から全区間を歩く場合は約20分です。", "JR 나라역 또는 긴테쓰 나라역→나라교통 시내순환버스→도다이지 다이부쓰덴·가스가타이샤마에 하차→도보 약 5분으로 도다이지에 도착합니다. 긴테쓰 나라역에서 모두 걸으면 약 20분입니다.", "JR奈良站或近铁奈良站→奈良交通市内循环公交→东大寺大佛殿・春日大社前下车→步行约5分钟到东大寺。从近铁奈良站全程步行约20分钟。", "JR Nara or Kintetsu Nara Station → Nara Kotsu city-loop bus → Todai-ji Daibutsuden / Kasuga Taisha-mae stop → walk about 5 minutes to Todai-ji. Walking all the way from Kintetsu Nara takes about 20 minutes.", "JR สถานีนาราหรือสถานีคินเท็ตสึนารา → รถบัสวนเมืองนาราโคสึ → ลงป้ายโทไดจิไดบุตสึเด็น/คาสึกะไทฉะมาเอะ → เดินประมาณ 5 นาทีถึงวัดโทไดจิ หากเดินทั้งหมดจากคินเท็ตสึนาราใช้ประมาณ 20 นาที"],
        "hiroshima": ["JR広島駅→広島電鉄1号線・広島港方面→袋町で下車→徒歩約10分で平和記念資料館へ。路線バスや観光周遊バスも候補です。最新の乗り場・運行時刻は乗換リンクで確認してください。", "JR 히로시마역→히로덴 1번 히로시마항 방향→후쿠로마치 하차→도보 약 10분으로 평화기념자료관에 도착합니다. 시내버스·관광순환버스도 가능합니다. 최신 정류장과 시간표는 환승 링크에서 확인하세요.", "JR广岛站→广岛电铁1号线广岛港方向→袋町下车→步行约10分钟到和平纪念资料馆。也可选择公交或观光循环巴士。最新乘车位置与时刻请查看换乘链接。", "JR Hiroshima Station → Hiroden tram line 1 toward Hiroshima Port → alight at Fukuromachi → walk about 10 minutes to the Peace Memorial Museum. City and sightseeing buses are alternatives; check the transit link for current stops and departures.", "JR สถานีฮิโรชิมะ → รถรางฮิโรเด็นสาย 1 ไปท่าเรือฮิโรชิมะ → ลงฟุคุโรมาจิ → เดินประมาณ 10 นาทีถึงพิพิธภัณฑ์สันติภาพ รถบัสเมืองและรถบัสท่องเที่ยวเป็นทางเลือก ดูจุดขึ้นและเวลาออกปัจจุบันจากลิงก์"]
    ]
    static let legs: [String: [[String]]] = [
        "asakusa": [
            ["浅草寺の境内から南側の仲見世通りへ出て、商店街を歩きます。", "센소지 경내에서 남쪽 나카미세 거리로 나와 상점가를 걸으세요.", "从浅草寺寺院区域向南进入仲见世街，沿商店街步行。", "Leave the Sensoji grounds to the south and walk into Nakamise Shopping Street.", "ออกจากบริเวณวัดเซ็นโซจิทางใต้แล้วเดินเข้าถนนร้านค้านากามิเสะ"],
            ["仲見世通りから横道へ入り、浅草寺近くの与ろゐ屋へ徒歩で向かいます。店舗の入口は経路図で確認できます。", "나카미세 거리에서 옆길로 들어가 센소지 근처 요로이야까지 걸으세요. 지도에서 입구를 확인하세요.", "从仲见世街进入侧街，步行前往浅草寺附近的与ろゐ屋。入口请查看地图。", "Turn off Nakamise into the side streets and walk to Yoroiya near Sensoji. Check the map for its entrance.", "จากนากามิเสะเข้าถนนด้านข้างแล้วเดินไปโยโรอิยะใกล้วัดเซ็นโซจิ ดูทางเข้าร้านจากแผนที่"],
            ["徒歩なら隅田川を渡り、スカイツリー方面へ。電車を使う場合は下の東武線の案内を確認してください。", "도보라면 스미다강을 건너 스카이트리 방향으로 가세요. 전철 이용 시 아래 도부선 안내를 확인하세요.", "步行可跨越隅田川前往晴空塔方向。乘电车请参考下方东武线说明。", "On foot, cross the Sumida River toward Skytree. For the train option, see the Tobu Line guidance below.", "หากเดินให้ข้ามแม่น้ำสุมิดะไปทางสกายทรี หากใช้รถไฟดูคำแนะนำสายโทบุด้านล่าง"],
            ["スカイツリーとソラマチは同じ施設内です。館内の案内表示に沿って徒歩で移動します。", "스카이트리와 소라마치는 같은 단지에 있습니다. 안내 표지에 따라 걸으세요.", "晴空塔与晴空街道在同一园区内，按现场指示步行。", "Skytree and Solamachi share the same complex. Follow the signs and walk between them.", "สกายทรีและโซลามาจิอยู่ในพื้นที่เดียวกัน เดินตามป้ายแนะนำภายใน"]
        ],
        "ueno": [
            ["博物館の正門から上野公園内へ戻り、公園の歩道を散策します。", "박물관 정문에서 우에노 공원으로 돌아가 공원 산책로를 걸으세요.", "从博物馆正门返回上野公园，沿园内步道散步。", "Exit the museum main gate into Ueno Park and follow the park paths.", "ออกจากประตูหลักพิพิธภัณฑ์เข้าสวนอุเอโนะแล้วเดินตามทางในสวน"],
            ["上野公園内の歩道を使い、韻松亭へ徒歩で移動します。", "우에노 공원 산책로를 따라 인쇼테이까지 걸으세요.", "沿上野公园步道步行至韵松亭。", "Follow the paths within Ueno Park to Inshotei.", "เดินตามทางภายในสวนอุเอโนะไปอินโชเท"],
            ["食事後は公園内を国立科学博物館方面へ歩きます。", "식사 후 공원 안을 걸어 국립과학박물관으로 가세요.", "用餐后沿公园步道前往国立科学博物馆。", "After lunch, walk through the park toward the National Museum of Nature and Science.", "หลังอาหารเดินผ่านสวนไปพิพิธภัณฑ์ธรรมชาติและวิทยาศาสตร์แห่งชาติ"],
            ["博物館から公園内を南西の不忍池方面へ歩きます。道路の横断位置は徒歩の道順で確認できます。", "박물관에서 공원을 지나 남서쪽 시노바즈 연못으로 걸으세요. 횡단 위치는 도보 경로에서 확인하세요.", "从博物馆穿过公园，向西南方向步行至不忍池。过街位置请查看步行路线。", "Walk southwest through the park toward Shinobazu Pond. Check walking directions for road crossings.", "เดินจากพิพิธภัณฑ์ผ่านสวนไปทางตะวันตกเฉียงใต้สู่บึงชิโนบาซุ ดูจุดข้ามถนนจากเส้นทางเดิน"]
        ],
        "kyoto": [
            ["清水寺から参道を下り、産寧坂・二寧坂へ歩きます。坂道と階段があります。", "기요미즈데라 참배길을 내려가 산넨자카·니넨자카로 걸으세요. 경사와 계단이 있습니다.", "从清水寺沿参道下坡，步行至三年坂、二年坂。途中有坡道和台阶。", "Walk downhill from Kiyomizu-dera along the approach toward Sannenzaka and Ninenzaka. Expect slopes and steps.", "เดินลงทางเข้าวัดคิโยมิซุเดระไปซันเน็นซากะและนิเน็นซากะ มีเนินและบันได"],
            ["二寧坂・産寧坂の周辺から八坂の塔方面へ歩き、八坂圓堂へ向かいます。", "니넨자카·산넨자카에서 야사카의 탑 방향으로 걸어 덴푸라 엔도로 가세요.", "从二年坂、三年坂附近向八坂之塔方向步行至八坂圆堂。", "Walk toward Yasaka Pagoda from the historic slopes and continue to Gion Tempura Endo.", "จากบริเวณนิเน็นซากะและซันเน็นซากะเดินไปทางเจดีย์ยาซากะแล้วไปกิองเท็มปุระเอ็นโด"],
            ["食事後は八坂神社方面へ徒歩で移動します。入口は徒歩の道順で確認してください。", "식사 후 야사카 신사 방향으로 걸으세요. 입구는 도보 경로에서 확인하세요.", "用餐后步行前往八坂神社，入口请查看步行路线。", "After lunch, walk toward Yasaka Shrine. Check walking directions for the entrance.", "หลังอาหารเดินไปทางศาลเจ้ายาซากะ ดูทางเข้าจากเส้นทางเดิน"],
            ["八坂神社から祇園の公道へ出て、四条通や花見小路周辺を散策します。", "야사카 신사에서 기온의 공공 도로로 나와 시조도리와 하나미코지 주변을 걸으세요.", "从八坂神社进入祇园公共街道，漫步四条通或花见小路周边。", "Leave Yasaka Shrine for Gion’s public streets around Shijo-dori and Hanamikoji.", "จากศาลเจ้ายาซากะออกสู่ถนนสาธารณะในกิอง เดินชมรอบชิโจโดริและฮานามิโคจิ"]
        ],
        "osaka": [
            ["黒門市場から難波方面へ歩き、千日前道具屋筋の商店街へ向かいます。", "구로몬 시장에서 난바 방향으로 걸어 센니치마에 도구야스지로 가세요.", "从黑门市场向难波方向步行至千日前道具屋筋商店街。", "Walk from Kuromon Market toward Namba and Sennichimae Doguyasuji.", "จากตลาดคุโรมงเดินไปทางนัมบะและถนนเซ็นนิจิมาเอะโดกุยาสุจิ"],
            ["道具屋筋から道頓堀方面へ徒歩で向かい、千房の店舗へ進みます。", "도구야스지에서 도톤보리 방향으로 걸어 치보로 가세요.", "从道具屋筋向道顿堀方向步行至千房店铺。", "Walk from Doguyasuji toward Dotonbori and Chibo.", "จากโดกุยาสุจิเดินไปทางโดทงโบริและร้านชิโบ"],
            ["食事後は道頓堀の川沿いへ出て、周辺の歩道を散策します。", "식사 후 도톤보리 강변으로 나와 산책로를 걸으세요.", "用餐后前往道顿堀河岸，沿周边步道散步。", "After lunch, walk out to Dotonbori’s canal-side paths.", "หลังอาหารเดินออกสู่ทางเดินริมคลองโดทงโบริ"],
            ["道頓堀から戎橋周辺を通り、北側の心斎橋筋商店街へ歩きます。", "도톤보리에서 에비스바시 주변을 지나 북쪽 신사이바시스지로 걸으세요.", "从道顿堀经过戎桥周边，向北步行至心斋桥筋商店街。", "Walk through the Ebisubashi area and head north into Shinsaibashi-suji.", "จากโดทงโบริผ่านบริเวณสะพานเอบิสึบาชิแล้วเดินขึ้นเหนือเข้าสู่ชินไซบาชิสุจิ"]
        ],
        "nara": [
            ["東大寺の参道から南側へ戻り、依水園の入口へ徒歩で向かいます。", "도다이지 참배길에서 남쪽으로 돌아가 이스이엔 입구까지 걸으세요.", "从东大寺参道向南返回，步行前往依水园入口。", "Return south from the Todai-ji approach and walk to Isuien Garden’s entrance.", "กลับลงใต้จากทางเข้าวัดโทไดจิแล้วเดินไปทางเข้าสวนอิซุยเอ็น"],
            ["依水園から近鉄奈良駅方面へ歩き、釜粋本店へ向かいます。", "이스이엔에서 긴테쓰 나라역 방향으로 걸어 가마이키 본점으로 가세요.", "从依水园向近铁奈良站方向步行至釜粋本店。", "Walk from Isuien toward Kintetsu Nara Station and Kamaiki Honten.", "จากอิซุยเอ็นเดินไปทางสถานีคินเท็ตสึนาราและคามาอิกิสาขาหลัก"],
            ["食事後は興福寺の境内方面へ徒歩で移動します。", "식사 후 고후쿠지 경내 방향으로 걸으세요.", "用餐后步行前往兴福寺寺院区域。", "After lunch, walk toward the Kohfukuji temple grounds.", "หลังอาหารเดินไปทางบริเวณวัดโคฟุกุจิ"],
            ["興福寺から猿沢池方面へ下り、ならまちの公道へ徒歩で向かいます。", "고후쿠지에서 사루사와 연못 방향으로 내려가 나라마치 공공 거리로 걸으세요.", "从兴福寺向猿泽池方向下行，步行进入奈良町公共街道。", "Walk down toward Sarusawa Pond, then continue into Naramachi’s public streets.", "เดินจากโคฟุกุจิลงไปทางบึงซารุซาวะแล้วต่อไปถนนสาธารณะในนารามาจิ"]
        ],
        "hiroshima": [
            ["資料館から平和記念公園内の歩道へ出て、慰霊碑などを巡ります。", "자료관에서 평화기념공원 산책로로 나와 위령비 등을 둘러보세요.", "从资料馆进入和平纪念公园步道，参观慰灵碑等纪念设施。", "Leave the museum for the park paths and memorial monuments.", "ออกจากพิพิธภัณฑ์สู่ทางเดินในสวนสันติภาพและอนุสรณ์ต่าง ๆ"],
            ["平和公園から原爆ドーム・元安橋周辺を通り、長田屋へ徒歩で向かいます。", "평화공원에서 원폭돔·모토야스바시 주변을 지나 나가타야까지 걸으세요.", "从和平公园经过原爆圆顶馆、元安桥周边，步行至长田屋。", "Walk through the Atomic Bomb Dome / Motoyasu Bridge area toward Nagata-ya.", "จากสวนสันติภาพเดินผ่านบริเวณโดมระเบิดปรมาณูและสะพานโมโตยาสุไปนากาตะยะ"],
            ["食事後は紙屋町・県庁方面を通り、広島城跡へ徒歩で向かいます。歩く距離が長い場合は公共交通の候補を比較してください。", "식사 후 가미야초·현청 방향을 지나 히로시마성 터까지 걸으세요. 거리가 길면 대중교통을 비교하세요.", "用餐后经过纸屋町、县厅方向，步行前往广岛城址。步行距离较长时可比较公共交通。", "After lunch, walk via the Kamiyacho / prefectural office area toward Hiroshima Castle grounds. Compare transit if the walk is too long.", "หลังอาหารเดินผ่านบริเวณคามิยาโจและที่ทำการจังหวัดไปบริเวณปราสาทฮิโรชิมะ หากเดินไกลให้เปรียบเทียบขนส่งสาธารณะ"],
            ["広島城跡から東側の縮景園方面へ徒歩で向かいます。広島県立美術館が入口付近の目印です。", "히로시마성 터에서 동쪽 슈케이엔으로 걸으세요. 입구 근처 히로시마 현립미술관이 표지입니다.", "从广岛城址向东步行至缩景园，入口附近的广岛县立美术馆可作为地标。", "Walk east from the castle grounds toward Shukkeien. The Prefectural Art Museum is a landmark near the entrance.", "จากบริเวณปราสาทเดินไปทางตะวันออกสู่ชุกเคเอ็น พิพิธภัณฑ์ศิลปะจังหวัดเป็นจุดสังเกตใกล้ทางเข้า"]
        ]
    ]
}

private struct DinnerPlace: Identifiable {
    let id: String
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    let distance: Double
    var query: String { "\(latitude),\(longitude)" }
}

private enum JourneyTranslations {
    static let ui: [String: [String]] = [
        "translatedPage": ["翻訳ページを開く", "번역 페이지 열기", "打开翻译页面", "Open translated page", "เปิดหน้าที่แปลแล้ว"],
        "originalPage": ["元のページを開く", "원본 페이지 열기", "打开原网页", "Open original page", "เปิดหน้าต้นฉบับ"],
        "webTranslationNote": ["外部の案内ページは翻訳版を優先表示します。翻訳できない場合は元のページを開いてください。", "외부 안내 페이지는 번역판을 우선 표시합니다. 번역이 되지 않으면 원본 페이지를 여세요.", "外部指南优先打开翻译页面。如无法翻译，请打开原网页。", "Guide links open in your chosen language when translation is available. Use the original page if it does not load.", "ลิงก์ข้อมูลจะเปิดคำแปลเป็นภาษาที่เลือก หากไม่แสดงให้เปิดหน้าต้นฉบับ"],
        "lunchSearch": ["昼食のお店を選ぶ", "점심 식당 선택", "选择午餐餐厅", "Choose a lunch restaurant", "เลือกร้านมื้อกลางวัน"],
        "lunchNote": ["近くのお店を検索し、実際に行くお店を選んでください。", "주변 식당을 검색해 방문할 곳을 선택하세요.", "搜索附近餐厅并选择实际要去的餐厅。", "Search nearby restaurants and choose the one you will visit.", "ค้นหาร้านอาหารใกล้เคียงแล้วเลือกร้านที่จะไป"],
        "lunchNext": ["次は近くで昼食です。お店を選ぶと行き方を表示します。", "다음은 주변에서 점심입니다. 식당을 선택하면 경로가 표시됩니다.", "下一站在附近吃午餐。选好餐厅后显示路线。", "Lunch is next. Choose a restaurant to show its directions.", "ต่อไปทานมื้อกลางวันใกล้เคียง เลือกร้านเพื่อดูเส้นทาง"],
        "nearby": ["この近く", "이 근처", "附近", "nearby", "บริเวณใกล้เคียง"],
        "findLunch": ["近くの昼食のお店を探す", "주변 점심 식당 찾기", "搜索附近午餐餐厅", "Find nearby lunch restaurants", "ค้นหาร้านมื้อกลางวันใกล้เคียง"],
        "selectedLunch": ["選んだ昼食のお店", "선택한 점심 식당", "已选午餐餐厅", "Selected lunch restaurant", "ร้านมื้อกลางวันที่เลือก"],
        "selectLunch": ["このお店で昼食にする", "이 식당에서 점심 먹기", "选择这家餐厅吃午餐", "Choose this restaurant for lunch", "เลือกร้านนี้สำหรับมื้อกลางวัน"],
        "newArrival": ["ホテルから最初の観光地までの徒歩・公共交通の経路を確認してください。", "호텔에서 첫 관광지까지 도보·대중교통 경로를 확인하세요.", "请查看从酒店到第一站的步行及公共交通路线。", "Check walking or transit directions from your hotel to the first stop.", "ตรวจสอบเส้นทางเดินหรือขนส่งสาธารณะจากโรงแรมไปยังจุดแรก"],
        "region": ["地域", "지역", "地区", "Region", "ภูมิภาค"],
        "prefecture": ["都道府県", "도도부현", "都道府县", "Prefecture", "จังหวัด"],
        "courseCount": ["この都道府県：%dコース", "이 지역: %d개 코스", "该地区：%d条路线", "%d routes in this prefecture", "%d เส้นทางในจังหวัดนี้"],
        "placeMap": ["地図・現地情報", "지도·현지 정보", "地图・当地信息", "Map and local details", "แผนที่และข้อมูลสถานที่"],
        "findHotels": ["出発地近くのホテルを探す", "출발지 주변 호텔 찾기", "查找起点附近的酒店", "Find hotels near the first stop", "ค้นหาโรงแรมใกล้จุดแรก"],
        "searchingHotels": ["近くのホテルを検索中…", "주변 호텔 검색 중…", "正在搜索附近酒店…", "Searching nearby hotels…", "กำลังค้นหาโรงแรมใกล้เคียง…"],
        "hotelsUnavailable": ["ホテルを取得できませんでした。再検索するか、ホテル名・住所を入力してください。", "호텔을 찾지 못했습니다. 다시 검색하거나 호텔 이름과 주소를 입력하세요.", "无法获取酒店。请重试或输入酒店名称与地址。", "No hotels were found. Retry or enter a hotel name and address.", "ไม่พบโรงแรม ลองอีกครั้งหรือระบุชื่อและที่อยู่โรงแรม"],
        "chooseThisHotel": ["このホテルを選ぶ", "이 호텔 선택", "选择这家酒店", "Choose this hotel", "เลือกโรงแรมนี้"],
        "opening": ["ホテルから観光・夕食・帰り道まで、順番にご案内します。", "호텔에서 관광, 저녁 식사, 귀가까지 순서대로 안내합니다.", "从酒店出发、观光、晚餐到返回酒店，按顺序为您指引。", "From your hotel through sightseeing and dinner, then back to your hotel.", "นำทางตามลำดับตั้งแต่โรงแรม เที่ยวชม มื้อเย็น และกลับโรงแรม"],
        "chooseHotel": ["出発・帰着するホテル", "출발·귀착 호텔", "出发与返回的酒店", "Departure and return hotel", "โรงแรมที่ออกเดินทางและกลับ"],
        "ownHotel": ["自分のホテルを入力", "내 호텔 입력", "输入自己的酒店", "Enter your own hotel", "ระบุโรงแรมของคุณ"],
        "hotelInput": ["ホテル名・住所", "호텔 이름·주소", "酒店名称・地址", "Hotel name and address", "ชื่อและที่อยู่โรงแรม"],
        "hotelInputNote": ["同名のホテルがある場合は住所も入力してください。", "같은 이름의 호텔이 있으면 주소도 입력하세요.", "如有同名酒店，请同时输入地址。", "Include the address if hotels share the same name.", "หากมีโรงแรมชื่อเหมือนกัน โปรดระบุที่อยู่ด้วย"],
        "hotelChoiceNote": ["ここでの選択は経路案内用です。宿泊予約は公式サイトで行ってください。", "이 선택은 경로 안내용입니다. 숙박 예약은 공식 사이트에서 하세요.", "此处选择仅用于路线指引。请在官网预订住宿。", "This selection sets your route. Book accommodation on the official site.", "การเลือกนี้ใช้กำหนดเส้นทาง โปรดจองที่พักในเว็บไซต์ทางการ"],
        "enterHotel": ["先にホテル名・住所を入力してください。", "먼저 호텔 이름과 주소를 입력하세요.", "请先输入酒店名称与地址。", "Enter your hotel name and address first.", "กรุณาระบุชื่อและที่อยู่โรงแรมก่อน"],
        "depart": ["ホテル出発", "호텔 출발", "从酒店出发", "Leave the hotel", "ออกจากโรงแรม"],
        "hotelFirst": ["いったんホテルへ戻る", "먼저 호텔로 돌아가기", "先返回酒店", "Return to the hotel first", "กลับโรงแรมก่อน"],
        "dinnerHotel": ["ホテル周辺で夕食", "호텔 주변에서 저녁 식사", "在酒店附近吃晚餐", "Dinner near the hotel", "มื้อเย็นใกล้โรงแรม"],
        "dinnerLast": ["最後の観光地周辺で夕食", "마지막 관광지 주변에서 저녁 식사", "在最后一个景点附近吃晚餐", "Dinner near the final stop", "มื้อเย็นใกล้สถานที่เที่ยวสุดท้าย"],
        "returnHotel": ["ホテルへ戻る", "호텔로 돌아가기", "返回酒店", "Return to the hotel", "กลับโรงแรม"],
        "order": ["今日の順番", "오늘의 순서", "今天的行程顺序", "Today’s sequence", "ลำดับของวันนี้"],
        "finish": ["観光終了予定", "관광 종료 예정", "预计观光结束", "Estimated sightseeing finish", "เวลาเที่ยวเสร็จโดยประมาณ"],
        "current": ["いま確認する工程", "현재 확인할 단계", "当前步骤", "Current step", "ขั้นตอนปัจจุบัน"],
        "firstDestination": ["最初はここへ", "첫 목적지", "第一站前往这里", "First destination", "จุดหมายแรก"],
        "nextHotel": ["次はホテルへ", "다음은 호텔로", "下一步返回酒店", "Next: the hotel", "ต่อไปกลับโรงแรม"],
        "nextDinner": ["次は夕食へ", "다음은 저녁 식사", "下一步吃晚餐", "Next: dinner", "ต่อไปมื้อเย็น"],
        "earlyNote": ["早めの終了：ホテルへ戻り、ホテル周辺で夕食。その後ホテルへ戻ります。", "일찍 끝나면 호텔로 돌아온 뒤 주변에서 저녁을 먹고 다시 호텔로 돌아갑니다.", "结束较早：先返回酒店，在酒店附近吃晚餐，然后回酒店。", "An early finish: return to your hotel, eat nearby, then return after dinner.", "เมื่อเที่ยวเสร็จเร็ว กลับโรงแรมก่อน ทานมื้อเย็นใกล้โรงแรม แล้วกลับโรงแรม"],
        "lateNote": ["遅めの終了：最後の観光地周辺で夕食をとり、食後にホテルへ戻ります。", "늦게 끝나면 마지막 관광지 주변에서 저녁을 먹고 호텔로 돌아갑니다.", "结束较晚：在最后一个景点附近吃晚餐，餐后返回酒店。", "A late finish: eat near the final sightseeing stop, then return to your hotel.", "เมื่อเที่ยวเสร็จช้า ทานมื้อเย็นใกล้สถานที่เที่ยวสุดท้าย แล้วกลับโรงแรม"],
        "afterDinner": ["食後のホテルへの帰り道", "식사 후 호텔 귀가 경로", "餐后返回酒店的路线", "Route back to the hotel after dinner", "เส้นทางกลับโรงแรมหลังมื้อเย็น"],
        "selectDinnerHotel": ["夕食のお店と、帰るホテルを先に選んでください。", "저녁 식사할 곳과 돌아갈 호텔을 먼저 선택하세요.", "请先选择晚餐餐厅和返回的酒店。", "Choose a dinner restaurant and your return hotel first.", "เลือกสถานที่ทานมื้อเย็นและโรงแรมที่จะกลับก่อน"],
        "completed": ["今日の行程が完了しました。", "오늘 일정이 완료되었습니다.", "今天的行程已完成。", "Today’s itinerary is complete.", "แผนการเดินทางวันนี้เสร็จสิ้นแล้ว"],
        "arrived": ["ホテル到着・今日の行程を完了", "호텔 도착·오늘 일정 완료", "已到酒店・完成今天的行程", "Arrived at hotel · finish the day", "ถึงโรงแรมแล้ว · จบแผนวันนี้"],
        "next": ["次の工程へ進む", "다음 단계로", "进入下一步", "Continue to the next step", "ไปขั้นตอนถัดไป"],
        "previous": ["ひとつ前へ戻る", "이전 단계로", "返回上一步", "Go back one step", "กลับขั้นตอนก่อนหน้า"],
        "dinnerPlan": ["夕食の場所", "저녁 식사 위치", "晚餐区域", "Dinner area", "บริเวณมื้อเย็น"],
        "cutoffNote": ["自動：観光終了が18時より前ならホテル周辺、18時以降なら最後の観光地周辺。予定に合わせて手動で変更できます。", "자동: 관광 종료가 18시 전이면 호텔 주변, 18시 이후면 마지막 관광지 주변입니다. 직접 변경할 수 있습니다.", "自动：观光在18点前结束，选酒店附近；18点及之后，选最后景点附近。可手动调整。", "Auto: before 18:00, dine near the hotel; from 18:00, near the final stop. You can change this manually.", "อัตโนมัติ: เสร็จก่อน 18:00 ทานใกล้โรงแรม ตั้งแต่ 18:00 ทานใกล้จุดสุดท้าย เปลี่ยนเองได้"],
        "dinnerArea": ["夕食のエリアを選ぶ", "저녁 식사 지역 선택", "选择晚餐区域", "Choose dinner area", "เลือกบริเวณมื้อเย็น"],
        "automatic": ["終了時刻に合わせて自動", "종료 시간에 따라 자동", "根据结束时间自动选择", "Automatic by finish time", "อัตโนมัติตามเวลาเที่ยวเสร็จ"],
        "nearHotel": ["ホテル周辺", "호텔 주변", "酒店附近", "Near the hotel", "ใกล้โรงแรม"],
        "nearLast": ["最後の観光地周辺", "마지막 관광지 주변", "最后景点附近", "Near the final stop", "ใกล้จุดเที่ยวสุดท้าย"],
        "findDinner": ["近くの夕食のお店を探す", "주변 저녁 식사 식당 찾기", "查找附近的晚餐餐厅", "Find nearby dinner restaurants", "ค้นหาร้านอาหารเย็นใกล้เคียง"],
        "searching": ["近くのお店を検索中…", "주변 식당 검색 중…", "正在搜索附近餐厅…", "Searching nearby restaurants…", "กำลังค้นหาร้านอาหารใกล้เคียง…"],
        "searchFailure": ["お店が見つからない、または通信できませんでした。再検索するか、地図で周辺のお店を確認してください。", "식당을 찾지 못했거나 연결할 수 없습니다. 다시 검색하거나 지도를 확인하세요.", "未找到餐厅或连接失败。请重试，或在地图查看附近餐厅。", "No restaurants were found or the connection failed. Retry or check nearby places on the map.", "ไม่พบร้านอาหารหรือเชื่อมต่อไม่ได้ ลองอีกครั้งหรือดูร้านใกล้เคียงบนแผนที่"],
        "moreDinner": ["地図で周辺のお店も見る", "지도에서 주변 식당 보기", "在地图查看周边餐厅", "Also browse nearby restaurants on the map", "ดูร้านอาหารใกล้เคียงบนแผนที่"],
        "distance": ["検索地点から直線で約%d m", "검색 지점에서 직선 약 %d m", "距搜索地点直线约%d米", "About %d m in a straight line from the search location", "ห่างจากจุดค้นหาประมาณ %d เมตรในแนวตรง"],
        "menuHours": ["メニュー・営業時間・料金を確認", "메뉴·영업시간·요금 확인", "查看菜单・营业时间・价格", "Check menu, hours and prices", "ดูเมนู เวลาเปิด และราคา"],
        "selectedDinner": ["選んだ夕食のお店", "선택한 저녁 식당", "已选晚餐餐厅", "Selected dinner restaurant", "ร้านมื้อเย็นที่เลือก"],
        "selectDinner": ["このお店で夕食にする", "이 식당에서 저녁 먹기", "选择这家餐厅吃晚餐", "Choose this restaurant for dinner", "เลือกร้านนี้สำหรับมื้อเย็น"],
        "dinnerThenHotel": ["食事後は「次の工程へ進む」でホテルへの帰り道を表示します。", "식사 후 다음 단계에서 호텔로 돌아가는 경로를 확인하세요.", "餐后点击进入下一步，查看返回酒店的路线。", "After dinner, continue to the next step for your route back to the hotel.", "หลังทานอาหาร ไปขั้นตอนถัดไปเพื่อดูเส้นทางกลับโรงแรม"],
        "dinnerCheck": ["営業時間・ラストオーダー・料金・予約の必要性は、お店の最新情報で確認してください。検索結果は営業中を保証するものではありません。", "영업시간, 주문 마감, 요금과 예약 필요 여부를 최신 정보로 확인하세요. 검색 결과가 영업 중임을 보장하지는 않습니다.", "请确认餐厅最新的营业时间、最后点餐时间、价格和预约要求。搜索结果不保证当前营业。", "Check current opening and last-order times, prices and booking requirements. Search results do not guarantee the restaurant is open.", "ตรวจสอบเวลาเปิด รับออเดอร์สุดท้าย ราคา และการจอง ข้อมูลค้นหาไม่ได้รับรองว่าร้านเปิดอยู่"],
        "nextDestination": ["次はここ・行き方を検索", "다음 목적지·경로 검색", "下一站・搜索路线", "Next destination · search directions", "จุดหมายถัดไป · ค้นหาเส้นทาง"],
        "timeEstimate": ["時刻は観光の計画用の目安です。ホテル移動・夕食の時間は含みません。", "시간은 관광 계획용 예상치입니다. 호텔 이동과 저녁 식사 시간은 포함되지 않습니다.", "时间为观光计划的估算，不含酒店往返和晚餐时间。", "Times estimate the sightseeing plan; hotel travel and dinner are additional.", "เวลาเป็นค่าประมาณสำหรับเที่ยวชม ไม่รวมเดินทางไปโรงแรมและมื้อเย็น"]
    ]
}

private struct RegionOption: Identifiable {
    let id: String
    let japanese: String
    let english: String
    var name: String { japanese }
}

private struct PrefectureOption: Identifiable, Decodable {
    let id: String
    let ja: String
    let en: String
    let region: String
}

private enum NationwideRoutes {
    static let routes: [DayRoute] = {
        let json = #"""
[{"id":"sapporo","prefecture":"hokkaido","label":"Sapporo · Odori","title":"Sapporo · Odori","description":"Four selected places in one area; follow the directions for each transfer.","area":"Sapporo central","gap":25,"stops":[{"type":"sight","duration":65,"choices":[["Odori Park","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%A4%A7%E9%80%9A%E5%85%AC%E5%9C%92%20%E5%8C%97%E6%B5%B7%E9%81%93"]]},{"type":"walk","duration":55,"choices":[["Sapporo TV Tower","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E3%81%95%E3%81%A3%E3%81%BD%E3%82%8D%E3%83%86%E3%83%AC%E3%83%93%E5%A1%94%20%E5%8C%97%E6%B5%B7%E9%81%93"]]},{"type":"food","duration":60,"choices":[["Lunch near Sapporo TV Tower","Choose a nearby restaurant for lunch.","https://www.google.com/maps/search/?api=1&query=%E3%83%AC%E3%82%B9%E3%83%88%E3%83%A9%E3%83%B3%20Sapporo%20TV%20Tower%20Sapporo%20central"]]},{"type":"sight","duration":75,"choices":[["Sapporo Clock Tower","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E6%9C%AD%E5%B9%8C%E5%B8%82%E6%99%82%E8%A8%88%E5%8F%B0%20%E5%8C%97%E6%B5%B7%E9%81%93"]]},{"type":"break","duration":55,"choices":[["Tanukikoji Shopping Street","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E7%8B%B8%E5%B0%8F%E8%B7%AF%E5%95%86%E5%BA%97%E8%A1%97%20%E5%8C%97%E6%B5%B7%E9%81%93"]]}]},{"id":"hakodate","prefecture":"hokkaido","label":"Hakodate · Harbor and Hills","title":"Hakodate · Harbor and Hills","description":"Four selected places in one area; follow the directions for each transfer.","area":"Hakodate Motomachi","gap":25,"stops":[{"type":"sight","duration":65,"choices":[["Hakodate Morning Market","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%87%BD%E9%A4%A8%E6%9C%9D%E5%B8%82%20%E5%8C%97%E6%B5%B7%E9%81%93"]]},{"type":"walk","duration":55,"choices":[["Kanemori Red Brick Warehouses","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E9%87%91%E6%A3%AE%E8%B5%A4%E3%83%AC%E3%83%B3%E3%82%AC%E5%80%89%E5%BA%AB%20%E5%8C%97%E6%B5%B7%E9%81%93"]]},{"type":"food","duration":60,"choices":[["Lunch near Kanemori Red Brick Warehouses","Choose a nearby restaurant for lunch.","https://www.google.com/maps/search/?api=1&query=%E3%83%AC%E3%82%B9%E3%83%88%E3%83%A9%E3%83%B3%20Kanemori%20Red%20Brick%20Warehouses%20Hakodate%20Motomachi"]]},{"type":"sight","duration":75,"choices":[["Hachimanzaka Slope","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%85%AB%E5%B9%A1%E5%9D%82%20%E5%8C%97%E6%B5%B7%E9%81%93"]]},{"type":"break","duration":55,"choices":[["Old Public Hall of Hakodate Ward","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E6%97%A7%E5%87%BD%E9%A4%A8%E5%8C%BA%E5%85%AC%E4%BC%9A%E5%A0%82%20%E5%8C%97%E6%B5%B7%E9%81%93"]]}]},{"id":"aomori-city","prefecture":"aomori","label":"Aomori · Bay and Nebuta","title":"Aomori · Bay and Nebuta","description":"Four selected places in one area; follow the directions for each transfer.","area":"Aomori Station","gap":25,"stops":[{"type":"sight","duration":65,"choices":[["Aomori Station","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E9%9D%92%E6%A3%AE%E9%A7%85%20%E9%9D%92%E6%A3%AE%E7%9C%8C"]]},{"type":"walk","duration":55,"choices":[["Nebuta Museum WA RASSE","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E3%81%AD%E3%81%B6%E3%81%9F%E3%81%AE%E5%AE%B6%20%E3%83%AF%E3%83%BB%E3%83%A9%E3%83%83%E3%82%BB%20%E9%9D%92%E6%A3%AE%E7%9C%8C"]]},{"type":"food","duration":60,"choices":[["Lunch near Nebuta Museum WA RASSE","Choose a nearby restaurant for lunch.","https://www.google.com/maps/search/?api=1&query=%E3%83%AC%E3%82%B9%E3%83%88%E3%83%A9%E3%83%B3%20Nebuta%20Museum%20WA%20RASSE%20Aomori%20Station"]]},{"type":"sight","duration":75,"choices":[["A-FACTORY Aomori","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=A-FACTORY%20%E9%9D%92%E6%A3%AE%E7%9C%8C"]]},{"type":"break","duration":55,"choices":[["Aomori ASPAM","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E9%9D%92%E6%A3%AE%E7%9C%8C%E8%A6%B3%E5%85%89%E7%89%A9%E7%94%A3%E9%A4%A8%E3%82%A2%E3%82%B9%E3%83%91%E3%83%A0%20%E9%9D%92%E6%A3%AE%E7%9C%8C"]]}]},{"id":"morioka","prefecture":"iwate","label":"Morioka · Castle Park","title":"Morioka · Castle Park","description":"Four selected places in one area; follow the directions for each transfer.","area":"Central Morioka","gap":25,"stops":[{"type":"sight","duration":65,"choices":[["Morioka Castle Ruins Park","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E7%9B%9B%E5%B2%A1%E5%9F%8E%E8%B7%A1%E5%85%AC%E5%9C%92%20%E5%B2%A9%E6%89%8B%E7%9C%8C"]]},{"type":"walk","duration":55,"choices":[["Morioka History and Culture Museum","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E3%82%82%E3%82%8A%E3%81%8A%E3%81%8B%E6%AD%B4%E5%8F%B2%E6%96%87%E5%8C%96%E9%A4%A8%20%E5%B2%A9%E6%89%8B%E7%9C%8C"]]},{"type":"food","duration":60,"choices":[["Lunch near Morioka History and Culture Museum","Choose a nearby restaurant for lunch.","https://www.google.com/maps/search/?api=1&query=%E3%83%AC%E3%82%B9%E3%83%88%E3%83%A9%E3%83%B3%20Morioka%20History%20and%20Culture%20Museum%20Central%20Morioka"]]},{"type":"sight","duration":75,"choices":[["Sakurayama Shrine Morioka","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E6%A1%9C%E5%B1%B1%E7%A5%9E%E7%A4%BE%20%E5%B2%A9%E6%89%8B%E7%9C%8C"]]},{"type":"break","duration":55,"choices":[["Iwate Bank Red Brick Building","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%B2%A9%E6%89%8B%E9%8A%80%E8%A1%8C%E8%B5%A4%E3%83%AC%E3%83%B3%E3%82%AC%E9%A4%A8%20%E5%B2%A9%E6%89%8B%E7%9C%8C"]]}]},{"id":"sendai","prefecture":"miyagi","label":"Sendai · Aoba and City","title":"Sendai · Aoba and City","description":"Four selected places in one area; follow the directions for each transfer.","area":"Central Sendai","gap":25,"stops":[{"type":"sight","duration":65,"choices":[["Sendai Station","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E4%BB%99%E5%8F%B0%E9%A7%85%20%E5%AE%AE%E5%9F%8E%E7%9C%8C"]]},{"type":"walk","duration":55,"choices":[["Zuihoden Sendai","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E7%91%9E%E9%B3%B3%E6%AE%BF%20%E5%AE%AE%E5%9F%8E%E7%9C%8C"]]},{"type":"food","duration":60,"choices":[["Lunch near Zuihoden Sendai","Choose a nearby restaurant for lunch.","https://www.google.com/maps/search/?api=1&query=%E3%83%AC%E3%82%B9%E3%83%88%E3%83%A9%E3%83%B3%20Zuihoden%20Sendai%20Central%20Sendai"]]},{"type":"sight","duration":75,"choices":[["Sendai Castle Ruins","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E4%BB%99%E5%8F%B0%E5%9F%8E%E8%B7%A1%20%E5%AE%AE%E5%9F%8E%E7%9C%8C"]]},{"type":"break","duration":55,"choices":[["Jozenji-dori Avenue","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%AE%9A%E7%A6%85%E5%AF%BA%E9%80%9A%20%E5%AE%AE%E5%9F%8E%E7%9C%8C"]]}]},{"id":"akita-city","prefecture":"akita","label":"Akita · Castle Park","title":"Akita · Castle Park","description":"Four selected places in one area; follow the directions for each transfer.","area":"Akita Station","gap":25,"stops":[{"type":"sight","duration":65,"choices":[["Akita Station","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E7%A7%8B%E7%94%B0%E9%A7%85%20%E7%A7%8B%E7%94%B0%E7%9C%8C"]]},{"type":"walk","duration":55,"choices":[["Senshu Park","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%8D%83%E7%A7%8B%E5%85%AC%E5%9C%92%20%E7%A7%8B%E7%94%B0%E7%9C%8C"]]},{"type":"food","duration":60,"choices":[["Lunch near Senshu Park","Choose a nearby restaurant for lunch.","https://www.google.com/maps/search/?api=1&query=%E3%83%AC%E3%82%B9%E3%83%88%E3%83%A9%E3%83%B3%20Senshu%20Park%20Akita%20Station"]]},{"type":"sight","duration":75,"choices":[["Akita Museum of Art","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E7%A7%8B%E7%94%B0%E7%9C%8C%E7%AB%8B%E7%BE%8E%E8%A1%93%E9%A4%A8%20%E7%A7%8B%E7%94%B0%E7%9C%8C"]]},{"type":"break","duration":55,"choices":[["Akita Citizen Market","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E7%A7%8B%E7%94%B0%E5%B8%82%E6%B0%91%E5%B8%82%E5%A0%B4%20%E7%A7%8B%E7%94%B0%E7%9C%8C"]]}]},{"id":"yamagata-city","prefecture":"yamagata","label":"Yamagata · Castle and Bunshokan","title":"Yamagata · Castle and Bunshokan","description":"Four selected places in one area; follow the directions for each transfer.","area":"Central Yamagata","gap":25,"stops":[{"type":"sight","duration":65,"choices":[["Yamagata Station","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%B1%B1%E5%BD%A2%E9%A7%85%20%E5%B1%B1%E5%BD%A2%E7%9C%8C"]]},{"type":"walk","duration":55,"choices":[["Kajo Park Yamagata","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E9%9C%9E%E5%9F%8E%E5%85%AC%E5%9C%92%20%E5%B1%B1%E5%BD%A2%E7%9C%8C"]]},{"type":"food","duration":60,"choices":[["Lunch near Kajo Park Yamagata","Choose a nearby restaurant for lunch.","https://www.google.com/maps/search/?api=1&query=%E3%83%AC%E3%82%B9%E3%83%88%E3%83%A9%E3%83%B3%20Kajo%20Park%20Yamagata%20Central%20Yamagata"]]},{"type":"sight","duration":75,"choices":[["Yamagata Museum of Art","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%B1%B1%E5%BD%A2%E7%BE%8E%E8%A1%93%E9%A4%A8%20%E5%B1%B1%E5%BD%A2%E7%9C%8C"]]},{"type":"break","duration":55,"choices":[["Bunshokan Yamagata","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E6%96%87%E7%BF%94%E9%A4%A8%20%E5%B1%B1%E5%BD%A2%E7%9C%8C"]]}]},{"id":"aizu","prefecture":"fukushima","label":"Aizu · Castle and Streets","title":"Aizu · Castle and Streets","description":"Four selected places in one area; follow the directions for each transfer.","area":"Aizuwakamatsu","gap":25,"stops":[{"type":"sight","duration":65,"choices":[["Aizuwakamatsu Station","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E4%BC%9A%E6%B4%A5%E8%8B%A5%E6%9D%BE%E9%A7%85%20%E7%A6%8F%E5%B3%B6%E7%9C%8C"]]},{"type":"walk","duration":55,"choices":[["Tsuruga Castle Aizu","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E9%B6%B4%E3%83%B6%E5%9F%8E%20%E7%A6%8F%E5%B3%B6%E7%9C%8C"]]},{"type":"food","duration":60,"choices":[["Lunch near Tsuruga Castle Aizu","Choose a nearby restaurant for lunch.","https://www.google.com/maps/search/?api=1&query=%E3%83%AC%E3%82%B9%E3%83%88%E3%83%A9%E3%83%B3%20Tsuruga%20Castle%20Aizu%20Aizuwakamatsu"]]},{"type":"sight","duration":75,"choices":[["Oyakuen Garden Aizu","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%BE%A1%E8%96%AC%E5%9C%92%20%E7%A6%8F%E5%B3%B6%E7%9C%8C"]]},{"type":"break","duration":55,"choices":[["Nanokamachi Street Aizu","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E4%B8%83%E6%97%A5%E7%94%BA%E9%80%9A%E3%82%8A%20%E7%A6%8F%E5%B3%B6%E7%9C%8C"]]}]},{"id":"mito","prefecture":"ibaraki","label":"Mito · Kairakuen","title":"Mito · Kairakuen","description":"Four selected places in one area; follow the directions for each transfer.","area":"Central Mito","gap":25,"stops":[{"type":"sight","duration":65,"choices":[["Mito Station","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E6%B0%B4%E6%88%B8%E9%A7%85%20%E8%8C%A8%E5%9F%8E%E7%9C%8C"]]},{"type":"walk","duration":55,"choices":[["Kodokan Mito","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%BC%98%E9%81%93%E9%A4%A8%20%E8%8C%A8%E5%9F%8E%E7%9C%8C"]]},{"type":"food","duration":60,"choices":[["Lunch near Kodokan Mito","Choose a nearby restaurant for lunch.","https://www.google.com/maps/search/?api=1&query=%E3%83%AC%E3%82%B9%E3%83%88%E3%83%A9%E3%83%B3%20Kodokan%20Mito%20Central%20Mito"]]},{"type":"sight","duration":75,"choices":[["Kairakuen Garden","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%81%95%E6%A5%BD%E5%9C%92%20%E8%8C%A8%E5%9F%8E%E7%9C%8C"]]},{"type":"break","duration":55,"choices":[["Lake Senba","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%8D%83%E6%B3%A2%E6%B9%96%20%E8%8C%A8%E5%9F%8E%E7%9C%8C"]]}]},{"id":"nikko","prefecture":"tochigi","label":"Nikko · Shrines and Temples","title":"Nikko · Shrines and Temples","description":"Four selected places in one area; follow the directions for each transfer.","area":"Nikko shrines","gap":25,"stops":[{"type":"sight","duration":65,"choices":[["Shinkyo Bridge Nikko","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E7%A5%9E%E6%A9%8B%20%E6%A0%83%E6%9C%A8%E7%9C%8C"]]},{"type":"walk","duration":55,"choices":[["Rinnoji Temple Nikko","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E8%BC%AA%E7%8E%8B%E5%AF%BA%20%E6%A0%83%E6%9C%A8%E7%9C%8C"]]},{"type":"food","duration":60,"choices":[["Lunch near Rinnoji Temple Nikko","Choose a nearby restaurant for lunch.","https://www.google.com/maps/search/?api=1&query=%E3%83%AC%E3%82%B9%E3%83%88%E3%83%A9%E3%83%B3%20Rinnoji%20Temple%20Nikko%20Nikko%20shrines"]]},{"type":"sight","duration":75,"choices":[["Nikko Toshogu Shrine","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E6%97%A5%E5%85%89%E6%9D%B1%E7%85%A7%E5%AE%AE%20%E6%A0%83%E6%9C%A8%E7%9C%8C"]]},{"type":"break","duration":55,"choices":[["Nikko Futarasan Shrine","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E6%97%A5%E5%85%89%E4%BA%8C%E8%8D%92%E5%B1%B1%E7%A5%9E%E7%A4%BE%20%E6%A0%83%E6%9C%A8%E7%9C%8C"]]}]},{"id":"kusatsu","prefecture":"gunma","label":"Kusatsu · Onsen Town","title":"Kusatsu · Onsen Town","description":"Four selected places in one area; follow the directions for each transfer.","area":"Kusatsu Onsen","gap":25,"stops":[{"type":"sight","duration":65,"choices":[["Kusatsu Onsen Bus Terminal","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E8%8D%89%E6%B4%A5%E6%B8%A9%E6%B3%89%E3%83%90%E3%82%B9%E3%82%BF%E3%83%BC%E3%83%9F%E3%83%8A%E3%83%AB%20%E7%BE%A4%E9%A6%AC%E7%9C%8C"]]},{"type":"walk","duration":55,"choices":[["Yubatake Kusatsu","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E6%B9%AF%E7%95%91%20%E7%BE%A4%E9%A6%AC%E7%9C%8C"]]},{"type":"food","duration":60,"choices":[["Lunch near Yubatake Kusatsu","Choose a nearby restaurant for lunch.","https://www.google.com/maps/search/?api=1&query=%E3%83%AC%E3%82%B9%E3%83%88%E3%83%A9%E3%83%B3%20Yubatake%20Kusatsu%20Kusatsu%20Onsen"]]},{"type":"sight","duration":75,"choices":[["Netsunoyu Kusatsu","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E7%86%B1%E4%B9%83%E6%B9%AF%20%E7%BE%A4%E9%A6%AC%E7%9C%8C"]]},{"type":"break","duration":55,"choices":[["Sainokawara Park Kusatsu","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E8%A5%BF%E3%81%AE%E6%B2%B3%E5%8E%9F%E5%85%AC%E5%9C%92%20%E7%BE%A4%E9%A6%AC%E7%9C%8C"]]}]},{"id":"kawagoe","prefecture":"saitama","label":"Kawagoe · Little Edo","title":"Kawagoe · Little Edo","description":"Four selected places in one area; follow the directions for each transfer.","area":"Central Kawagoe","gap":25,"stops":[{"type":"sight","duration":65,"choices":[["Kawagoe Ichibangai","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%B7%9D%E8%B6%8A%E4%B8%80%E7%95%AA%E8%A1%97%20%E5%9F%BC%E7%8E%89%E7%9C%8C"]]},{"type":"walk","duration":55,"choices":[["Toki no Kane Kawagoe","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E6%99%82%E3%81%AE%E9%90%98%20%E5%9F%BC%E7%8E%89%E7%9C%8C"]]},{"type":"food","duration":60,"choices":[["Lunch near Toki no Kane Kawagoe","Choose a nearby restaurant for lunch.","https://www.google.com/maps/search/?api=1&query=%E3%83%AC%E3%82%B9%E3%83%88%E3%83%A9%E3%83%B3%20Toki%20no%20Kane%20Kawagoe%20Central%20Kawagoe"]]},{"type":"sight","duration":75,"choices":[["Kashiya Yokocho","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E8%8F%93%E5%AD%90%E5%B1%8B%E6%A8%AA%E4%B8%81%20%E5%9F%BC%E7%8E%89%E7%9C%8C"]]},{"type":"break","duration":55,"choices":[["Kawagoe Hikawa Shrine","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%B7%9D%E8%B6%8A%E6%B0%B7%E5%B7%9D%E7%A5%9E%E7%A4%BE%20%E5%9F%BC%E7%8E%89%E7%9C%8C"]]}]},{"id":"narita","prefecture":"chiba","label":"Narita · Temple Town","title":"Narita · Temple Town","description":"Four selected places in one area; follow the directions for each transfer.","area":"Naritasan","gap":25,"stops":[{"type":"sight","duration":65,"choices":[["Narita Station","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E6%88%90%E7%94%B0%E9%A7%85%20%E5%8D%83%E8%91%89%E7%9C%8C"]]},{"type":"walk","duration":55,"choices":[["Naritasan Omotesando","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E6%88%90%E7%94%B0%E5%B1%B1%E8%A1%A8%E5%8F%82%E9%81%93%20%E5%8D%83%E8%91%89%E7%9C%8C"]]},{"type":"food","duration":60,"choices":[["Lunch near Naritasan Omotesando","Choose a nearby restaurant for lunch.","https://www.google.com/maps/search/?api=1&query=%E3%83%AC%E3%82%B9%E3%83%88%E3%83%A9%E3%83%B3%20Naritasan%20Omotesando%20Naritasan"]]},{"type":"sight","duration":75,"choices":[["Naritasan Shinshoji Temple","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E6%88%90%E7%94%B0%E5%B1%B1%E6%96%B0%E5%8B%9D%E5%AF%BA%20%E5%8D%83%E8%91%89%E7%9C%8C"]]},{"type":"break","duration":55,"choices":[["Naritasan Park","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E6%88%90%E7%94%B0%E5%B1%B1%E5%85%AC%E5%9C%92%20%E5%8D%83%E8%91%89%E7%9C%8C"]]}]},{"id":"shibuya","prefecture":"tokyo","label":"Shibuya · Harajuku","title":"Shibuya · Harajuku","description":"Four selected places in one area; follow the directions for each transfer.","area":"Harajuku and Shibuya","gap":25,"stops":[{"type":"sight","duration":65,"choices":[["Meiji Jingu Shrine","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E6%98%8E%E6%B2%BB%E7%A5%9E%E5%AE%AE%20%E6%9D%B1%E4%BA%AC%E9%83%BD"]]},{"type":"walk","duration":55,"choices":[["Takeshita Street","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E7%AB%B9%E4%B8%8B%E9%80%9A%E3%82%8A%20%E6%9D%B1%E4%BA%AC%E9%83%BD"]]},{"type":"food","duration":60,"choices":[["Lunch near Takeshita Street","Choose a nearby restaurant for lunch.","https://www.google.com/maps/search/?api=1&query=%E3%83%AC%E3%82%B9%E3%83%88%E3%83%A9%E3%83%B3%20Takeshita%20Street%20Harajuku%20and%20Shibuya"]]},{"type":"sight","duration":75,"choices":[["Omotesando Tokyo","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E8%A1%A8%E5%8F%82%E9%81%93%20%E6%9D%B1%E4%BA%AC%E9%83%BD"]]},{"type":"break","duration":55,"choices":[["Hachiko Square Shibuya","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E3%83%8F%E3%83%81%E5%85%AC%E5%89%8D%E5%BA%83%E5%A0%B4%20%E6%9D%B1%E4%BA%AC%E9%83%BD"]]}]},{"id":"yokohama","prefecture":"kanagawa","label":"Yokohama · Waterfront","title":"Yokohama · Waterfront","description":"Four selected places in one area; follow the directions for each transfer.","area":"Minato Mirai","gap":25,"stops":[{"type":"sight","duration":65,"choices":[["Yokohama Red Brick Warehouse","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E6%A8%AA%E6%B5%9C%E8%B5%A4%E3%83%AC%E3%83%B3%E3%82%AC%E5%80%89%E5%BA%AB%20%E7%A5%9E%E5%A5%88%E5%B7%9D%E7%9C%8C"]]},{"type":"walk","duration":55,"choices":[["Osanbashi Pier Yokohama","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%A4%A7%E3%81%95%E3%82%93%E6%A9%8B%20%E7%A5%9E%E5%A5%88%E5%B7%9D%E7%9C%8C"]]},{"type":"food","duration":60,"choices":[["Lunch near Osanbashi Pier Yokohama","Choose a nearby restaurant for lunch.","https://www.google.com/maps/search/?api=1&query=%E3%83%AC%E3%82%B9%E3%83%88%E3%83%A9%E3%83%B3%20Osanbashi%20Pier%20Yokohama%20Minato%20Mirai"]]},{"type":"sight","duration":75,"choices":[["Yamashita Park","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%B1%B1%E4%B8%8B%E5%85%AC%E5%9C%92%20%E7%A5%9E%E5%A5%88%E5%B7%9D%E7%9C%8C"]]},{"type":"break","duration":55,"choices":[["Yokohama Chinatown","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E6%A8%AA%E6%B5%9C%E4%B8%AD%E8%8F%AF%E8%A1%97%20%E7%A5%9E%E5%A5%88%E5%B7%9D%E7%9C%8C"]]}]},{"id":"niigata-city","prefecture":"niigata","label":"Niigata · River and Bay","title":"Niigata · River and Bay","description":"Four selected places in one area; follow the directions for each transfer.","area":"Central Niigata","gap":25,"stops":[{"type":"sight","duration":65,"choices":[["Niigata Station","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E6%96%B0%E6%BD%9F%E9%A7%85%20%E6%96%B0%E6%BD%9F%E7%9C%8C"]]},{"type":"walk","duration":55,"choices":[["Bandai Bridge Niigata","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E8%90%AC%E4%BB%A3%E6%A9%8B%20%E6%96%B0%E6%BD%9F%E7%9C%8C"]]},{"type":"food","duration":60,"choices":[["Lunch near Bandai Bridge Niigata","Choose a nearby restaurant for lunch.","https://www.google.com/maps/search/?api=1&query=%E3%83%AC%E3%82%B9%E3%83%88%E3%83%A9%E3%83%B3%20Bandai%20Bridge%20Niigata%20Central%20Niigata"]]},{"type":"sight","duration":75,"choices":[["Pier Bandai","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E3%83%94%E3%82%A2Bandai%20%E6%96%B0%E6%BD%9F%E7%9C%8C"]]},{"type":"break","duration":55,"choices":[["Toki Messe Niigata","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E6%9C%B1%E9%B7%BA%E3%83%A1%E3%83%83%E3%82%BB%20%E6%96%B0%E6%BD%9F%E7%9C%8C"]]}]},{"id":"toyama-city","prefecture":"toyama","label":"Toyama · Canal and Glass","title":"Toyama · Canal and Glass","description":"Four selected places in one area; follow the directions for each transfer.","area":"Central Toyama","gap":25,"stops":[{"type":"sight","duration":65,"choices":[["Toyama Station","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%AF%8C%E5%B1%B1%E9%A7%85%20%E5%AF%8C%E5%B1%B1%E7%9C%8C"]]},{"type":"walk","duration":55,"choices":[["Kansui Park Toyama","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%AF%8C%E5%B2%A9%E9%81%8B%E6%B2%B3%E7%92%B0%E6%B0%B4%E5%85%AC%E5%9C%92%20%E5%AF%8C%E5%B1%B1%E7%9C%8C"]]},{"type":"food","duration":60,"choices":[["Lunch near Kansui Park Toyama","Choose a nearby restaurant for lunch.","https://www.google.com/maps/search/?api=1&query=%E3%83%AC%E3%82%B9%E3%83%88%E3%83%A9%E3%83%B3%20Kansui%20Park%20Toyama%20Central%20Toyama"]]},{"type":"sight","duration":75,"choices":[["Toyama Glass Art Museum","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%AF%8C%E5%B1%B1%E5%B8%82%E3%82%AC%E3%83%A9%E3%82%B9%E7%BE%8E%E8%A1%93%E9%A4%A8%20%E5%AF%8C%E5%B1%B1%E7%9C%8C"]]},{"type":"break","duration":55,"choices":[["Toyama Castle Park","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%AF%8C%E5%B1%B1%E5%9F%8E%E5%9D%80%E5%85%AC%E5%9C%92%20%E5%AF%8C%E5%B1%B1%E7%9C%8C"]]}]},{"id":"kanazawa","prefecture":"ishikawa","label":"Kanazawa · Gardens","title":"Kanazawa · Gardens","description":"Four selected places in one area; follow the directions for each transfer.","area":"Central Kanazawa","gap":25,"stops":[{"type":"sight","duration":65,"choices":[["Omicho Market Kanazawa","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E8%BF%91%E6%B1%9F%E7%94%BA%E5%B8%82%E5%A0%B4%20%E7%9F%B3%E5%B7%9D%E7%9C%8C"]]},{"type":"walk","duration":55,"choices":[["Kanazawa Castle Park","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E9%87%91%E6%B2%A2%E5%9F%8E%E5%85%AC%E5%9C%92%20%E7%9F%B3%E5%B7%9D%E7%9C%8C"]]},{"type":"food","duration":60,"choices":[["Lunch near Kanazawa Castle Park","Choose a nearby restaurant for lunch.","https://www.google.com/maps/search/?api=1&query=%E3%83%AC%E3%82%B9%E3%83%88%E3%83%A9%E3%83%B3%20Kanazawa%20Castle%20Park%20Central%20Kanazawa"]]},{"type":"sight","duration":75,"choices":[["Kenrokuen Garden","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%85%BC%E5%85%AD%E5%9C%92%20%E7%9F%B3%E5%B7%9D%E7%9C%8C"]]},{"type":"break","duration":55,"choices":[["Higashi Chaya District","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E3%81%B2%E3%81%8C%E3%81%97%E8%8C%B6%E5%B1%8B%E8%A1%97%20%E7%9F%B3%E5%B7%9D%E7%9C%8C"]]}]},{"id":"fukui-city","prefecture":"fukui","label":"Fukui · Castle and Garden","title":"Fukui · Castle and Garden","description":"Four selected places in one area; follow the directions for each transfer.","area":"Central Fukui","gap":25,"stops":[{"type":"sight","duration":65,"choices":[["Fukui Station","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E7%A6%8F%E4%BA%95%E9%A7%85%20%E7%A6%8F%E4%BA%95%E7%9C%8C"]]},{"type":"walk","duration":55,"choices":[["Fukui Castle Ruins","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E7%A6%8F%E4%BA%95%E5%9F%8E%E5%9D%80%20%E7%A6%8F%E4%BA%95%E7%9C%8C"]]},{"type":"food","duration":60,"choices":[["Lunch near Fukui Castle Ruins","Choose a nearby restaurant for lunch.","https://www.google.com/maps/search/?api=1&query=%E3%83%AC%E3%82%B9%E3%83%88%E3%83%A9%E3%83%B3%20Fukui%20Castle%20Ruins%20Central%20Fukui"]]},{"type":"sight","duration":75,"choices":[["Fukui City History Museum","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E7%A6%8F%E4%BA%95%E5%B8%82%E7%AB%8B%E9%83%B7%E5%9C%9F%E6%AD%B4%E5%8F%B2%E5%8D%9A%E7%89%A9%E9%A4%A8%20%E7%A6%8F%E4%BA%95%E7%9C%8C"]]},{"type":"break","duration":55,"choices":[["Yokokan Garden Fukui","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E9%A4%8A%E6%B5%A9%E9%A4%A8%E5%BA%AD%E5%9C%92%20%E7%A6%8F%E4%BA%95%E7%9C%8C"]]}]},{"id":"kofu","prefecture":"yamanashi","label":"Kofu · Castle and Shrine","title":"Kofu · Castle and Shrine","description":"Four selected places in one area; follow the directions for each transfer.","area":"Central Kofu","gap":25,"stops":[{"type":"sight","duration":65,"choices":[["Kofu Station","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E7%94%B2%E5%BA%9C%E9%A7%85%20%E5%B1%B1%E6%A2%A8%E7%9C%8C"]]},{"type":"walk","duration":55,"choices":[["Maizuru Castle Park Kofu","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E8%88%9E%E9%B6%B4%E5%9F%8E%E5%85%AC%E5%9C%92%20%E5%B1%B1%E6%A2%A8%E7%9C%8C"]]},{"type":"food","duration":60,"choices":[["Lunch near Maizuru Castle Park Kofu","Choose a nearby restaurant for lunch.","https://www.google.com/maps/search/?api=1&query=%E3%83%AC%E3%82%B9%E3%83%88%E3%83%A9%E3%83%B3%20Maizuru%20Castle%20Park%20Kofu%20Central%20Kofu"]]},{"type":"sight","duration":75,"choices":[["Fujimura Memorial Hall Kofu","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E7%94%B2%E5%BA%9C%E5%B8%82%E8%97%A4%E6%9D%91%E8%A8%98%E5%BF%B5%E9%A4%A8%20%E5%B1%B1%E6%A2%A8%E7%9C%8C"]]},{"type":"break","duration":55,"choices":[["Takeda Shrine Kofu","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E6%AD%A6%E7%94%B0%E7%A5%9E%E7%A4%BE%20%E5%B1%B1%E6%A2%A8%E7%9C%8C"]]}]},{"id":"nagano-city","prefecture":"nagano","label":"Nagano · Zenkoji","title":"Nagano · Zenkoji","description":"Four selected places in one area; follow the directions for each transfer.","area":"Central Nagano","gap":25,"stops":[{"type":"sight","duration":65,"choices":[["Nagano Station","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E9%95%B7%E9%87%8E%E9%A7%85%20%E9%95%B7%E9%87%8E%E7%9C%8C"]]},{"type":"walk","duration":55,"choices":[["Zenkoji Approach","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%96%84%E5%85%89%E5%AF%BA%E8%A1%A8%E5%8F%82%E9%81%93%20%E9%95%B7%E9%87%8E%E7%9C%8C"]]},{"type":"food","duration":60,"choices":[["Lunch near Zenkoji Approach","Choose a nearby restaurant for lunch.","https://www.google.com/maps/search/?api=1&query=%E3%83%AC%E3%82%B9%E3%83%88%E3%83%A9%E3%83%B3%20Zenkoji%20Approach%20Central%20Nagano"]]},{"type":"sight","duration":75,"choices":[["Zenkoji Temple Nagano","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%96%84%E5%85%89%E5%AF%BA%20%E9%95%B7%E9%87%8E%E7%9C%8C"]]},{"type":"break","duration":55,"choices":[["Nagano Prefectural Art Museum","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E9%95%B7%E9%87%8E%E7%9C%8C%E7%AB%8B%E7%BE%8E%E8%A1%93%E9%A4%A8%20%E9%95%B7%E9%87%8E%E7%9C%8C"]]}]},{"id":"takayama","prefecture":"gifu","label":"Takayama · Old Town","title":"Takayama · Old Town","description":"Four selected places in one area; follow the directions for each transfer.","area":"Takayama","gap":25,"stops":[{"type":"sight","duration":65,"choices":[["Takayama Station","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E9%AB%98%E5%B1%B1%E9%A7%85%20%E5%B2%90%E9%98%9C%E7%9C%8C"]]},{"type":"walk","duration":55,"choices":[["Miyagawa Morning Market","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%AE%AE%E5%B7%9D%E6%9C%9D%E5%B8%82%20%E5%B2%90%E9%98%9C%E7%9C%8C"]]},{"type":"food","duration":60,"choices":[["Lunch near Miyagawa Morning Market","Choose a nearby restaurant for lunch.","https://www.google.com/maps/search/?api=1&query=%E3%83%AC%E3%82%B9%E3%83%88%E3%83%A9%E3%83%B3%20Miyagawa%20Morning%20Market%20Takayama"]]},{"type":"sight","duration":75,"choices":[["Takayama Jinya","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E9%AB%98%E5%B1%B1%E9%99%A3%E5%B1%8B%20%E5%B2%90%E9%98%9C%E7%9C%8C"]]},{"type":"break","duration":55,"choices":[["Takayama Old Town","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%8F%A4%E3%81%84%E7%94%BA%E4%B8%A6%20%E5%B2%90%E9%98%9C%E7%9C%8C"]]}]},{"id":"shizuoka-city","prefecture":"shizuoka","label":"Shizuoka · Castle Park","title":"Shizuoka · Castle Park","description":"Four selected places in one area; follow the directions for each transfer.","area":"Central Shizuoka","gap":25,"stops":[{"type":"sight","duration":65,"choices":[["Shizuoka Station","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E9%9D%99%E5%B2%A1%E9%A7%85%20%E9%9D%99%E5%B2%A1%E7%9C%8C"]]},{"type":"walk","duration":55,"choices":[["Sumpu Castle Park","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E9%A7%BF%E5%BA%9C%E5%9F%8E%E5%85%AC%E5%9C%92%20%E9%9D%99%E5%B2%A1%E7%9C%8C"]]},{"type":"food","duration":60,"choices":[["Lunch near Sumpu Castle Park","Choose a nearby restaurant for lunch.","https://www.google.com/maps/search/?api=1&query=%E3%83%AC%E3%82%B9%E3%83%88%E3%83%A9%E3%83%B3%20Sumpu%20Castle%20Park%20Central%20Shizuoka"]]},{"type":"sight","duration":75,"choices":[["Shizuoka City Museum of History","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E9%9D%99%E5%B2%A1%E5%B8%82%E6%AD%B4%E5%8F%B2%E5%8D%9A%E7%89%A9%E9%A4%A8%20%E9%9D%99%E5%B2%A1%E7%9C%8C"]]},{"type":"break","duration":55,"choices":[["Aoba Symbol Road Shizuoka","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E9%9D%92%E8%91%89%E3%82%B7%E3%83%B3%E3%83%9C%E3%83%AB%E3%83%AD%E3%83%BC%E3%83%89%20%E9%9D%99%E5%B2%A1%E7%9C%8C"]]}]},{"id":"nagoya-castle","prefecture":"aichi","label":"Nagoya · Castle and Sakae","title":"Nagoya · Castle and Sakae","description":"Four selected places in one area; follow the directions for each transfer.","area":"Nagoya Castle","gap":25,"stops":[{"type":"sight","duration":65,"choices":[["Nagoya Castle","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%90%8D%E5%8F%A4%E5%B1%8B%E5%9F%8E%20%E6%84%9B%E7%9F%A5%E7%9C%8C"]]},{"type":"walk","duration":55,"choices":[["Meijo Park","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%90%8D%E5%9F%8E%E5%85%AC%E5%9C%92%20%E6%84%9B%E7%9F%A5%E7%9C%8C"]]},{"type":"food","duration":60,"choices":[["Lunch near Meijo Park","Choose a nearby restaurant for lunch.","https://www.google.com/maps/search/?api=1&query=%E3%83%AC%E3%82%B9%E3%83%88%E3%83%A9%E3%83%B3%20Meijo%20Park%20Nagoya%20Castle"]]},{"type":"sight","duration":75,"choices":[["Hisaya Odori Park","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E4%B9%85%E5%B1%8B%E5%A4%A7%E9%80%9A%E5%85%AC%E5%9C%92%20%E6%84%9B%E7%9F%A5%E7%9C%8C"]]},{"type":"break","duration":55,"choices":[["Oasis 21 Nagoya","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E3%82%AA%E3%82%A2%E3%82%B7%E3%82%B921%20%E6%84%9B%E7%9F%A5%E7%9C%8C"]]}]},{"id":"nagoya-atsuta","prefecture":"aichi","label":"Nagoya · Atsuta","title":"Nagoya · Atsuta","description":"Four selected places in one area; follow the directions for each transfer.","area":"Atsuta Nagoya","gap":25,"stops":[{"type":"sight","duration":65,"choices":[["Atsuta Jingu Shrine","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E7%86%B1%E7%94%B0%E7%A5%9E%E5%AE%AE%20%E6%84%9B%E7%9F%A5%E7%9C%8C"]]},{"type":"walk","duration":55,"choices":[["Atsuta Jingu Treasure Hall","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E7%86%B1%E7%94%B0%E7%A5%9E%E5%AE%AE%E5%AE%9D%E7%89%A9%E9%A4%A8%20%E6%84%9B%E7%9F%A5%E7%9C%8C"]]},{"type":"food","duration":60,"choices":[["Lunch near Atsuta Jingu Treasure Hall","Choose a nearby restaurant for lunch.","https://www.google.com/maps/search/?api=1&query=%E3%83%AC%E3%82%B9%E3%83%88%E3%83%A9%E3%83%B3%20Atsuta%20Jingu%20Treasure%20Hall%20Atsuta%20Nagoya"]]},{"type":"sight","duration":75,"choices":[["Shirotori Garden Nagoya","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E7%99%BD%E9%B3%A5%E5%BA%AD%E5%9C%92%20%E6%84%9B%E7%9F%A5%E7%9C%8C"]]},{"type":"break","duration":55,"choices":[["Miya no Watashi Park Nagoya","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%AE%AE%E3%81%AE%E6%B8%A1%E3%81%97%E5%85%AC%E5%9C%92%20%E6%84%9B%E7%9F%A5%E7%9C%8C"]]}]},{"id":"ise","prefecture":"mie","label":"Ise · Shrine Town","title":"Ise · Shrine Town","description":"Four selected places in one area; follow the directions for each transfer.","area":"Ise","gap":25,"stops":[{"type":"sight","duration":65,"choices":[["Iseshi Station","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E4%BC%8A%E5%8B%A2%E5%B8%82%E9%A7%85%20%E4%B8%89%E9%87%8D%E7%9C%8C"]]},{"type":"walk","duration":55,"choices":[["Ise Jingu Geku","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E4%BC%8A%E5%8B%A2%E7%A5%9E%E5%AE%AE%20%E5%A4%96%E5%AE%AE%20%E4%B8%89%E9%87%8D%E7%9C%8C"]]},{"type":"food","duration":60,"choices":[["Lunch near Ise Jingu Geku","Choose a nearby restaurant for lunch.","https://www.google.com/maps/search/?api=1&query=%E3%83%AC%E3%82%B9%E3%83%88%E3%83%A9%E3%83%B3%20Ise%20Jingu%20Geku%20Ise"]]},{"type":"sight","duration":75,"choices":[["Sarutahiko Shrine Ise","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E7%8C%BF%E7%94%B0%E5%BD%A6%E7%A5%9E%E7%A4%BE%20%E4%B8%89%E9%87%8D%E7%9C%8C"]]},{"type":"break","duration":55,"choices":[["Okage Yokocho Ise","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E3%81%8A%E3%81%8B%E3%81%92%E6%A8%AA%E4%B8%81%20%E4%B8%89%E9%87%8D%E7%9C%8C"]]}]},{"id":"hikone","prefecture":"shiga","label":"Hikone · Castle Town","title":"Hikone · Castle Town","description":"Four selected places in one area; follow the directions for each transfer.","area":"Hikone Castle","gap":25,"stops":[{"type":"sight","duration":65,"choices":[["Hikone Station","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%BD%A6%E6%A0%B9%E9%A7%85%20%E6%BB%8B%E8%B3%80%E7%9C%8C"]]},{"type":"walk","duration":55,"choices":[["Hikone Castle","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%BD%A6%E6%A0%B9%E5%9F%8E%20%E6%BB%8B%E8%B3%80%E7%9C%8C"]]},{"type":"food","duration":60,"choices":[["Lunch near Hikone Castle","Choose a nearby restaurant for lunch.","https://www.google.com/maps/search/?api=1&query=%E3%83%AC%E3%82%B9%E3%83%88%E3%83%A9%E3%83%B3%20Hikone%20Castle%20Hikone%20Castle"]]},{"type":"sight","duration":75,"choices":[["Genkyuen Garden Hikone","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E7%8E%84%E5%AE%AE%E5%9C%92%20%E6%BB%8B%E8%B3%80%E7%9C%8C"]]},{"type":"break","duration":55,"choices":[["Yume Kyobashi Castle Road","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%A4%A2%E4%BA%AC%E6%A9%8B%E3%82%AD%E3%83%A3%E3%83%83%E3%82%B9%E3%83%AB%E3%83%AD%E3%83%BC%E3%83%89%20%E6%BB%8B%E8%B3%80%E7%9C%8C"]]}]},{"id":"arashiyama","prefecture":"kyoto","label":"Kyoto · Arashiyama","title":"Kyoto · Arashiyama","description":"Four selected places in one area; follow the directions for each transfer.","area":"Arashiyama","gap":25,"stops":[{"type":"sight","duration":65,"choices":[["Togetsukyo Bridge Kyoto","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E6%B8%A1%E6%9C%88%E6%A9%8B%20%E4%BA%AC%E9%83%BD%E5%BA%9C"]]},{"type":"walk","duration":55,"choices":[["Tenryuji Temple Kyoto","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%A4%A9%E9%BE%8D%E5%AF%BA%20%E4%BA%AC%E9%83%BD%E5%BA%9C"]]},{"type":"food","duration":60,"choices":[["Lunch near Tenryuji Temple Kyoto","Choose a nearby restaurant for lunch.","https://www.google.com/maps/search/?api=1&query=%E3%83%AC%E3%82%B9%E3%83%88%E3%83%A9%E3%83%B3%20Tenryuji%20Temple%20Kyoto%20Arashiyama"]]},{"type":"sight","duration":75,"choices":[["Arashiyama Bamboo Grove","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%B5%AF%E5%B3%A8%E9%87%8E%E7%AB%B9%E6%9E%97%E3%81%AE%E5%B0%8F%E5%BE%84%20%E4%BA%AC%E9%83%BD%E5%BA%9C"]]},{"type":"break","duration":55,"choices":[["Nonomiya Shrine Kyoto","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E9%87%8E%E5%AE%AE%E7%A5%9E%E7%A4%BE%20%E4%BA%AC%E9%83%BD%E5%BA%9C"]]}]},{"id":"fushimi","prefecture":"kyoto","label":"Kyoto · Fushimi and Higashiyama","title":"Kyoto · Fushimi and Higashiyama","description":"Four selected places in one area; follow the directions for each transfer.","area":"Fushimi Inari","gap":25,"stops":[{"type":"sight","duration":65,"choices":[["Fushimi Inari Station","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E4%BC%8F%E8%A6%8B%E7%A8%B2%E8%8D%B7%E9%A7%85%20%E4%BA%AC%E9%83%BD%E5%BA%9C"]]},{"type":"walk","duration":55,"choices":[["Fushimi Inari Taisha","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E4%BC%8F%E8%A6%8B%E7%A8%B2%E8%8D%B7%E5%A4%A7%E7%A4%BE%20%E4%BA%AC%E9%83%BD%E5%BA%9C"]]},{"type":"food","duration":60,"choices":[["Lunch near Fushimi Inari Taisha","Choose a nearby restaurant for lunch.","https://www.google.com/maps/search/?api=1&query=%E3%83%AC%E3%82%B9%E3%83%88%E3%83%A9%E3%83%B3%20Fushimi%20Inari%20Taisha%20Fushimi%20Inari"]]},{"type":"sight","duration":75,"choices":[["Tofukuji Temple Kyoto","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E6%9D%B1%E7%A6%8F%E5%AF%BA%20%E4%BA%AC%E9%83%BD%E5%BA%9C"]]},{"type":"break","duration":55,"choices":[["Sanjusangendo Temple Kyoto","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E4%B8%89%E5%8D%81%E4%B8%89%E9%96%93%E5%A0%82%20%E4%BA%AC%E9%83%BD%E5%BA%9C"]]}]},{"id":"osaka-castle","prefecture":"osaka","label":"Osaka · Castle and River","title":"Osaka · Castle and River","description":"Four selected places in one area; follow the directions for each transfer.","area":"Osaka Castle","gap":25,"stops":[{"type":"sight","duration":65,"choices":[["Osaka Castle Park","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%A4%A7%E9%98%AA%E5%9F%8E%E5%85%AC%E5%9C%92%20%E5%A4%A7%E9%98%AA%E5%BA%9C"]]},{"type":"walk","duration":55,"choices":[["Osaka Castle","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%A4%A7%E9%98%AA%E5%9F%8E%20%E5%A4%A7%E9%98%AA%E5%BA%9C"]]},{"type":"food","duration":60,"choices":[["Lunch near Osaka Castle","Choose a nearby restaurant for lunch.","https://www.google.com/maps/search/?api=1&query=%E3%83%AC%E3%82%B9%E3%83%88%E3%83%A9%E3%83%B3%20Osaka%20Castle%20Osaka%20Castle"]]},{"type":"sight","duration":75,"choices":[["Osaka Museum of History","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%A4%A7%E9%98%AA%E6%AD%B4%E5%8F%B2%E5%8D%9A%E7%89%A9%E9%A4%A8%20%E5%A4%A7%E9%98%AA%E5%BA%9C"]]},{"type":"break","duration":55,"choices":[["Nakanoshima Park Osaka","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E4%B8%AD%E4%B9%8B%E5%B3%B6%E5%85%AC%E5%9C%92%20%E5%A4%A7%E9%98%AA%E5%BA%9C"]]}]},{"id":"shinsekai","prefecture":"osaka","label":"Osaka · Shinsekai","title":"Osaka · Shinsekai","description":"Four selected places in one area; follow the directions for each transfer.","area":"Tennoji and Shinsekai","gap":25,"stops":[{"type":"sight","duration":65,"choices":[["Tennoji Station","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%A4%A9%E7%8E%8B%E5%AF%BA%E9%A7%85%20%E5%A4%A7%E9%98%AA%E5%BA%9C"]]},{"type":"walk","duration":55,"choices":[["Shitennoji Temple Osaka","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%9B%9B%E5%A4%A9%E7%8E%8B%E5%AF%BA%20%E5%A4%A7%E9%98%AA%E5%BA%9C"]]},{"type":"food","duration":60,"choices":[["Lunch near Shitennoji Temple Osaka","Choose a nearby restaurant for lunch.","https://www.google.com/maps/search/?api=1&query=%E3%83%AC%E3%82%B9%E3%83%88%E3%83%A9%E3%83%B3%20Shitennoji%20Temple%20Osaka%20Tennoji%20and%20Shinsekai"]]},{"type":"sight","duration":75,"choices":[["Tennoji Park Osaka","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%A4%A9%E7%8E%8B%E5%AF%BA%E5%85%AC%E5%9C%92%20%E5%A4%A7%E9%98%AA%E5%BA%9C"]]},{"type":"break","duration":55,"choices":[["Tsutenkaku Tower Osaka","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E9%80%9A%E5%A4%A9%E9%96%A3%20%E5%A4%A7%E9%98%AA%E5%BA%9C"]]}]},{"id":"kobe","prefecture":"hyogo","label":"Kobe · Waterfront","title":"Kobe · Waterfront","description":"Four selected places in one area; follow the directions for each transfer.","area":"Kobe Waterfront","gap":25,"stops":[{"type":"sight","duration":65,"choices":[["Kobe Harborland","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E7%A5%9E%E6%88%B8%E3%83%8F%E3%83%BC%E3%83%90%E3%83%BC%E3%83%A9%E3%83%B3%E3%83%89%20%E5%85%B5%E5%BA%AB%E7%9C%8C"]]},{"type":"walk","duration":55,"choices":[["Meriken Park Kobe","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E3%83%A1%E3%83%AA%E3%82%B1%E3%83%B3%E3%83%91%E3%83%BC%E3%82%AF%20%E5%85%B5%E5%BA%AB%E7%9C%8C"]]},{"type":"food","duration":60,"choices":[["Lunch near Meriken Park Kobe","Choose a nearby restaurant for lunch.","https://www.google.com/maps/search/?api=1&query=%E3%83%AC%E3%82%B9%E3%83%88%E3%83%A9%E3%83%B3%20Meriken%20Park%20Kobe%20Kobe%20Waterfront"]]},{"type":"sight","duration":75,"choices":[["Kobe Port Tower","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E7%A5%9E%E6%88%B8%E3%83%9D%E3%83%BC%E3%83%88%E3%82%BF%E3%83%AF%E3%83%BC%20%E5%85%B5%E5%BA%AB%E7%9C%8C"]]},{"type":"break","duration":55,"choices":[["Nankinmachi Kobe","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%8D%97%E4%BA%AC%E7%94%BA%20%E5%85%B5%E5%BA%AB%E7%9C%8C"]]}]},{"id":"ikaruga","prefecture":"nara","label":"Nara · Ikaruga Temples","title":"Nara · Ikaruga Temples","description":"Four selected places in one area; follow the directions for each transfer.","area":"Ikaruga","gap":25,"stops":[{"type":"sight","duration":65,"choices":[["Horyuji Station","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E6%B3%95%E9%9A%86%E5%AF%BA%E9%A7%85%20%E5%A5%88%E8%89%AF%E7%9C%8C"]]},{"type":"walk","duration":55,"choices":[["Horyuji Temple","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E6%B3%95%E9%9A%86%E5%AF%BA%20%E5%A5%88%E8%89%AF%E7%9C%8C"]]},{"type":"food","duration":60,"choices":[["Lunch near Horyuji Temple","Choose a nearby restaurant for lunch.","https://www.google.com/maps/search/?api=1&query=%E3%83%AC%E3%82%B9%E3%83%88%E3%83%A9%E3%83%B3%20Horyuji%20Temple%20Ikaruga"]]},{"type":"sight","duration":75,"choices":[["Chuguji Temple Nara","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E4%B8%AD%E5%AE%AE%E5%AF%BA%20%E5%A5%88%E8%89%AF%E7%9C%8C"]]},{"type":"break","duration":55,"choices":[["Hokiji Temple Nara","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E6%B3%95%E8%B5%B7%E5%AF%BA%20%E5%A5%88%E8%89%AF%E7%9C%8C"]]}]},{"id":"wakayama-city","prefecture":"wakayama","label":"Wakayama · Castle Town","title":"Wakayama · Castle Town","description":"Four selected places in one area; follow the directions for each transfer.","area":"Wakayama Castle","gap":25,"stops":[{"type":"sight","duration":65,"choices":[["Wakayamashi Station","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%92%8C%E6%AD%8C%E5%B1%B1%E5%B8%82%E9%A7%85%20%E5%92%8C%E6%AD%8C%E5%B1%B1%E7%9C%8C"]]},{"type":"walk","duration":55,"choices":[["Wakayama Castle","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%92%8C%E6%AD%8C%E5%B1%B1%E5%9F%8E%20%E5%92%8C%E6%AD%8C%E5%B1%B1%E7%9C%8C"]]},{"type":"food","duration":60,"choices":[["Lunch near Wakayama Castle","Choose a nearby restaurant for lunch.","https://www.google.com/maps/search/?api=1&query=%E3%83%AC%E3%82%B9%E3%83%88%E3%83%A9%E3%83%B3%20Wakayama%20Castle%20Wakayama%20Castle"]]},{"type":"sight","duration":75,"choices":[["Momijidani Garden Wakayama","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E7%B4%85%E8%91%89%E6%B8%93%E5%BA%AD%E5%9C%92%20%E5%92%8C%E6%AD%8C%E5%B1%B1%E7%9C%8C"]]},{"type":"break","duration":55,"choices":[["Wakayama Museum of Modern Art","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%92%8C%E6%AD%8C%E5%B1%B1%E7%9C%8C%E7%AB%8B%E8%BF%91%E4%BB%A3%E7%BE%8E%E8%A1%93%E9%A4%A8%20%E5%92%8C%E6%AD%8C%E5%B1%B1%E7%9C%8C"]]}]},{"id":"tottori-dunes","prefecture":"tottori","label":"Tottori · Sand Dunes","title":"Tottori · Sand Dunes","description":"Four selected places in one area; follow the directions for each transfer.","area":"Tottori Sand Dunes","gap":25,"stops":[{"type":"sight","duration":65,"choices":[["Tottori Sand Dunes Visitor Center","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E9%B3%A5%E5%8F%96%E7%A0%82%E4%B8%98%E3%83%93%E3%82%B8%E3%82%BF%E3%83%BC%E3%82%BB%E3%83%B3%E3%82%BF%E3%83%BC%20%E9%B3%A5%E5%8F%96%E7%9C%8C"]]},{"type":"walk","duration":55,"choices":[["Tottori Sand Dunes","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E9%B3%A5%E5%8F%96%E7%A0%82%E4%B8%98%20%E9%B3%A5%E5%8F%96%E7%9C%8C"]]},{"type":"food","duration":60,"choices":[["Lunch near Tottori Sand Dunes","Choose a nearby restaurant for lunch.","https://www.google.com/maps/search/?api=1&query=%E3%83%AC%E3%82%B9%E3%83%88%E3%83%A9%E3%83%B3%20Tottori%20Sand%20Dunes%20Tottori%20Sand%20Dunes"]]},{"type":"sight","duration":75,"choices":[["The Sand Museum Tottori","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E7%A0%82%E3%81%AE%E7%BE%8E%E8%A1%93%E9%A4%A8%20%E9%B3%A5%E5%8F%96%E7%9C%8C"]]},{"type":"break","duration":55,"choices":[["Sakyu Center View Hill Tottori","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E7%A0%82%E4%B8%98%E3%82%BB%E3%83%B3%E3%82%BF%E3%83%BC%E8%A6%8B%E6%99%B4%E3%82%89%E3%81%97%E3%81%AE%E4%B8%98%20%E9%B3%A5%E5%8F%96%E7%9C%8C"]]}]},{"id":"matsue","prefecture":"shimane","label":"Matsue · Castle and Lake","title":"Matsue · Castle and Lake","description":"Four selected places in one area; follow the directions for each transfer.","area":"Central Matsue","gap":25,"stops":[{"type":"sight","duration":65,"choices":[["Matsue Castle","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E6%9D%BE%E6%B1%9F%E5%9F%8E%20%E5%B3%B6%E6%A0%B9%E7%9C%8C"]]},{"type":"walk","duration":55,"choices":[["Shiomi Nawate Street Matsue","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%A1%A9%E8%A6%8B%E7%B8%84%E6%89%8B%20%E5%B3%B6%E6%A0%B9%E7%9C%8C"]]},{"type":"food","duration":60,"choices":[["Lunch near Shiomi Nawate Street Matsue","Choose a nearby restaurant for lunch.","https://www.google.com/maps/search/?api=1&query=%E3%83%AC%E3%82%B9%E3%83%88%E3%83%A9%E3%83%B3%20Shiomi%20Nawate%20Street%20Matsue%20Central%20Matsue"]]},{"type":"sight","duration":75,"choices":[["Lafcadio Hearn Memorial Museum Matsue","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%B0%8F%E6%B3%89%E5%85%AB%E9%9B%B2%E8%A8%98%E5%BF%B5%E9%A4%A8%20%E5%B3%B6%E6%A0%B9%E7%9C%8C"]]},{"type":"break","duration":55,"choices":[["Shimane Art Museum","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%B3%B6%E6%A0%B9%E7%9C%8C%E7%AB%8B%E7%BE%8E%E8%A1%93%E9%A4%A8%20%E5%B3%B6%E6%A0%B9%E7%9C%8C"]]}]},{"id":"okayama-city","prefecture":"okayama","label":"Okayama · Korakuen","title":"Okayama · Korakuen","description":"Four selected places in one area; follow the directions for each transfer.","area":"Central Okayama","gap":25,"stops":[{"type":"sight","duration":65,"choices":[["Okayama Station","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%B2%A1%E5%B1%B1%E9%A7%85%20%E5%B2%A1%E5%B1%B1%E7%9C%8C"]]},{"type":"walk","duration":55,"choices":[["Okayama Castle","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%B2%A1%E5%B1%B1%E5%9F%8E%20%E5%B2%A1%E5%B1%B1%E7%9C%8C"]]},{"type":"food","duration":60,"choices":[["Lunch near Okayama Castle","Choose a nearby restaurant for lunch.","https://www.google.com/maps/search/?api=1&query=%E3%83%AC%E3%82%B9%E3%83%88%E3%83%A9%E3%83%B3%20Okayama%20Castle%20Central%20Okayama"]]},{"type":"sight","duration":75,"choices":[["Okayama Korakuen Garden","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%B2%A1%E5%B1%B1%E5%BE%8C%E6%A5%BD%E5%9C%92%20%E5%B2%A1%E5%B1%B1%E7%9C%8C"]]},{"type":"break","duration":55,"choices":[["Okayama Prefectural Museum of Art","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%B2%A1%E5%B1%B1%E7%9C%8C%E7%AB%8B%E7%BE%8E%E8%A1%93%E9%A4%A8%20%E5%B2%A1%E5%B1%B1%E7%9C%8C"]]}]},{"id":"yamaguchi-city","prefecture":"yamaguchi","label":"Yamaguchi · Culture and Onsen","title":"Yamaguchi · Culture and Onsen","description":"Four selected places in one area; follow the directions for each transfer.","area":"Central Yamaguchi","gap":25,"stops":[{"type":"sight","duration":65,"choices":[["Yamaguchi Station","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%B1%B1%E5%8F%A3%E9%A7%85%20%E5%B1%B1%E5%8F%A3%E7%9C%8C"]]},{"type":"walk","duration":55,"choices":[["Yamaguchi Xavier Memorial Church","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%B1%B1%E5%8F%A3%E3%82%B5%E3%83%93%E3%82%A8%E3%83%AB%E8%A8%98%E5%BF%B5%E8%81%96%E5%A0%82%20%E5%B1%B1%E5%8F%A3%E7%9C%8C"]]},{"type":"food","duration":60,"choices":[["Lunch near Yamaguchi Xavier Memorial Church","Choose a nearby restaurant for lunch.","https://www.google.com/maps/search/?api=1&query=%E3%83%AC%E3%82%B9%E3%83%88%E3%83%A9%E3%83%B3%20Yamaguchi%20Xavier%20Memorial%20Church%20Central%20Yamaguchi"]]},{"type":"sight","duration":75,"choices":[["Yamaguchi Prefectural Museum of Art","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%B1%B1%E5%8F%A3%E7%9C%8C%E7%AB%8B%E7%BE%8E%E8%A1%93%E9%A4%A8%20%E5%B1%B1%E5%8F%A3%E7%9C%8C"]]},{"type":"break","duration":55,"choices":[["Yuda Onsen Yamaguchi","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E6%B9%AF%E7%94%B0%E6%B8%A9%E6%B3%89%20%E5%B1%B1%E5%8F%A3%E7%9C%8C"]]}]},{"id":"tokushima-city","prefecture":"tokushima","label":"Tokushima · Awa Odori","title":"Tokushima · Awa Odori","description":"Four selected places in one area; follow the directions for each transfer.","area":"Central Tokushima","gap":25,"stops":[{"type":"sight","duration":65,"choices":[["Tokushima Station","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%BE%B3%E5%B3%B6%E9%A7%85%20%E5%BE%B3%E5%B3%B6%E7%9C%8C"]]},{"type":"walk","duration":55,"choices":[["Awa Odori Kaikan","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E9%98%BF%E6%B3%A2%E3%81%8A%E3%81%A9%E3%82%8A%E4%BC%9A%E9%A4%A8%20%E5%BE%B3%E5%B3%B6%E7%9C%8C"]]},{"type":"food","duration":60,"choices":[["Lunch near Awa Odori Kaikan","Choose a nearby restaurant for lunch.","https://www.google.com/maps/search/?api=1&query=%E3%83%AC%E3%82%B9%E3%83%88%E3%83%A9%E3%83%B3%20Awa%20Odori%20Kaikan%20Central%20Tokushima"]]},{"type":"sight","duration":75,"choices":[["Bizan Ropeway","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E7%9C%89%E5%B1%B1%E3%83%AD%E3%83%BC%E3%83%97%E3%82%A6%E3%82%A7%E3%82%A4%20%E5%BE%B3%E5%B3%B6%E7%9C%8C"]]},{"type":"break","duration":55,"choices":[["Shinmachigawa Waterfront Park Tokushima","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E6%96%B0%E7%94%BA%E5%B7%9D%E6%B0%B4%E9%9A%9B%E5%85%AC%E5%9C%92%20%E5%BE%B3%E5%B3%B6%E7%9C%8C"]]}]},{"id":"takamatsu","prefecture":"kagawa","label":"Takamatsu · Garden and Port","title":"Takamatsu · Garden and Port","description":"Four selected places in one area; follow the directions for each transfer.","area":"Central Takamatsu","gap":25,"stops":[{"type":"sight","duration":65,"choices":[["Ritsurin Garden Takamatsu","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E6%A0%97%E6%9E%97%E5%85%AC%E5%9C%92%20%E9%A6%99%E5%B7%9D%E7%9C%8C"]]},{"type":"walk","duration":55,"choices":[["Takamatsu Marugamemachi Shopping Street","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E9%AB%98%E6%9D%BE%E4%B8%B8%E4%BA%80%E7%94%BA%E5%95%86%E5%BA%97%E8%A1%97%20%E9%A6%99%E5%B7%9D%E7%9C%8C"]]},{"type":"food","duration":60,"choices":[["Lunch near Takamatsu Marugamemachi Shopping Street","Choose a nearby restaurant for lunch.","https://www.google.com/maps/search/?api=1&query=%E3%83%AC%E3%82%B9%E3%83%88%E3%83%A9%E3%83%B3%20Takamatsu%20Marugamemachi%20Shopping%20Street%20Central%20Takamatsu"]]},{"type":"sight","duration":75,"choices":[["Tamamo Park Takamatsu","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E7%8E%89%E8%97%BB%E5%85%AC%E5%9C%92%20%E9%A6%99%E5%B7%9D%E7%9C%8C"]]},{"type":"break","duration":55,"choices":[["Sunport Takamatsu","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E3%82%B5%E3%83%B3%E3%83%9D%E3%83%BC%E3%83%88%E9%AB%98%E6%9D%BE%20%E9%A6%99%E5%B7%9D%E7%9C%8C"]]}]},{"id":"matsuyama","prefecture":"ehime","label":"Matsuyama · Castle and Dogo","title":"Matsuyama · Castle and Dogo","description":"Four selected places in one area; follow the directions for each transfer.","area":"Central Matsuyama","gap":25,"stops":[{"type":"sight","duration":65,"choices":[["Matsuyama Castle","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E6%9D%BE%E5%B1%B1%E5%9F%8E%20%E6%84%9B%E5%AA%9B%E7%9C%8C"]]},{"type":"walk","duration":55,"choices":[["Ropeway Street Matsuyama","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E3%83%AD%E3%83%BC%E3%83%97%E3%82%A6%E3%82%A7%E3%83%BC%E8%A1%97%20%E6%84%9B%E5%AA%9B%E7%9C%8C"]]},{"type":"food","duration":60,"choices":[["Lunch near Ropeway Street Matsuyama","Choose a nearby restaurant for lunch.","https://www.google.com/maps/search/?api=1&query=%E3%83%AC%E3%82%B9%E3%83%88%E3%83%A9%E3%83%B3%20Ropeway%20Street%20Matsuyama%20Central%20Matsuyama"]]},{"type":"sight","duration":75,"choices":[["Dogo Onsen Honkan","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E9%81%93%E5%BE%8C%E6%B8%A9%E6%B3%89%E6%9C%AC%E9%A4%A8%20%E6%84%9B%E5%AA%9B%E7%9C%8C"]]},{"type":"break","duration":55,"choices":[["Botchan Karakuri Clock","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%9D%8A%E3%81%A3%E3%81%A1%E3%82%83%E3%82%93%E3%82%AB%E3%83%A9%E3%82%AF%E3%83%AA%E6%99%82%E8%A8%88%20%E6%84%9B%E5%AA%9B%E7%9C%8C"]]}]},{"id":"kochi-city","prefecture":"kochi","label":"Kochi · Castle and Market","title":"Kochi · Castle and Market","description":"Four selected places in one area; follow the directions for each transfer.","area":"Central Kochi","gap":25,"stops":[{"type":"sight","duration":65,"choices":[["Kochi Station","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E9%AB%98%E7%9F%A5%E9%A7%85%20%E9%AB%98%E7%9F%A5%E7%9C%8C"]]},{"type":"walk","duration":55,"choices":[["Kochi Castle","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E9%AB%98%E7%9F%A5%E5%9F%8E%20%E9%AB%98%E7%9F%A5%E7%9C%8C"]]},{"type":"food","duration":60,"choices":[["Lunch near Kochi Castle","Choose a nearby restaurant for lunch.","https://www.google.com/maps/search/?api=1&query=%E3%83%AC%E3%82%B9%E3%83%88%E3%83%A9%E3%83%B3%20Kochi%20Castle%20Central%20Kochi"]]},{"type":"sight","duration":75,"choices":[["Hirome Market Kochi","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E3%81%B2%E3%82%8D%E3%82%81%E5%B8%82%E5%A0%B4%20%E9%AB%98%E7%9F%A5%E7%9C%8C"]]},{"type":"break","duration":55,"choices":[["Harimaya Bridge Kochi","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E3%81%AF%E3%82%8A%E3%81%BE%E3%82%84%E6%A9%8B%20%E9%AB%98%E7%9F%A5%E7%9C%8C"]]}]},{"id":"fukuoka-city","prefecture":"fukuoka","label":"Fukuoka · Ohori and Tenjin","title":"Fukuoka · Ohori and Tenjin","description":"Four selected places in one area; follow the directions for each transfer.","area":"Central Fukuoka","gap":25,"stops":[{"type":"sight","duration":65,"choices":[["Ohori Park Fukuoka","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%A4%A7%E6%BF%A0%E5%85%AC%E5%9C%92%20%E7%A6%8F%E5%B2%A1%E7%9C%8C"]]},{"type":"walk","duration":55,"choices":[["Fukuoka Art Museum","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E7%A6%8F%E5%B2%A1%E5%B8%82%E7%BE%8E%E8%A1%93%E9%A4%A8%20%E7%A6%8F%E5%B2%A1%E7%9C%8C"]]},{"type":"food","duration":60,"choices":[["Lunch near Fukuoka Art Museum","Choose a nearby restaurant for lunch.","https://www.google.com/maps/search/?api=1&query=%E3%83%AC%E3%82%B9%E3%83%88%E3%83%A9%E3%83%B3%20Fukuoka%20Art%20Museum%20Central%20Fukuoka"]]},{"type":"sight","duration":75,"choices":[["Fukuoka Castle Ruins","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E7%A6%8F%E5%B2%A1%E5%9F%8E%E8%B7%A1%20%E7%A6%8F%E5%B2%A1%E7%9C%8C"]]},{"type":"break","duration":55,"choices":[["Tenjin Fukuoka","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%A4%A9%E7%A5%9E%20%E7%A6%8F%E5%B2%A1%E7%9C%8C"]]}]},{"id":"dazaifu","prefecture":"fukuoka","label":"Fukuoka · Dazaifu","title":"Fukuoka · Dazaifu","description":"Four selected places in one area; follow the directions for each transfer.","area":"Dazaifu","gap":25,"stops":[{"type":"sight","duration":65,"choices":[["Dazaifu Station","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%A4%AA%E5%AE%B0%E5%BA%9C%E9%A7%85%20%E7%A6%8F%E5%B2%A1%E7%9C%8C"]]},{"type":"walk","duration":55,"choices":[["Dazaifu Tenmangu Approach","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%A4%AA%E5%AE%B0%E5%BA%9C%E5%A4%A9%E6%BA%80%E5%AE%AE%E5%8F%82%E9%81%93%20%E7%A6%8F%E5%B2%A1%E7%9C%8C"]]},{"type":"food","duration":60,"choices":[["Lunch near Dazaifu Tenmangu Approach","Choose a nearby restaurant for lunch.","https://www.google.com/maps/search/?api=1&query=%E3%83%AC%E3%82%B9%E3%83%88%E3%83%A9%E3%83%B3%20Dazaifu%20Tenmangu%20Approach%20Dazaifu"]]},{"type":"sight","duration":75,"choices":[["Dazaifu Tenmangu Shrine","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%A4%AA%E5%AE%B0%E5%BA%9C%E5%A4%A9%E6%BA%80%E5%AE%AE%20%E7%A6%8F%E5%B2%A1%E7%9C%8C"]]},{"type":"break","duration":55,"choices":[["Kyushu National Museum","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E4%B9%9D%E5%B7%9E%E5%9B%BD%E7%AB%8B%E5%8D%9A%E7%89%A9%E9%A4%A8%20%E7%A6%8F%E5%B2%A1%E7%9C%8C"]]}]},{"id":"saga-city","prefecture":"saga","label":"Saga · Castle Town","title":"Saga · Castle Town","description":"Four selected places in one area; follow the directions for each transfer.","area":"Central Saga","gap":25,"stops":[{"type":"sight","duration":65,"choices":[["Saga Station","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E4%BD%90%E8%B3%80%E9%A7%85%20%E4%BD%90%E8%B3%80%E7%9C%8C"]]},{"type":"walk","duration":55,"choices":[["Saga Castle History Museum","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E4%BD%90%E8%B3%80%E5%9F%8E%E6%9C%AC%E4%B8%B8%E6%AD%B4%E5%8F%B2%E9%A4%A8%20%E4%BD%90%E8%B3%80%E7%9C%8C"]]},{"type":"food","duration":60,"choices":[["Lunch near Saga Castle History Museum","Choose a nearby restaurant for lunch.","https://www.google.com/maps/search/?api=1&query=%E3%83%AC%E3%82%B9%E3%83%88%E3%83%A9%E3%83%B3%20Saga%20Castle%20History%20Museum%20Central%20Saga"]]},{"type":"sight","duration":75,"choices":[["Saga Prefectural Museum","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E4%BD%90%E8%B3%80%E7%9C%8C%E7%AB%8B%E5%8D%9A%E7%89%A9%E9%A4%A8%20%E4%BD%90%E8%B3%80%E7%9C%8C"]]},{"type":"break","duration":55,"choices":[["Chokokan Saga","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%BE%B4%E5%8F%A4%E9%A4%A8%20%E4%BD%90%E8%B3%80%E7%9C%8C"]]}]},{"id":"nagasaki-city","prefecture":"nagasaki","label":"Nagasaki · Peace Memorials","title":"Nagasaki · Peace Memorials","description":"Four selected places in one area; follow the directions for each transfer.","area":"Urakami Nagasaki","gap":25,"stops":[{"type":"sight","duration":65,"choices":[["Peace Park Nagasaki","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%B9%B3%E5%92%8C%E5%85%AC%E5%9C%92%20%E9%95%B7%E5%B4%8E%E7%9C%8C"]]},{"type":"walk","duration":55,"choices":[["Nagasaki Atomic Bomb Museum","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E9%95%B7%E5%B4%8E%E5%8E%9F%E7%88%86%E8%B3%87%E6%96%99%E9%A4%A8%20%E9%95%B7%E5%B4%8E%E7%9C%8C"]]},{"type":"food","duration":60,"choices":[["Lunch near Nagasaki Atomic Bomb Museum","Choose a nearby restaurant for lunch.","https://www.google.com/maps/search/?api=1&query=%E3%83%AC%E3%82%B9%E3%83%88%E3%83%A9%E3%83%B3%20Nagasaki%20Atomic%20Bomb%20Museum%20Urakami%20Nagasaki"]]},{"type":"sight","duration":75,"choices":[["Atomic Bomb Hypocenter Park Nagasaki","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%8E%9F%E7%88%86%E8%90%BD%E4%B8%8B%E4%B8%AD%E5%BF%83%E5%9C%B0%E5%85%AC%E5%9C%92%20%E9%95%B7%E5%B4%8E%E7%9C%8C"]]},{"type":"break","duration":55,"choices":[["Urakami Cathedral Nagasaki","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E6%B5%A6%E4%B8%8A%E5%A4%A9%E4%B8%BB%E5%A0%82%20%E9%95%B7%E5%B4%8E%E7%9C%8C"]]}]},{"id":"kumamoto-city","prefecture":"kumamoto","label":"Kumamoto · Castle and Garden","title":"Kumamoto · Castle and Garden","description":"Four selected places in one area; follow the directions for each transfer.","area":"Central Kumamoto","gap":25,"stops":[{"type":"sight","duration":65,"choices":[["Kumamoto Castle","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E7%86%8A%E6%9C%AC%E5%9F%8E%20%E7%86%8A%E6%9C%AC%E7%9C%8C"]]},{"type":"walk","duration":55,"choices":[["Sakura no Baba Josaien","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E6%A1%9C%E3%81%AE%E9%A6%AC%E5%A0%B4%20%E5%9F%8E%E5%BD%A9%E8%8B%91%20%E7%86%8A%E6%9C%AC%E7%9C%8C"]]},{"type":"food","duration":60,"choices":[["Lunch near Sakura no Baba Josaien","Choose a nearby restaurant for lunch.","https://www.google.com/maps/search/?api=1&query=%E3%83%AC%E3%82%B9%E3%83%88%E3%83%A9%E3%83%B3%20Sakura%20no%20Baba%20Josaien%20Central%20Kumamoto"]]},{"type":"sight","duration":75,"choices":[["Shimotori Arcade Kumamoto","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E4%B8%8B%E9%80%9A%E3%82%A2%E3%83%BC%E3%82%B1%E3%83%BC%E3%83%89%20%E7%86%8A%E6%9C%AC%E7%9C%8C"]]},{"type":"break","duration":55,"choices":[["Suizenji Jojuen Garden","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E6%B0%B4%E5%89%8D%E5%AF%BA%E6%88%90%E8%B6%A3%E5%9C%92%20%E7%86%8A%E6%9C%AC%E7%9C%8C"]]}]},{"id":"beppu","prefecture":"oita","label":"Beppu · Onsen Town","title":"Beppu · Onsen Town","description":"Four selected places in one area; follow the directions for each transfer.","area":"Central Beppu","gap":25,"stops":[{"type":"sight","duration":65,"choices":[["Beppu Station","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%88%A5%E5%BA%9C%E9%A7%85%20%E5%A4%A7%E5%88%86%E7%9C%8C"]]},{"type":"walk","duration":55,"choices":[["Takegawara Onsen Beppu","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E7%AB%B9%E7%93%A6%E6%B8%A9%E6%B3%89%20%E5%A4%A7%E5%88%86%E7%9C%8C"]]},{"type":"food","duration":60,"choices":[["Lunch near Takegawara Onsen Beppu","Choose a nearby restaurant for lunch.","https://www.google.com/maps/search/?api=1&query=%E3%83%AC%E3%82%B9%E3%83%88%E3%83%A9%E3%83%B3%20Takegawara%20Onsen%20Beppu%20Central%20Beppu"]]},{"type":"sight","duration":75,"choices":[["Beppu Tower","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%88%A5%E5%BA%9C%E3%82%BF%E3%83%AF%E3%83%BC%20%E5%A4%A7%E5%88%86%E7%9C%8C"]]},{"type":"break","duration":55,"choices":[["Beppu Park","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%88%A5%E5%BA%9C%E5%85%AC%E5%9C%92%20%E5%A4%A7%E5%88%86%E7%9C%8C"]]}]},{"id":"aoshima","prefecture":"miyazaki","label":"Miyazaki · Aoshima","title":"Miyazaki · Aoshima","description":"Four selected places in one area; follow the directions for each transfer.","area":"Aoshima Miyazaki","gap":25,"stops":[{"type":"sight","duration":65,"choices":[["Aoshima Station Miyazaki","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E9%9D%92%E5%B3%B6%E9%A7%85%20%E5%AE%AE%E5%B4%8E%E7%9C%8C"]]},{"type":"walk","duration":55,"choices":[["Aoshima Beach Miyazaki","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E9%9D%92%E5%B3%B6%E3%83%93%E3%83%BC%E3%83%81%20%E5%AE%AE%E5%B4%8E%E7%9C%8C"]]},{"type":"food","duration":60,"choices":[["Lunch near Aoshima Beach Miyazaki","Choose a nearby restaurant for lunch.","https://www.google.com/maps/search/?api=1&query=%E3%83%AC%E3%82%B9%E3%83%88%E3%83%A9%E3%83%B3%20Aoshima%20Beach%20Miyazaki%20Aoshima%20Miyazaki"]]},{"type":"sight","duration":75,"choices":[["Aoshima Shrine","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E9%9D%92%E5%B3%B6%E7%A5%9E%E7%A4%BE%20%E5%AE%AE%E5%B4%8E%E7%9C%8C"]]},{"type":"break","duration":55,"choices":[["Aoshima Botanical Garden","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%AE%AE%E4%BA%A4%E3%83%9C%E3%82%BF%E3%83%8B%E3%83%83%E3%82%AF%E3%82%AC%E3%83%BC%E3%83%87%E3%83%B3%E9%9D%92%E5%B3%B6%20%E5%AE%AE%E5%B4%8E%E7%9C%8C"]]}]},{"id":"kagoshima-city","prefecture":"kagoshima","label":"Kagoshima · City and Bay","title":"Kagoshima · City and Bay","description":"Four selected places in one area; follow the directions for each transfer.","area":"Central Kagoshima","gap":25,"stops":[{"type":"sight","duration":65,"choices":[["Kagoshima Chuo Station","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E9%B9%BF%E5%85%90%E5%B3%B6%E4%B8%AD%E5%A4%AE%E9%A7%85%20%E9%B9%BF%E5%85%90%E5%B3%B6%E7%9C%8C"]]},{"type":"walk","duration":55,"choices":[["Tenmonkan Kagoshima","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%A4%A9%E6%96%87%E9%A4%A8%20%E9%B9%BF%E5%85%90%E5%B3%B6%E7%9C%8C"]]},{"type":"food","duration":60,"choices":[["Lunch near Tenmonkan Kagoshima","Choose a nearby restaurant for lunch.","https://www.google.com/maps/search/?api=1&query=%E3%83%AC%E3%82%B9%E3%83%88%E3%83%A9%E3%83%B3%20Tenmonkan%20Kagoshima%20Central%20Kagoshima"]]},{"type":"sight","duration":75,"choices":[["Shiroyama Observatory Kagoshima","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%9F%8E%E5%B1%B1%E5%B1%95%E6%9C%9B%E5%8F%B0%20%E9%B9%BF%E5%85%90%E5%B3%B6%E7%9C%8C"]]},{"type":"break","duration":55,"choices":[["Kagoshima City Aquarium","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E3%81%8B%E3%81%94%E3%81%97%E3%81%BE%E6%B0%B4%E6%97%8F%E9%A4%A8%20%E9%B9%BF%E5%85%90%E5%B3%B6%E7%9C%8C"]]}]},{"id":"naha","prefecture":"okinawa","label":"Okinawa · Naha","title":"Okinawa · Naha","description":"Four selected places in one area; follow the directions for each transfer.","area":"Central Naha","gap":25,"stops":[{"type":"sight","duration":65,"choices":[["Kokusai Dori Naha","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%9B%BD%E9%9A%9B%E9%80%9A%E3%82%8A%20%E6%B2%96%E7%B8%84%E7%9C%8C"]]},{"type":"walk","duration":55,"choices":[["Makishi Public Market Naha","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E7%AC%AC%E4%B8%80%E7%89%A7%E5%BF%97%E5%85%AC%E8%A8%AD%E5%B8%82%E5%A0%B4%20%E6%B2%96%E7%B8%84%E7%9C%8C"]]},{"type":"food","duration":60,"choices":[["Lunch near Makishi Public Market Naha","Choose a nearby restaurant for lunch.","https://www.google.com/maps/search/?api=1&query=%E3%83%AC%E3%82%B9%E3%83%88%E3%83%A9%E3%83%B3%20Makishi%20Public%20Market%20Naha%20Central%20Naha"]]},{"type":"sight","duration":75,"choices":[["Tsuboya Pottery Street Naha","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%A3%BA%E5%B1%8B%E3%82%84%E3%81%A1%E3%82%80%E3%82%93%E9%80%9A%E3%82%8A%20%E6%B2%96%E7%B8%84%E7%9C%8C"]]},{"type":"break","duration":55,"choices":[["Fukushuen Garden Naha","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E7%A6%8F%E5%B7%9E%E5%9C%92%20%E6%B2%96%E7%B8%84%E7%9C%8C"]]}]},{"id":"shuri","prefecture":"okinawa","label":"Okinawa · Shuri","title":"Okinawa · Shuri","description":"Four selected places in one area; follow the directions for each transfer.","area":"Shuri Naha","gap":25,"stops":[{"type":"sight","duration":65,"choices":[["Shuri Station Naha","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E9%A6%96%E9%87%8C%E9%A7%85%20%E6%B2%96%E7%B8%84%E7%9C%8C"]]},{"type":"walk","duration":55,"choices":[["Shuri Castle Park","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E9%A6%96%E9%87%8C%E5%9F%8E%E5%85%AC%E5%9C%92%20%E6%B2%96%E7%B8%84%E7%9C%8C"]]},{"type":"food","duration":60,"choices":[["Lunch near Shuri Castle Park","Choose a nearby restaurant for lunch.","https://www.google.com/maps/search/?api=1&query=%E3%83%AC%E3%82%B9%E3%83%88%E3%83%A9%E3%83%B3%20Shuri%20Castle%20Park%20Shuri%20Naha"]]},{"type":"sight","duration":75,"choices":[["Tamaudun Shuri","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E7%8E%89%E9%99%B5%20%E6%B2%96%E7%B8%84%E7%9C%8C"]]},{"type":"break","duration":55,"choices":[["Kinjo Stone Paved Road Shuri","Check local access and opening information before visiting.","https://www.google.com/maps/search/?api=1&query=%E9%87%91%E5%9F%8E%E7%94%BA%E7%9F%B3%E7%95%B3%E9%81%93%20%E6%B2%96%E7%B8%84%E7%9C%8C"]]}]}]
"""#
        guard let value = try? JSONDecoder().decode([DayRoute].self, from: Data(json.utf8)) else {
            preconditionFailure("Invalid nationwide route catalog")
        }
        return value
    }()
    static let prefectures: [PrefectureOption] = {
        let json = #"""
[{"id":"hokkaido","ja":"北海道","en":"Hokkaido","region":"hokkaido"},{"id":"aomori","ja":"青森県","en":"Aomori","region":"tohoku"},{"id":"iwate","ja":"岩手県","en":"Iwate","region":"tohoku"},{"id":"miyagi","ja":"宮城県","en":"Miyagi","region":"tohoku"},{"id":"akita","ja":"秋田県","en":"Akita","region":"tohoku"},{"id":"yamagata","ja":"山形県","en":"Yamagata","region":"tohoku"},{"id":"fukushima","ja":"福島県","en":"Fukushima","region":"tohoku"},{"id":"ibaraki","ja":"茨城県","en":"Ibaraki","region":"kanto"},{"id":"tochigi","ja":"栃木県","en":"Tochigi","region":"kanto"},{"id":"gunma","ja":"群馬県","en":"Gunma","region":"kanto"},{"id":"saitama","ja":"埼玉県","en":"Saitama","region":"kanto"},{"id":"chiba","ja":"千葉県","en":"Chiba","region":"kanto"},{"id":"tokyo","ja":"東京都","en":"Tokyo","region":"kanto"},{"id":"kanagawa","ja":"神奈川県","en":"Kanagawa","region":"kanto"},{"id":"niigata","ja":"新潟県","en":"Niigata","region":"hokuriku"},{"id":"toyama","ja":"富山県","en":"Toyama","region":"hokuriku"},{"id":"ishikawa","ja":"石川県","en":"Ishikawa","region":"hokuriku"},{"id":"fukui","ja":"福井県","en":"Fukui","region":"hokuriku"},{"id":"yamanashi","ja":"山梨県","en":"Yamanashi","region":"hokuriku"},{"id":"nagano","ja":"長野県","en":"Nagano","region":"hokuriku"},{"id":"gifu","ja":"岐阜県","en":"Gifu","region":"tokai"},{"id":"shizuoka","ja":"静岡県","en":"Shizuoka","region":"tokai"},{"id":"aichi","ja":"愛知県","en":"Aichi","region":"tokai"},{"id":"mie","ja":"三重県","en":"Mie","region":"tokai"},{"id":"shiga","ja":"滋賀県","en":"Shiga","region":"kansai"},{"id":"kyoto","ja":"京都府","en":"Kyoto","region":"kansai"},{"id":"osaka","ja":"大阪府","en":"Osaka","region":"kansai"},{"id":"hyogo","ja":"兵庫県","en":"Hyogo","region":"kansai"},{"id":"nara","ja":"奈良県","en":"Nara","region":"kansai"},{"id":"wakayama","ja":"和歌山県","en":"Wakayama","region":"kansai"},{"id":"tottori","ja":"鳥取県","en":"Tottori","region":"chugoku"},{"id":"shimane","ja":"島根県","en":"Shimane","region":"chugoku"},{"id":"okayama","ja":"岡山県","en":"Okayama","region":"chugoku"},{"id":"hiroshima","ja":"広島県","en":"Hiroshima","region":"chugoku"},{"id":"yamaguchi","ja":"山口県","en":"Yamaguchi","region":"chugoku"},{"id":"tokushima","ja":"徳島県","en":"Tokushima","region":"shikoku"},{"id":"kagawa","ja":"香川県","en":"Kagawa","region":"shikoku"},{"id":"ehime","ja":"愛媛県","en":"Ehime","region":"shikoku"},{"id":"kochi","ja":"高知県","en":"Kochi","region":"shikoku"},{"id":"fukuoka","ja":"福岡県","en":"Fukuoka","region":"kyushu"},{"id":"saga","ja":"佐賀県","en":"Saga","region":"kyushu"},{"id":"nagasaki","ja":"長崎県","en":"Nagasaki","region":"kyushu"},{"id":"kumamoto","ja":"熊本県","en":"Kumamoto","region":"kyushu"},{"id":"oita","ja":"大分県","en":"Oita","region":"kyushu"},{"id":"miyazaki","ja":"宮崎県","en":"Miyazaki","region":"kyushu"},{"id":"kagoshima","ja":"鹿児島県","en":"Kagoshima","region":"kyushu"},{"id":"okinawa","ja":"沖縄県","en":"Okinawa","region":"okinawa"}]
"""#
        return (try? JSONDecoder().decode([PrefectureOption].self, from: Data(json.utf8))) ?? []
    }()
    static let regions: [RegionOption] = [
        RegionOption(id: "hokkaido", japanese: "北海道", english: "Hokkaido"),
        RegionOption(id: "tohoku", japanese: "東北", english: "Tohoku"),
        RegionOption(id: "kanto", japanese: "関東", english: "Kanto"),
        RegionOption(id: "hokuriku", japanese: "北陸・甲信越", english: "Hokuriku & Koshinetsu"),
        RegionOption(id: "tokai", japanese: "東海", english: "Tokai"),
        RegionOption(id: "kansai", japanese: "関西", english: "Kansai"),
        RegionOption(id: "chugoku", japanese: "中国", english: "Chugoku"),
        RegionOption(id: "shikoku", japanese: "四国", english: "Shikoku"),
        RegionOption(id: "kyushu", japanese: "九州", english: "Kyushu"),
        RegionOption(id: "okinawa", japanese: "沖縄", english: "Okinawa")
    ]
    static let existingPrefectures: [String: String] = [
        "asakusa": "tokyo",
        "ueno": "tokyo",
        "kyoto": "kyoto",
        "osaka": "osaka",
        "nara": "nara",
        "hiroshima": "hiroshima"
    ]
    static let japaneseLabels: [String: String] = [
        "sapporo": "札幌・大通",
        "hakodate": "函館・港と坂道",
        "aomori-city": "青森・港とねぶた",
        "morioka": "盛岡・城跡と街歩き",
        "sendai": "仙台・青葉山と街",
        "akita-city": "秋田・千秋公園",
        "yamagata-city": "山形・城跡と文翔館",
        "aizu": "会津・鶴ヶ城",
        "mito": "水戸・偕楽園",
        "nikko": "日光・社寺",
        "kusatsu": "草津・温泉街",
        "kawagoe": "川越・小江戸",
        "narita": "成田・参道と公園",
        "shibuya": "渋谷・原宿",
        "yokohama": "横浜・港散策",
        "niigata-city": "新潟・港と信濃川",
        "toyama-city": "富山・水辺とガラス",
        "kanazawa": "金沢・庭園と茶屋街",
        "fukui-city": "福井・城跡と庭園",
        "kofu": "甲府・城跡と神社",
        "nagano-city": "長野・善光寺",
        "takayama": "高山・古い町並",
        "shizuoka-city": "静岡・駿府の街",
        "nagoya-castle": "名古屋・城と栄",
        "nagoya-atsuta": "名古屋・熱田の歴史",
        "ise": "伊勢・神宮と門前町",
        "hikone": "彦根・城下町",
        "arashiyama": "京都・嵐山",
        "fushimi": "京都・伏見と東山",
        "osaka-castle": "大阪・城と中之島",
        "shinsekai": "大阪・新世界と天王寺",
        "kobe": "神戸・港と街",
        "ikaruga": "奈良・斑鳩",
        "wakayama-city": "和歌山・城と街",
        "tottori-dunes": "鳥取・砂丘",
        "matsue": "松江・城と湖",
        "okayama-city": "岡山・後楽園",
        "yamaguchi-city": "山口・文化と湯田",
        "tokushima-city": "徳島・阿波おどり",
        "takamatsu": "高松・庭園と港",
        "matsuyama": "松山・城と道後",
        "kochi-city": "高知・城と市場",
        "fukuoka-city": "福岡・大濠と天神",
        "dazaifu": "福岡・太宰府",
        "saga-city": "佐賀・城下町",
        "nagasaki-city": "長崎・平和を巡る",
        "kumamoto-city": "熊本・城と庭",
        "beppu": "別府・温泉街",
        "aoshima": "宮崎・青島",
        "kagoshima-city": "鹿児島・城山と湾",
        "naha": "沖縄・那覇の街",
        "shuri": "沖縄・首里の歴史"
    ]
    static let japaneseAreas: [String: String] = [
        "sapporo": "札幌中心部",
        "hakodate": "函館元町",
        "aomori-city": "青森駅周辺",
        "morioka": "盛岡中心部",
        "sendai": "仙台中心部",
        "akita-city": "秋田駅周辺",
        "yamagata-city": "山形中心部",
        "aizu": "会津若松",
        "mito": "水戸中心部",
        "nikko": "日光社寺周辺",
        "kusatsu": "草津温泉",
        "kawagoe": "川越中心部",
        "narita": "成田山周辺",
        "shibuya": "原宿・渋谷",
        "yokohama": "みなとみらい",
        "niigata-city": "新潟中心部",
        "toyama-city": "富山中心部",
        "kanazawa": "金沢中心部",
        "fukui-city": "福井中心部",
        "kofu": "甲府中心部",
        "nagano-city": "長野市中心部",
        "takayama": "飛騨高山",
        "shizuoka-city": "静岡中心部",
        "nagoya-castle": "名古屋城周辺",
        "nagoya-atsuta": "熱田神宮周辺",
        "ise": "伊勢",
        "hikone": "彦根城周辺",
        "arashiyama": "嵐山",
        "fushimi": "伏見稲荷",
        "osaka-castle": "大阪城周辺",
        "shinsekai": "天王寺・新世界",
        "kobe": "神戸港周辺",
        "ikaruga": "斑鳩",
        "wakayama-city": "和歌山城周辺",
        "tottori-dunes": "鳥取砂丘",
        "matsue": "松江中心部",
        "okayama-city": "岡山中心部",
        "yamaguchi-city": "山口市中心部",
        "tokushima-city": "徳島中心部",
        "takamatsu": "高松中心部",
        "matsuyama": "松山中心部",
        "kochi-city": "高知中心部",
        "fukuoka-city": "福岡中心部",
        "dazaifu": "太宰府",
        "saga-city": "佐賀中心部",
        "nagasaki-city": "長崎・浦上",
        "kumamoto-city": "熊本中心部",
        "beppu": "別府中心部",
        "aoshima": "青島",
        "kagoshima-city": "鹿児島中心部",
        "naha": "那覇中心部",
        "shuri": "那覇・首里"
    ]
    static let japanesePlaces: [String: String] = [
        "Odori Park": "大通公園",
        "Sapporo TV Tower": "さっぽろテレビ塔",
        "Sapporo Clock Tower": "札幌市時計台",
        "Tanukikoji Shopping Street": "狸小路商店街",
        "Hakodate Morning Market": "函館朝市",
        "Kanemori Red Brick Warehouses": "金森赤レンガ倉庫",
        "Hachimanzaka Slope": "八幡坂",
        "Old Public Hall of Hakodate Ward": "旧函館区公会堂",
        "Aomori Station": "青森駅",
        "Nebuta Museum WA RASSE": "ねぶたの家 ワ・ラッセ",
        "A-FACTORY Aomori": "A-FACTORY",
        "Aomori ASPAM": "青森県観光物産館アスパム",
        "Morioka Castle Ruins Park": "盛岡城跡公園",
        "Morioka History and Culture Museum": "もりおか歴史文化館",
        "Sakurayama Shrine Morioka": "桜山神社",
        "Iwate Bank Red Brick Building": "岩手銀行赤レンガ館",
        "Sendai Station": "仙台駅",
        "Zuihoden Sendai": "瑞鳳殿",
        "Sendai Castle Ruins": "仙台城跡",
        "Jozenji-dori Avenue": "定禅寺通",
        "Akita Station": "秋田駅",
        "Senshu Park": "千秋公園",
        "Akita Museum of Art": "秋田県立美術館",
        "Akita Citizen Market": "秋田市民市場",
        "Yamagata Station": "山形駅",
        "Kajo Park Yamagata": "霞城公園",
        "Yamagata Museum of Art": "山形美術館",
        "Bunshokan Yamagata": "文翔館",
        "Aizuwakamatsu Station": "会津若松駅",
        "Tsuruga Castle Aizu": "鶴ヶ城",
        "Oyakuen Garden Aizu": "御薬園",
        "Nanokamachi Street Aizu": "七日町通り",
        "Mito Station": "水戸駅",
        "Kodokan Mito": "弘道館",
        "Kairakuen Garden": "偕楽園",
        "Lake Senba": "千波湖",
        "Shinkyo Bridge Nikko": "神橋",
        "Rinnoji Temple Nikko": "輪王寺",
        "Nikko Toshogu Shrine": "日光東照宮",
        "Nikko Futarasan Shrine": "日光二荒山神社",
        "Kusatsu Onsen Bus Terminal": "草津温泉バスターミナル",
        "Yubatake Kusatsu": "湯畑",
        "Netsunoyu Kusatsu": "熱乃湯",
        "Sainokawara Park Kusatsu": "西の河原公園",
        "Kawagoe Ichibangai": "川越一番街",
        "Toki no Kane Kawagoe": "時の鐘",
        "Kashiya Yokocho": "菓子屋横丁",
        "Kawagoe Hikawa Shrine": "川越氷川神社",
        "Narita Station": "成田駅",
        "Naritasan Omotesando": "成田山表参道",
        "Naritasan Shinshoji Temple": "成田山新勝寺",
        "Naritasan Park": "成田山公園",
        "Meiji Jingu Shrine": "明治神宮",
        "Takeshita Street": "竹下通り",
        "Omotesando Tokyo": "表参道",
        "Hachiko Square Shibuya": "ハチ公前広場",
        "Yokohama Red Brick Warehouse": "横浜赤レンガ倉庫",
        "Osanbashi Pier Yokohama": "大さん橋",
        "Yamashita Park": "山下公園",
        "Yokohama Chinatown": "横浜中華街",
        "Niigata Station": "新潟駅",
        "Bandai Bridge Niigata": "萬代橋",
        "Pier Bandai": "ピアBandai",
        "Toki Messe Niigata": "朱鷺メッセ",
        "Toyama Station": "富山駅",
        "Kansui Park Toyama": "富岩運河環水公園",
        "Toyama Glass Art Museum": "富山市ガラス美術館",
        "Toyama Castle Park": "富山城址公園",
        "Omicho Market Kanazawa": "近江町市場",
        "Kanazawa Castle Park": "金沢城公園",
        "Kenrokuen Garden": "兼六園",
        "Higashi Chaya District": "ひがし茶屋街",
        "Fukui Station": "福井駅",
        "Fukui Castle Ruins": "福井城址",
        "Fukui City History Museum": "福井市立郷土歴史博物館",
        "Yokokan Garden Fukui": "養浩館庭園",
        "Kofu Station": "甲府駅",
        "Maizuru Castle Park Kofu": "舞鶴城公園",
        "Fujimura Memorial Hall Kofu": "甲府市藤村記念館",
        "Takeda Shrine Kofu": "武田神社",
        "Nagano Station": "長野駅",
        "Zenkoji Approach": "善光寺表参道",
        "Zenkoji Temple Nagano": "善光寺",
        "Nagano Prefectural Art Museum": "長野県立美術館",
        "Takayama Station": "高山駅",
        "Miyagawa Morning Market": "宮川朝市",
        "Takayama Jinya": "高山陣屋",
        "Takayama Old Town": "古い町並",
        "Shizuoka Station": "静岡駅",
        "Sumpu Castle Park": "駿府城公園",
        "Shizuoka City Museum of History": "静岡市歴史博物館",
        "Aoba Symbol Road Shizuoka": "青葉シンボルロード",
        "Nagoya Castle": "名古屋城",
        "Meijo Park": "名城公園",
        "Hisaya Odori Park": "久屋大通公園",
        "Oasis 21 Nagoya": "オアシス21",
        "Atsuta Jingu Shrine": "熱田神宮",
        "Atsuta Jingu Treasure Hall": "熱田神宮宝物館",
        "Shirotori Garden Nagoya": "白鳥庭園",
        "Miya no Watashi Park Nagoya": "宮の渡し公園",
        "Iseshi Station": "伊勢市駅",
        "Ise Jingu Geku": "伊勢神宮 外宮",
        "Sarutahiko Shrine Ise": "猿田彦神社",
        "Okage Yokocho Ise": "おかげ横丁",
        "Hikone Station": "彦根駅",
        "Hikone Castle": "彦根城",
        "Genkyuen Garden Hikone": "玄宮園",
        "Yume Kyobashi Castle Road": "夢京橋キャッスルロード",
        "Togetsukyo Bridge Kyoto": "渡月橋",
        "Tenryuji Temple Kyoto": "天龍寺",
        "Arashiyama Bamboo Grove": "嵯峨野竹林の小径",
        "Nonomiya Shrine Kyoto": "野宮神社",
        "Fushimi Inari Station": "伏見稲荷駅",
        "Fushimi Inari Taisha": "伏見稲荷大社",
        "Tofukuji Temple Kyoto": "東福寺",
        "Sanjusangendo Temple Kyoto": "三十三間堂",
        "Osaka Castle Park": "大阪城公園",
        "Osaka Castle": "大阪城",
        "Osaka Museum of History": "大阪歴史博物館",
        "Nakanoshima Park Osaka": "中之島公園",
        "Tennoji Station": "天王寺駅",
        "Shitennoji Temple Osaka": "四天王寺",
        "Tennoji Park Osaka": "天王寺公園",
        "Tsutenkaku Tower Osaka": "通天閣",
        "Kobe Harborland": "神戸ハーバーランド",
        "Meriken Park Kobe": "メリケンパーク",
        "Kobe Port Tower": "神戸ポートタワー",
        "Nankinmachi Kobe": "南京町",
        "Horyuji Station": "法隆寺駅",
        "Horyuji Temple": "法隆寺",
        "Chuguji Temple Nara": "中宮寺",
        "Hokiji Temple Nara": "法起寺",
        "Wakayamashi Station": "和歌山市駅",
        "Wakayama Castle": "和歌山城",
        "Momijidani Garden Wakayama": "紅葉渓庭園",
        "Wakayama Museum of Modern Art": "和歌山県立近代美術館",
        "Tottori Sand Dunes Visitor Center": "鳥取砂丘ビジターセンター",
        "Tottori Sand Dunes": "鳥取砂丘",
        "The Sand Museum Tottori": "砂の美術館",
        "Sakyu Center View Hill Tottori": "砂丘センター見晴らしの丘",
        "Matsue Castle": "松江城",
        "Shiomi Nawate Street Matsue": "塩見縄手",
        "Lafcadio Hearn Memorial Museum Matsue": "小泉八雲記念館",
        "Shimane Art Museum": "島根県立美術館",
        "Okayama Station": "岡山駅",
        "Okayama Castle": "岡山城",
        "Okayama Korakuen Garden": "岡山後楽園",
        "Okayama Prefectural Museum of Art": "岡山県立美術館",
        "Yamaguchi Station": "山口駅",
        "Yamaguchi Xavier Memorial Church": "山口サビエル記念聖堂",
        "Yamaguchi Prefectural Museum of Art": "山口県立美術館",
        "Yuda Onsen Yamaguchi": "湯田温泉",
        "Tokushima Station": "徳島駅",
        "Awa Odori Kaikan": "阿波おどり会館",
        "Bizan Ropeway": "眉山ロープウェイ",
        "Shinmachigawa Waterfront Park Tokushima": "新町川水際公園",
        "Ritsurin Garden Takamatsu": "栗林公園",
        "Takamatsu Marugamemachi Shopping Street": "高松丸亀町商店街",
        "Tamamo Park Takamatsu": "玉藻公園",
        "Sunport Takamatsu": "サンポート高松",
        "Matsuyama Castle": "松山城",
        "Ropeway Street Matsuyama": "ロープウェー街",
        "Dogo Onsen Honkan": "道後温泉本館",
        "Botchan Karakuri Clock": "坊っちゃんカラクリ時計",
        "Kochi Station": "高知駅",
        "Kochi Castle": "高知城",
        "Hirome Market Kochi": "ひろめ市場",
        "Harimaya Bridge Kochi": "はりまや橋",
        "Ohori Park Fukuoka": "大濠公園",
        "Fukuoka Art Museum": "福岡市美術館",
        "Fukuoka Castle Ruins": "福岡城跡",
        "Tenjin Fukuoka": "天神",
        "Dazaifu Station": "太宰府駅",
        "Dazaifu Tenmangu Approach": "太宰府天満宮参道",
        "Dazaifu Tenmangu Shrine": "太宰府天満宮",
        "Kyushu National Museum": "九州国立博物館",
        "Saga Station": "佐賀駅",
        "Saga Castle History Museum": "佐賀城本丸歴史館",
        "Saga Prefectural Museum": "佐賀県立博物館",
        "Chokokan Saga": "徴古館",
        "Peace Park Nagasaki": "平和公園",
        "Nagasaki Atomic Bomb Museum": "長崎原爆資料館",
        "Atomic Bomb Hypocenter Park Nagasaki": "原爆落下中心地公園",
        "Urakami Cathedral Nagasaki": "浦上天主堂",
        "Kumamoto Castle": "熊本城",
        "Sakura no Baba Josaien": "桜の馬場 城彩苑",
        "Shimotori Arcade Kumamoto": "下通アーケード",
        "Suizenji Jojuen Garden": "水前寺成趣園",
        "Beppu Station": "別府駅",
        "Takegawara Onsen Beppu": "竹瓦温泉",
        "Beppu Tower": "別府タワー",
        "Beppu Park": "別府公園",
        "Aoshima Station Miyazaki": "青島駅",
        "Aoshima Beach Miyazaki": "青島ビーチ",
        "Aoshima Shrine": "青島神社",
        "Aoshima Botanical Garden": "宮交ボタニックガーデン青島",
        "Kagoshima Chuo Station": "鹿児島中央駅",
        "Tenmonkan Kagoshima": "天文館",
        "Shiroyama Observatory Kagoshima": "城山展望台",
        "Kagoshima City Aquarium": "かごしま水族館",
        "Kokusai Dori Naha": "国際通り",
        "Makishi Public Market Naha": "第一牧志公設市場",
        "Tsuboya Pottery Street Naha": "壺屋やちむん通り",
        "Fukushuen Garden Naha": "福州園",
        "Shuri Station Naha": "首里駅",
        "Shuri Castle Park": "首里城公園",
        "Tamaudun Shuri": "玉陵",
        "Kinjo Stone Paved Road Shuri": "金城町石畳道"
    ]
    static let summary = [
        "同じエリアの観光スポットを順番に巡ります。移動時間は経路検索で確認してください。",
        "같은 지역의 관광지를 차례로 둘러봅니다. 실제 이동 시간은 길찾기에서 확인하세요.",
        "依次游览同一区域的景点。请用路线搜索确认实际交通时间。",
        "Explore nearby sights in sequence. Check actual transfer times in directions.",
        "เที่ยวสถานที่ใกล้กันตามลำดับ ตรวจสอบเวลาเดินทางจริงในแผนที่"
    ]
    static let venueDetails = [
        "営業時間・入場方法を確認してから訪れてください。",
        "방문 전에 운영 시간과 입장 방법을 확인하세요.",
        "请在出发前确认营业时间和入场方式。",
        "Check hours and access before visiting.",
        "ตรวจสอบเวลาเปิดและวิธีเข้าชมก่อนเดินทาง"
    ]
}

private struct HotelSuggestion: Codable, Identifiable {
    let id: String
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    let phone: String?
    let website: String?
    let distance: Double
    var query: String { "\(latitude),\(longitude)" }
}

private struct FeaturedRouteInfo: Decodable {
    let fields: [[String]]
    let notes: [String]
    let accessURL: String
    let sourceURL: String
}
private enum FeaturedRoutes {
    static let routes: [DayRoute] = {
        let json = #"""
[{"id":"sns-gotokuji","prefecture":"tokyo","label":"Tokyo · Lucky cats & Setagaya tram","title":"Tokyo · Lucky cats & Setagaya tram","description":"Visit the temple whose lucky cats drew overseas social media attention, then local shopping streets.","area":"tokyo","gap":20,"stops":[{"type":"sight","duration":55,"choices":[["Gotokuji Temple","Check official information before visiting.","https://gotokuji.jp/"]]},{"type":"walk","duration":55,"choices":[["Gotokuji shopping street","Check official information before visiting.","https://www.google.com/maps/search/?api=1&query=%E8%B1%AA%E5%BE%B3%E5%AF%BA%E5%95%86%E5%BA%97%E8%A1%97+Japan"]]},{"type":"food","duration":60,"choices":[["Lunch near Gotokuji Station","Choose a nearby restaurant.","https://www.google.com/maps/search/?api=1&query=restaurants+Gotokuji+Station"]]},{"type":"break","duration":55,"choices":[["Sangenjaya shopping streets","Check official information before visiting.","https://www.google.com/maps/search/?api=1&query=%E4%B8%89%E8%BB%92%E8%8C%B6%E5%B1%8B%E3%81%AE%E5%95%86%E5%BA%97%E8%A1%97+Japan"]]}]},{"id":"sns-katsuoji","prefecture":"osaka","label":"Osaka · Katsuoji daruma & Minoh","title":"Osaka · Katsuoji daruma & Minoh","description":"Explore Katsuoji, popular with international visitors, then Minoh Station and the waterfall trail entrance.","area":"osaka","gap":45,"stops":[{"type":"sight","duration":55,"choices":[["Katsuoji Temple","Check official information before visiting.","https://katsuo-ji-temple.or.jp/"]]},{"type":"walk","duration":55,"choices":[["Minoh Station shopping street","Check official information before visiting.","https://www.google.com/maps/search/?api=1&query=%E7%AE%95%E9%9D%A2%E9%A7%85%E5%89%8D%E5%95%86%E5%BA%97%E8%A1%97+Japan"]]},{"type":"food","duration":60,"choices":[["Lunch near Minoh Station","Choose a nearby restaurant.","https://www.google.com/maps/search/?api=1&query=restaurants+Minoh+Station"]]},{"type":"break","duration":55,"choices":[["Minoh waterfall trail entrance","Check official information before visiting.","https://www.google.com/maps/search/?api=1&query=%E7%AE%95%E9%9D%A2%E6%BB%9D%E9%81%93%E5%85%A5%E5%8F%A3+Japan"]]}]},{"id":"sns-okusaga","prefecture":"kyoto","label":"Kyoto · Okusaga stone figures & old lanes","title":"Kyoto · Okusaga stone figures & old lanes","description":"Start at Otagi Nenbutsuji, attracting international visitors, and walk downhill through Saga Toriimoto.","area":"kyoto","gap":20,"stops":[{"type":"sight","duration":55,"choices":[["Otagi Nenbutsuji Temple","Check official information before visiting.","https://www.otagiji.com/visit-en"]]},{"type":"walk","duration":55,"choices":[["Saga Toriimoto preserved street","Check official information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%B5%AF%E5%B3%A8%E9%B3%A5%E5%B1%85%E6%9C%AC%E7%94%BA%E4%B8%A6%E3%81%BF%E4%BF%9D%E5%AD%98%E5%9C%B0%E5%8C%BA+Japan"]]},{"type":"food","duration":60,"choices":[["Lunch near Saga Toriimoto","Choose a nearby restaurant.","https://www.google.com/maps/search/?api=1&query=restaurants+Saga+Toriimoto+Kyoto"]]},{"type":"sight","duration":55,"choices":[["Adashino Nenbutsuji Temple","Check official information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%8C%96%E9%87%8E%E5%BF%B5%E4%BB%8F%E5%AF%BA+Japan"]]},{"type":"break","duration":55,"choices":[["Saga Arashiyama Station","Check official information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%B5%AF%E5%B3%A8%E5%B5%90%E5%B1%B1%E9%A7%85+Japan"]]}]},{"id":"sns-chichibugahama","prefecture":"kagawa","label":"Kagawa · Chichibugahama mirror beach & Nio","title":"Kagawa · Chichibugahama mirror beach & Nio","description":"Explore Nio port town and the beach attracting international social media attention.","area":"kagawa","gap":20,"stops":[{"type":"sight","duration":55,"choices":[["Nio port town","Check official information before visiting.","https://www.google.com/maps/search/?api=1&query=%E4%BB%81%E5%B0%BE%E3%81%AE%E6%B8%AF%E7%94%BA+Japan"]]},{"type":"walk","duration":55,"choices":[["Nio Hachiman Shrine","Check official information before visiting.","https://www.google.com/maps/search/?api=1&query=%E4%BB%81%E5%B0%BE%E5%85%AB%E5%B9%A1%E7%A5%9E%E7%A4%BE+Japan"]]},{"type":"food","duration":60,"choices":[["Lunch near Nio Mitoyo","Choose a nearby restaurant.","https://www.google.com/maps/search/?api=1&query=restaurants+Nio+Mitoyo"]]},{"type":"break","duration":55,"choices":[["Chichibugahama Beach","Check official information before visiting.","https://www.mitoyo-kanko.com/chichibugahama/"]]}]}]
"""#
        guard let result = try? JSONDecoder().decode([DayRoute].self, from: Data(json.utf8)) else { preconditionFailure("Invalid featured routes") }
        return result
    }()
    static let info: [String: FeaturedRouteInfo] = {
        let json = #"""
{"sns-gotokuji":{"fields":[["東京・豪徳寺の招き猫と世田谷線","東京・豪徳寺の招き猫と世田谷線","招き猫が海外SNSで話題の豪徳寺から、世田谷の商店街へ。","東京・豪徳寺の招き猫と世田谷線"],["도쿄·고토쿠지 고양이와 세타가야선","도쿄·고토쿠지 고양이와 세타가야선","해외 SNS에서 주목받는 고토쿠지와 세타가야 상점가.","도쿄·고토쿠지 고양이와 세타가야선"],["东京·豪德寺招财猫与世田谷线","东京·豪德寺招财猫与世田谷线","从海外社交媒体关注的豪德寺，游览世田谷商店街。","东京·豪德寺招财猫与世田谷线"],["Tokyo · Lucky cats & Setagaya tram","Tokyo · Lucky cats & Setagaya tram","Visit the temple whose lucky cats drew overseas social media attention, then local shopping streets.","Tokyo · Lucky cats & Setagaya tram"],["โตเกียว·แมวกวักและรถรางเซตากายะ","โตเกียว·แมวกวักและรถรางเซตากายะ","ชมแมวกวักที่เป็นที่สนใจบนโซเชียลต่างประเทศแล้วเดินย่านร้านค้าท้องถิ่น","โตเกียว·แมวกวักและรถรางเซตากายะ"]],"notes":["宮の坂駅から徒歩約5分。招き猫は動かさず、住宅街では通行の妨げにならないように。","미야노사카역에서 도보 약 5분. 고양이상을 옮기지 말고 주거지 통행을 방해하지 마세요.","宫之坂站步行约5分钟。请勿移动猫像或妨碍住宅区通行。","About 5 minutes on foot from Miyanosaka Station. Leave cat figures in place and keep residential paths clear.","เดินประมาณ 5 นาทีจากสถานีมิยาโนะซากะ ไม่เคลื่อนย้ายรูปแมวและไม่กีดขวางทาง"],"accessURL":"https://gotokuji.jp/","sourceURL":"https://www.fnn.jp/articles/-/965434"},"sns-katsuoji":{"fields":[["大阪・勝尾寺のだるまと箕面","大阪・勝尾寺のだるまと箕面","外国人旅行者にも人気の勝尾寺と、箕面の駅前・滝道入口を巡る。","大阪・勝尾寺のだるまと箕面"],["오사카·가쓰오지 달마와 미노오","오사카·가쓰오지 달마와 미노오","외국인에게도 인기 있는 가쓰오지와 미노오 역·산책로 입구.","오사카·가쓰오지 달마와 미노오"],["大阪·胜尾寺达摩与箕面","大阪·胜尾寺达摩与箕面","游览海外游客喜爱的胜尾寺及箕面站与瀑布步道入口。","大阪·胜尾寺达摩与箕面"],["Osaka · Katsuoji daruma & Minoh","Osaka · Katsuoji daruma & Minoh","Explore Katsuoji, popular with international visitors, then Minoh Station and the waterfall trail entrance.","Osaka · Katsuoji daruma & Minoh"],["โอซาก้า·ดารุมะวัดคัตสึโอจิและมิโน","โอซาก้า·ดารุมะวัดคัตสึโอจิและมิโน","ชมวัดคัตสึโอจิที่นักท่องเที่ยวต่างชาติชื่นชอบแล้วเดินบริเวณสถานีมิโน","โอซาก้า·ดารุมะวัดคัตสึโอจิและมิโน"]],"notes":["勝尾寺へは箕面萱野駅からバス。寺から箕面駅周辺は公共交通・タクシーの経路を確認。山道の徒歩移動を前提にしません。","미노오카야노역에서 버스. 사찰에서 미노오역까지 대중교통·택시 경로를 확인하세요. 산길 도보 코스가 아닙니다.","从箕面萱野站乘巴士。寺院到箕面站请查看公交或出租车路线，不按山路步行安排。","Take a bus from Minoh-kayano. Check transit or taxi routing to Minoh Station; this plan does not assume walking mountain roads.","นั่งรถบัสจากมิโนคายาโนะ ตรวจสอบขนส่งหรือแท็กซี่ไปสถานีมิโน ไม่วางแผนเดินถนนบนเขา"],"accessURL":"https://katsuo-ji-temple.or.jp/access/index.php","sourceURL":"https://prtimes.jp/main/html/rd/p/000000030.000111535.html"},"sns-okusaga":{"fields":[["京都・奥嵯峨の羅漢と古い街並み","京都・奥嵯峨の羅漢と古い街並み","海外旅行者が注目する愛宕念仏寺から、嵯峨鳥居本を下る散策。","京都・奥嵯峨の羅漢と古い街並み"],["교토·오쿠사가 석상과 옛 거리","교토·오쿠사가 석상과 옛 거리","해외 여행자가 주목하는 오타기넨부쓰지에서 사가토리이모토로 내려가는 산책.","교토·오쿠사가 석상과 옛 거리"],["京都·奥嵯峨罗汉与古街","京都·奥嵯峨罗汉与古街","从海外游客关注的爱宕念佛寺，沿嵯峨鸟居本下行漫步。","京都·奥嵯峨罗汉与古街"],["Kyoto · Okusaga stone figures & old lanes","Kyoto · Okusaga stone figures & old lanes","Start at Otagi Nenbutsuji, attracting international visitors, and walk downhill through Saga Toriimoto.","Kyoto · Okusaga stone figures & old lanes"],["เกียวโต·รูปหินและถนนเก่าโอคุซากะ","เกียวโต·รูปหินและถนนเก่าโอคุซากะ","เริ่มวัดโอตากิเน็นบุตสึจิที่นักท่องเที่ยวต่างชาติสนใจแล้วเดินลงผ่านซากะโทริอิโมโตะ","เกียวโต·รูปหินและถนนเก่าโอคุซากะ"]],"notes":["寺へは先にバス・タクシーで上がり、帰りは下り坂。公式案内では水曜・土曜休み。訪問前に営業日を確認してください。","먼저 버스·택시로 올라가고 내려오는 코스입니다. 공식 안내는 수·토 휴무. 방문 전 확인하세요.","先乘巴士或出租车上山，再沿下坡游览。官网目前周三、周六休息，出发前请确认。","Go uphill by bus or taxi, then walk downhill. The official site currently lists Wednesday and Saturday closures; recheck before visiting.","ขึ้นไปด้วยรถบัสหรือแท็กซี่แล้วเดินลง เว็บไซต์แจ้งหยุดพุธและเสาร์ ตรวจสอบก่อนเดินทาง"],"accessURL":"https://www.otagiji.com/visit-jp","sourceURL":"https://mezamashi.media/articles/-/186389"},"sns-chichibugahama":{"fields":[["香川・父母ヶ浜の天空の鏡と仁尾","香川・父母ヶ浜の天空の鏡と仁尾","海外SNSでも注目される父母ヶ浜へ。仁尾の港町散策と海辺の写真を楽しむ。","香川・父母ヶ浜の天空の鏡と仁尾"],["가가와·지치부가하마 거울 바다와 니오","가가와·지치부가하마 거울 바다와 니오","해외 SNS에서도 주목받는 해변. 니오 항구 산책과 바다 사진.","가가와·지치부가하마 거울 바다와 니오"],["香川·父母之滨天空之镜与仁尾","香川·父母之滨天空之镜与仁尾","前往海外社交媒体关注的海滩，漫步仁尾港镇并欣赏海景。","香川·父母之滨天空之镜与仁尾"],["Kagawa · Chichibugahama mirror beach & Nio","Kagawa · Chichibugahama mirror beach & Nio","Explore Nio port town and the beach attracting international social media attention.","Kagawa · Chichibugahama mirror beach & Nio"],["คางาวะ·หาดกระจกจิจิบุกาฮามะและนิโอ","คางาวะ·หาดกระจกจิจิบุกาฮามะและนิโอ","เดินเมืองท่านิโอและชมหาดที่ได้รับความสนใจบนโซเชียลต่างประเทศ","คางาวะ·หาดกระจกจิจิบุกาฮามะและนิโอ"]],"notes":["天空の鏡は干潮・日没・弱い風が条件。表示時刻は目安なので、公式カレンダーに合わせて出発時間を調整。帰りの交通も先に確認。","거울 풍경은 간조·일몰·약한 바람이 조건입니다. 시간은 예시이므로 공식 달력에 맞춰 출발을 조정하고 귀가 교통도 확인하세요.","镜面景观需退潮、日落与微风。行程时间为参考，请按官网日历调整出发时间并提前确认返程交通。","Mirror photos need low tide, sunset and calm wind. Times are estimates: adjust departure to the official calendar and check return transport.","ภาพกระจกต้องช่วงน้ำลง พระอาทิตย์ตก และลมสงบ เวลาเป็นประมาณการ ปรับตามปฏิทินและตรวจสอบรถกลับ"],"accessURL":"https://www.mitoyo-kanko.com/chichibugahama/","sourceURL":"https://www.mitoyo-kanko.com/author/mitoyokokusaikanko/"}}
"""#
        guard let result = try? JSONDecoder().decode([String: FeaturedRouteInfo].self, from: Data(json.utf8)) else { preconditionFailure("Invalid featured info") }
        return result
    }()
    static let names: [String: [String]] = {
        let json = #"""
{"Gotokuji Temple":["豪徳寺","고토쿠지","豪德寺","Gotokuji Temple","วัดโกโทคุจิ"],"Gotokuji shopping street":["豪徳寺商店街","고토쿠지 상점가","豪德寺商店街","Gotokuji shopping street","ย่านร้านค้าโกโทคุจิ"],"Sangenjaya shopping streets":["三軒茶屋の商店街","산겐자야 상점가","三轩茶屋商店街","Sangenjaya shopping streets","ย่านร้านค้าซังเก็นจายะ"],"Katsuoji Temple":["勝尾寺","가쓰오지","胜尾寺","Katsuoji Temple","วัดคัตสึโอจิ"],"Minoh Station shopping street":["箕面駅前商店街","미노오역 상점가","箕面站前商店街","Minoh Station shopping street","ย่านร้านค้าสถานีมิโน"],"Minoh waterfall trail entrance":["箕面滝道入口","미노오 폭포 산책로 입구","箕面瀑布步道入口","Minoh waterfall trail entrance","ทางเข้าทางเดินน้ำตกมิโน"],"Otagi Nenbutsuji Temple":["愛宕念仏寺","오타기넨부쓰지","爱宕念佛寺","Otagi Nenbutsuji Temple","วัดโอตากิเน็นบุตสึจิ"],"Saga Toriimoto preserved street":["嵯峨鳥居本町並み保存地区","사가토리이모토 옛 거리","嵯峨鸟居本传统街区","Saga Toriimoto preserved street","ถนนอนุรักษ์ซากะโทริอิโมโตะ"],"Adashino Nenbutsuji Temple":["化野念仏寺","아다시노넨부쓰지","化野念佛寺","Adashino Nenbutsuji Temple","วัดอาดาชิโนะเน็นบุตสึจิ"],"Saga Arashiyama Station":["嵯峨嵐山駅","사가아라시야마역","嵯峨岚山站","Saga Arashiyama Station","สถานีซากะอาราชิยามะ"],"Nio port town":["仁尾の港町","니오 항구마을","仁尾港镇","Nio port town","เมืองท่านิโอ"],"Nio Hachiman Shrine":["仁尾八幡神社","니오하치만 신사","仁尾八幡神社","Nio Hachiman Shrine","ศาลเจ้านิโอฮาจิมัง"],"Chichibugahama Beach":["父母ヶ浜","지치부가하마","父母之滨","Chichibugahama Beach","หาดจิจิบุกาฮามะ"]}
"""#
        guard let result = try? JSONDecoder().decode([String: [String]].self, from: Data(json.utf8)) else { preconditionFailure("Invalid featured names") }
        return result
    }()
    static let ui: [String: [String]] = {
        let json = #"""
{"featured":["SNS・海外旅行者の注目コース","SNS·해외 여행자 주목 코스","社交媒体与海外游客关注路线","Social media & international visitor picks","เส้นทางที่ได้รับความสนใจบนโซเชียลและจากนักท่องเที่ยว"],"featuredNote":["コース名と行き先を見て、ボタンを押すだけ。2026年10月調査。人気順ではありません。","코스와 장소를 보고 바로 선택하세요. 2026년 10월 조사. 인기 순위가 아닙니다.","查看路线与景点，直接点击选择。2026年10月核查，非人气排名。","See the stops and tap a course. Researched October 2026; not a popularity ranking.","ดูสถานที่แล้วกดเลือกเส้นทาง ตรวจสอบตุลาคม 2026 ไม่ใช่อันดับความนิยม"],"access":["営業時間・交通・撮影条件を確認","운영 시간·교통·촬영 조건 확인","查看开放时间、交通与拍摄条件","Check hours, access & photo conditions","ตรวจสอบเวลา การเดินทาง และเงื่อนไขถ่ายภาพ"],"source":["注目されている理由・調査元","주목받는 이유·출처","关注原因与资料来源","Why it is featured · source","เหตุผลที่ได้รับความสนใจและแหล่งข้อมูล"],"visitNote":["営業時間や撮影ルールは公式情報で確認。移動は下の徒歩・公共交通リンクから。","공식 운영 시간과 촬영 규칙을 확인하세요. 아래 도보·대중교통 링크를 이용하세요.","请在官网查看开放时间与拍摄规则。下方提供步行和公共交通路线。","Check official hours and photo rules. Use the walking and transit links below.","ตรวจสอบเวลาเปิดและกฎถ่ายภาพ ใช้ลิงก์เดินหรือขนส่งสาธารณะด้านล่าง"]}
"""#
        guard let result = try? JSONDecoder().decode([String: [String]].self, from: Data(json.utf8)) else { preconditionFailure("Invalid featured ui") }
        return result
    }()
}
