import SwiftUI

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
        let hour = (minutes / 60) % 24
        return String(format: "%d:%02d %@", hour % 12 == 0 ? 12 : hour % 12, minutes % 60, hour < 12 ? "AM" : "PM")
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
        var lines = ["Japan Day Planner · \(route.label)"]
        for index in route.stops.indices {
            let venue = selectedVenue(index)
            lines.append("\(time(startOfStop(index))) · \(venue.name) · \(venue.url)")
        }
        lines.append("Timing is an estimate. Confirm hours and travel before visiting.")
        return lines.joined(separator: "\n")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    intro
                    controls
                    VStack(alignment: .leading, spacing: 6) {
                        Text(route.title).font(.title2.bold())
                        Text(route.description).foregroundStyle(.secondary)
                        Text("\(route.area) · \(route.stops.count) stops · around \(time(startOfStop(route.stops.count - 1) + duration(route.stops.last!, venue: selectedVenue(route.stops.count - 1)))) finish")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(route.stops.indices, id: \.self) { index in
                        if index > 0 {
                            Label("Allow about \(route.gap) min to the next stop", systemImage: "figure.walk")
                                .font(.caption).foregroundStyle(.secondary)
                                .padding(.leading, 10)
                        }
                        stopCard(index)
                    }
                    Text("Times and transfer gaps are planning estimates. Check opening hours, tickets, reservations and routes before travelling.")
                        .font(.footnote).foregroundStyle(.secondary).padding(.bottom)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Japan Day Planner")
            .toolbar { ShareLink(item: sharedPlan) { Image(systemName: "square.and.arrow.up") }.accessibilityLabel("Share this itinerary") }
            .sheet(isPresented: Binding(get: { swapIndex != nil }, set: { if !$0 { swapIndex = nil } })) {
                if let index = swapIndex { swapSheet(index) }
            }
        }
        .tint(Color(red: 0.07, green: 0.40, blue: 0.43))
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("SEE JAPAN · TASTE JAPAN").font(.caption.bold()).tracking(2).foregroundStyle(.yellow)
            Text("A day that changes with you.").font(.largeTitle.bold()).foregroundStyle(.white)
            Text("Pick a route. Swap a sight or lunch. Your times update instantly.")
                .foregroundStyle(.white.opacity(0.88))
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(22)
        .background(Color(red: 0.08, green: 0.17, blue: 0.22), in: RoundedRectangle(cornerRadius: 18))
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("City route", selection: $routeID) {
                ForEach(guide.routes) { item in Text(item.label).tag(item.id) }
            }
            Picker("Start", selection: $startMinutes) {
                Text("9:00 AM").tag(540)
                Text("10:00 AM").tag(600)
                Text("11:00 AM").tag(660)
            }
        }
        .padding(14).background(.white, in: RoundedRectangle(cornerRadius: 15))
    }

    private func stopCard(_ index: Int) -> some View {
        let stop = route.stops[index]
        let venue = selectedVenue(index)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(time(startOfStop(index))).font(.subheadline.bold()).monospacedDigit()
                Spacer()
                Text(stop.type == "food" ? "LUNCH" : stop.type == "walk" ? "EXPLORE" : "SIGHT")
                    .font(.caption2.bold()).tracking(1).foregroundStyle(.orange)
            }
            Text(venue.name).font(.title3.bold())
            Text(venue.detail).font(.subheadline).foregroundStyle(.secondary)
            Text(guide.notes[venue.name] ?? "Check local information before visiting.")
                .font(.footnote).padding(10).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 9))
            HStack {
                Text("About \(duration(stop, venue: venue)) min").font(.caption).foregroundStyle(.secondary)
                Spacer()
                if let url = URL(string: venue.url) {
                    Link("Details", destination: url).font(.subheadline.bold())
                }
                Button("Swap") { swapIndex = index }.font(.subheadline.bold())
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(16).background(.white, in: RoundedRectangle(cornerRadius: 16))
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
                            Text(venue.name).font(.headline)
                            if choice == selectedIndex(index) { Image(systemName: "checkmark.circle.fill") }
                        }
                        Text(venue.detail).font(.subheadline).foregroundStyle(.secondary)
                        Text("About \(duration(stop, venue: venue)) min")
                            .font(.caption).foregroundStyle(.secondary)
                    }.padding(.vertical, 5)
                }.foregroundStyle(.primary)
            }
            .navigationTitle(stop.type == "food" ? "Choose lunch" : "Swap this stop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { swapIndex = nil } }
        }
        .presentationDetents([.medium, .large])
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? { indices.contains(index) ? self[index] : nil }
}
