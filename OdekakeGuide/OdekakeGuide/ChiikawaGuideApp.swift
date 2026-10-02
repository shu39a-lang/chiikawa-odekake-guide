import SwiftUI
import Foundation

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
        return guide
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
    @AppStorage("japanDay.start") private var startMinutes = 600
    @AppStorage("japanDay.choices") private var savedChoices = "{}"
    @State private var swapIndex: Int?
    @AppStorage("japanDay.language") private var languageCode = "ja"
    @State private var showingGuide = false

    private var language: GuideLanguage { GuideLanguage(rawValue: languageCode) ?? .ja }
    private func text(_ key: String) -> String { GuideTranslations.ui[key]?[language.index] ?? key }
    private func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: language.locale, arguments: arguments)
    }
    private func routeText(_ item: DayRoute, _ field: Int) -> String {
        GuideTranslations.routes[item.id]?[language.index][field] ?? [item.label, item.title, item.description, item.area][field]
    }
    private func venueText(_ venue: Venue, _ field: Int) -> String {
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
            lines.append("\(time(startOfStop(index))) · \(venueText(venue, 0)) · \(venue.url)")
        }
        lines.append(text("sharedNote"))
        return lines.joined(separator: "\n")
    }

    var body: some View {
        NavigationStack {
            if showingGuide {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    languageButtons
                    intro
                    controls
                    VStack(alignment: .leading, spacing: 6) {
                        Text(routeText(route, 1)).font(.title2.bold())
                        Text(routeText(route, 2)).foregroundStyle(.secondary)
                        Text(format("summary", routeText(route, 3), route.stops.count, finishTime))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(route.stops.indices, id: \.self) { index in
                        if index > 0 {
                            Label(format("gap", route.gap), systemImage: "figure.walk")
                                .font(.caption).foregroundStyle(.secondary)
                                .padding(.leading, 10)
                        }
                        stopCard(index)
                    }
                    Text(text("footer"))
                        .font(.footnote).foregroundStyle(.secondary).padding(.bottom)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Japan Day Planner")
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
            } else {
                languageHome
            }
        }
        .environment(\.locale, language.locale)
        .preferredColorScheme(.dark)
        .tint(Color(red: 0.25, green: 0.78, blue: 0.80))
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

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker(text("route"), selection: $routeID) {
                ForEach(guide.routes) { item in Text(routeText(item, 0)).tag(item.id) }
            }
            Picker(text("start"), selection: $startMinutes) {
                Text(time(540)).tag(540)
                Text(time(600)).tag(600)
                Text(time(660)).tag(660)
            }
        }
        .padding(14).background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 15))
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
                Spacer()
                if let url = URL(string: venue.url) {
                    Link(text("details"), destination: url).font(.subheadline.bold())
                }
                Button(text("swap")) { swapIndex = index }.font(.subheadline.bold())
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(16).background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
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
