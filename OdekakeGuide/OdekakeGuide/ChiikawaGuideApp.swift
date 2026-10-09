// DESIGN PREVIEW — NOT the requested complete multilingual release.
// Existing five languages only; no new language is silently mapped to English.
import SwiftUI
import UIKit
import Foundation
import MapKit
import CoreLocation
import WebKit

private struct TravelTime {
    let minutes: Int
    // True only for a distance-based fallback, never for a timetable result.
    let isApproximate: Bool
    var routeMetres: Double? = nil
    var straightMetres: Double? = nil

    static func rough(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D,
                      by mode: MKDirectionsTransportType) -> TravelTime? {
        guard CLLocationCoordinate2DIsValid(from), CLLocationCoordinate2DIsValid(to),
              mode == .walking || mode == .automobile else { return nil }
        let straight = CLLocation(latitude: from.latitude, longitude: from.longitude)
            .distance(from: CLLocation(latitude: to.latitude, longitude: to.longitude))
        guard straight.isFinite else { return nil }
        // Coarse planning guidance, never a measured route or a claim of access.
        let metresPerMinute: Double = mode == .walking ? (4000.0 / 60.0) : (25000.0 / 60.0)
        let roughMinutes = straight * 1.4 / metresPerMinute
        let roundedMinutes = Int(ceil(roughMinutes / 5.0)) * 5
        let minutes = max(5, roundedMinutes)
        return TravelTime(minutes: minutes, isApproximate: true, straightMetres: straight)
    }
}

@MainActor
private enum RouteMeasurements {
    private static var cache: [String: (Date, TravelTime)] = [:]

    static func fetch(from origin: MKMapItem, to destination: MKMapItem,
                      by mode: MKDirectionsTransportType) async -> TravelTime? {
        let a = origin.placemark.coordinate, b = destination.placemark.coordinate
        guard CLLocationCoordinate2DIsValid(a), CLLocationCoordinate2DIsValid(b), !Task.isCancelled else { return nil }
        let key = "\(a.latitude),\(a.longitude)>\(b.latitude),\(b.longitude)|\(mode.rawValue)"
        if let (date, value) = cache[key], Date().timeIntervalSince(date) < 300 { return value }
        let request = MKDirections.Request()
        request.source = origin; request.destination = destination
        request.transportType = mode; request.departureDate = Date()
        request.requestsAlternateRoutes = true
        let directions = MKDirections(request: request)
        let timeout = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 12_000_000_000)
            if !Task.isCancelled { directions.cancel() }
        }
        defer { timeout.cancel() }
        let response = try? await directions.calculate()
        guard !Task.isCancelled,
              let route = response?.routes.filter({
                  $0.distance.isFinite && $0.distance >= 0 &&
                  $0.expectedTravelTime.isFinite && $0.expectedTravelTime > 0 &&
                  $0.expectedTravelTime / 60 < Double(Int.max)
              }).min(by: { $0.expectedTravelTime < $1.expectedTravelTime }) else { return nil }
        let value = TravelTime(minutes: max(1, Int(ceil(route.expectedTravelTime / 60))),
                               isApproximate: false, routeMetres: route.distance)
        if cache.count > 300 { cache.removeAll() }
        cache[key] = (Date(), value)
        return value
    }
}

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
    @State private var presentedMap: PlannerMapRequest?
    @AppStorage("japanDay.language") private var languageCode = "ja"
    @State private var showingGuide = false
    @State private var showingLanguageSelection = false
    @State private var selectionInstructionsLanguage: GuideLanguage?
    @State private var instructionsLanguage: GuideLanguage?
    @State private var savedHotels = "{}"
    @State private var savedCustomHotels = "{}"
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
    @State private var resolvedPlaceCache: [String: MKMapItem] = [:]
    @State private var hotelResults: [HotelSuggestion] = []
    @State private var hotelWalkingTimes: [String: TravelTime] = [:]
    @State private var hotelSortByWalking = true

    private var sortedHotelResults: [HotelSuggestion] {
        hotelResults.sorted { a, b in
            if hotelSortByWalking {
                let x = hotelWalkingTimes[a.id]?.routeMetres
                let y = hotelWalkingTimes[b.id]?.routeMetres
                if let x, let y, x != y { return x < y }
                if (x != nil) != (y != nil) { return x != nil }
            }
            if a.distance != b.distance { return a.distance < b.distance }
            return a.id < b.id
        }
    }
    @State private var hotelSearching = false
    @State private var hotelSearchError = false
    @State private var hotelSearchID = UUID()
    @State private var hotelTravelMinutes: [String: TravelTime] = [:]
    @State private var hotelTravelLoading = false
    @State private var savedSuggestedHotels = "{}"
    @State private var routeLegTimes: [String: [String: TravelTime]] = [:]
    @State private var routeLegLoading: Set<String> = []

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
    // UI preview only: additional languages require complete translation packs.
    // Keep the five existing translation indices unchanged.
    private var languageSelectionTitle: String {
        ["ja":"国・言語を選ぶ", "ko":"국가·언어 선택", "zh":"选择国家和语言", "zht":"選擇國家和語言", "en":"Country / Language", "th":"เลือกประเทศ / ภาษา", "fr":"Pays / langue", "de":"Land / Sprache", "es":"País / idioma", "it":"Paese / lingua", "pt":"País / idioma", "hi":"देश / भाषा", "vi":"Quốc gia / ngôn ngữ", "id":"Negara / bahasa", "ms":"Negara / bahasa", "fil":"Bansa / wika", "ru":"Страна / язык", "nl":"Land / taal", "tr":"Ülke / dil", "pl":"Kraj / język", "ar":"الدولة / اللغة", "my":"နိုင်ငံ / ဘာသာ", "ne":"देश / भाषा", "si":"රට / භාෂාව", "km":"ប្រទេស / ភាសា", "he":"מדינה / שפה", "uk":"Країна / мова"][language.rawValue] ?? "Country / Language"
    }
    private var languageSelectionButton: some View {
        Button { showingLanguageSelection = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "globe").font(.title2)
                Text(languageSelectionTitle).font(.headline.bold())
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Image(systemName: "chevron.down").font(.headline)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18).padding(.vertical, 16)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(LinearGradient(colors: [Color(red: 0.43, green: 0.10, blue: 0.80), Color(red: 0.04, green: 0.25, blue: 0.77), Color(red: 0.0, green: 0.43, blue: 0.40)], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.cyan.opacity(0.65), lineWidth: 1.5))
            .shadow(color: .cyan.opacity(0.16), radius: 8)
        }.buttonStyle(.plain)
    }
    private func languageChoice(_ item: GuideLanguage) -> some View {
        HStack(alignment: .center, spacing: 6) {
            Button {
                swapIndex = nil
                languageCode = item.rawValue
                showingGuide = true
                showingLanguageSelection = false
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.countryTitle).font(.subheadline.bold())
                    Text(item.title).font(.caption).foregroundStyle(.white.opacity(0.8))
                    if language == item {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(PlannerTheme.amber)
                    }
                }
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                .contentShape(Rectangle())
            }.buttonStyle(.plain)
                .accessibilityLabel("\(item.countryTitle) · \(item.title)")
                .accessibilityAddTraits(language == item ? [.isSelected] : [])
            Button { selectionInstructionsLanguage = item } label: {
                Text(PlannerInstructions.buttonTitle(item))
                    .font(.caption.weight(.semibold)).underline()
                    .foregroundStyle(PlannerTheme.amber)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minWidth: 44, minHeight: 44)
            }.buttonStyle(.plain)
        }
        .padding(10).frame(maxWidth: .infinity, minHeight: 86)
        .background(PlannerTheme.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(language == item ? PlannerTheme.amber : Color.white.opacity(0.18), lineWidth: language == item ? 2 : 1))
    }
    private var languageSelectionSheet: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(GuideLanguage.allCases) { item in languageChoice(item) }
                }.padding(14)
            }
            .background(PlannerTheme.background)
            .navigationTitle(languageSelectionTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(PlannerInstructions.closeTitle(language)) { showingLanguageSelection = false }
                }
            }
            .sheet(item: $selectionInstructionsLanguage) { item in
                PlannerInstructionsView(language: item)
            }
        }.preferredColorScheme(.dark)
    }
    private var languageHome: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Japan Day Planner").font(.largeTitle.bold()).foregroundStyle(.white)
                languageSelectionButton
                Text(language.title).font(.subheadline).foregroundStyle(.white.opacity(0.8))
                Text(text("tagline")).font(.headline).foregroundStyle(.white)
                PlannerTravelBanner().frame(height: 170)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                featuredHomeEntry
                Button {
                    showingGuide = true
                } label: {
                    Label(text("route"), systemImage: "map.fill")
                        .font(.headline).foregroundStyle(.white)
                        .padding(18).frame(maxWidth: .infinity)
                        .background(PlannerTheme.surface, in: RoundedRectangle(cornerRadius: 18))
                }.buttonStyle(.plain)
                originalCourseEntry
            }
            .padding(20).frame(maxWidth: 650, alignment: .leading)
            .frame(maxWidth: .infinity)
        }.background(PlannerTheme.background)
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
        resetHotelSelection()
        resetJourney()
        prefectureID = value
        if let first = guide.routes.first(where: { ($0.prefecture ?? NationwideRoutes.existingPrefectures[$0.id]) == value }) {
            routeID = first.id
        }
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
        if index == 0 && selectedIndex(index) != choice {
            resetHotelSelection()
            resetJourney()
        }
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
                            plannerHeading
                            controls
                            selectedRouteHeading
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
                    .onChange(of: hotelTravelKey) { _ in
                        if selectedSearchedHotelVisible {
                            DispatchQueue.main.async {
                                withAnimation { proxy.scrollTo("selectedHotelTravel", anchor: .center) }
                            }
                        }
                    }
                }
                .navigationTitle("Japan Day Planner")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(text("home")) { showingGuide = false }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button { instructionsLanguage = language } label: {
                            Image(systemName: "book.closed.fill")
                                .frame(width: 36, height: 36)
                                .background(PlannerTheme.cyan.opacity(0.15), in: Circle())
                        }.accessibilityLabel(PlannerInstructions.buttonTitle(language))
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        ShareLink(item: sharedPlan) { Image(systemName: "square.and.arrow.up") }
                            .accessibilityLabel(text("share"))
                    }
                }
                .sheet(isPresented: Binding(get: { swapIndex != nil }, set: { if !$0 { swapIndex = nil } })) {
                    if let index = swapIndex { swapSheet(index) }
                }
                .onChange(of: routeID) { _ in resetHotelSelection(); resetJourney() }
                .onChange(of: selectedVenue(0).name) { _ in resetHotelSelection(); resetJourney() }
                .onAppear {
                    let oldPrefecture = routePrefecture
                    if prefectureID != oldPrefecture {
                        prefectureID = oldPrefecture
                        regionID = NationwideRoutes.prefectures.first(where: { $0.id == oldPrefecture })?.region ?? "kanto"
                    }
                }
                .onChange(of: startMinutes) { _ in resetJourney() }
                .onChange(of: dinnerArea) { _ in resetJourney() }
                .onChange(of: savedChoices) { _ in routeLegTimes = [:]; resetDinner(); resetLunch() }
                .onChange(of: dinnerNearHotel) { _ in resetJourney() }
            } else {
                languageHome
            }
        }
        .sheet(isPresented: $showingLanguageSelection) { languageSelectionSheet }
        .sheet(item: $presentedMap) { request in
            PlannerMapScreen(request: request, language: language)
        }
        .sheet(item: $instructionsLanguage) { item in
            PlannerInstructionsView(language: item)
        }
        .environment(\.locale, language.locale)
        .preferredColorScheme(.dark)
        .tint(journeyGold)
    }


    // Each destination and transfer has its own visible stage.
    private enum JourneyStage {
        case departure, stop(Int), hotelBeforeDinner, dinner, hotelAfterDinner
    }
    private let journeyBackground = PlannerTheme.background
    private let journeySurface = PlannerTheme.surface
    private let journeyGold = PlannerTheme.cyan

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
    private func resetHotelSelection() {
        savedHotels = "{}"
        savedCustomHotels = "{}"
        savedSuggestedHotels = "{}"
        hotelTravelMinutes = [:]
        hotelTravelLoading = false
        clearHotelSearch()
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
        if value == "suggested", let selected = selectedSuggestedHotel {
            // Hotels saved by an older search lack an anchor and may have been
            // measured from a different city. Require a fresh search for them.
            if selected.id.hasPrefix("registered|\(route.id)|\(selectedVenue(0).name)|") { return value }
            guard let anchorLatitude = selected.anchorLatitude,
                  let anchorLongitude = selected.anchorLongitude else { return "" }
            if let actual = pinnedFirstVenueCoordinate,
               CLLocation(latitude: actual.latitude, longitude: actual.longitude)
                .distance(from: CLLocation(latitude: anchorLatitude, longitude: anchorLongitude)) > 100 {
                return ""
            }
            return value
        }
        return ""
    }
    private var chosenHotel: NearbyHotel? { availableHotels.first(where: { $0.id == hotelChoice }) }
    private var customHotel: String { storedValues(savedCustomHotels)[route.id] ?? "" }
    private var hotelName: String {
        chosenHotel?.names[language.index] ?? (hotelChoice == "suggested" ? selectedSuggestedHotel?.name : nil) ?? (customHotel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? journeyText("enterHotel") : customHotel)
    }
    private var hotelQuery: String {
        if let hotel = chosenHotel { return "\(hotel.names[0]), \(hotel.addressJP), Japan" }
        if hotelChoice == "suggested", let hotel = selectedSuggestedHotel { return hotel.query }
        guard hotelChoice == "custom" else { return "" }
        let value = customHotel.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefecture = NationwideRoutes.prefectures.first(where: { $0.id == routePrefecture })?.ja ?? cityQuery
        return value.isEmpty ? "" : "\(value), \(prefecture), Japan"
    }
    private var hotelTravelKey: String {
        "\(route.id)|\(selectedVenue(0).name)|\(hotelQuery)"
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
        routeLegTimes = [:]
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
    private func journeyPanel<Content: View>(accent: Color = PlannerTheme.cyan, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14, content: content)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(journeySurface, in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(accent.opacity(0.28), lineWidth: 1))
    }
    private func journeyAction(_ title: String, systemImage: String = "arrow.right", accent: Color = PlannerTheme.cyan, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage).font(.headline)
                    .frame(width: 34, height: 34).background(Color.black.opacity(0.10), in: Circle())
                Text(title).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .font(.headline).padding(.horizontal, 16).padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 54)
            .foregroundStyle(Color.black)
            .background(accent, in: RoundedRectangle(cornerRadius: 28))
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
        default: return language.webLanguageCode
        }
    }
    private func translatedGuideURL(_ original: URL) -> URL? {
        guard language != .ja, let scheme = original.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              let host = original.host?.lowercased(),
              host != "translate.google.com", host != "translate.google.co.jp",
              !host.hasSuffix(".translate.goog"),
              !(host == "google.com" || host.hasSuffix(".google.com")),
              !(host == "google.co.jp" || host.hasSuffix(".google.co.jp")) else { return nil }
        var parts = URLComponents(string: "https://translate.google.com/translate")
        parts?.queryItems = [
            URLQueryItem(name: "sl", value: "auto"),
            URLQueryItem(name: "tl", value: targetWebLanguage),
            URLQueryItem(name: "hl", value: targetWebLanguage),
            URLQueryItem(name: "u", value: original.absoluteString)
        ]
        return parts?.url
    }
    private func isMapURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return (host == "www.google.com" || host == "google.com" || host == "maps.google.com"
                || host == "www.google.co.jp" || host == "maps.google.co.jp")
            && (url.path == "/maps" || url.path.hasPrefix("/maps/") || host.hasPrefix("maps."))
    }
    private func localizedMapURL(_ original: URL) -> URL {
        guard isMapURL(original) else { return original }
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
                Menu {
                    Link(destination: localizedMapURL(url)) {
                        Label(journeyText("originalPage"), systemImage: "globe")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle").font(.title3)
                        .frame(minWidth: 44, minHeight: 44)
                }
            } else {
                journeyLink(title, url: url, systemImage: "globe")
            }
        }
    }
    private func journeyLink(_ title: String, url: URL, systemImage: String = "magnifyingglass") -> some View {
        Group {
            if isMapURL(url) {
                Button {
                    presentedMap = PlannerMapRequest(url: localizedMapURL(url), title: title)
                } label: {
                    journeyLinkLabel(title, systemImage: systemImage)
                }.buttonStyle(.plain)
            } else {
                Link(destination: translatedGuideURL(url) ?? url) {
                    journeyLinkLabel(title, systemImage: systemImage)
                }
            }
        }
    }
    private func journeyLinkLabel(_ title: String, systemImage: String) -> some View {
        let accent = PlannerTheme.linkAccent(systemImage)
        return HStack(spacing: 10) {
            Image(systemName: systemImage).font(.headline)
                .frame(width: 38, height: 38)
                .background(accent.opacity(0.16), in: Circle())
            Text(title).font(.subheadline.bold()).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption.bold()).accessibilityHidden(true)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
        .foregroundStyle(accent)
        .background(PlannerTheme.raised, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(accent.opacity(0.35), lineWidth: 1))
    }

    private var journeyHotelPicker: some View {
        journeyPanel(accent: PlannerTheme.amber) {
            Label(hotelTravelText("chooseNow"), systemImage: "bed.double.fill")
                .font(.title3.bold()).foregroundStyle(PlannerTheme.amber)
            Text(routeText(route, 0)).font(.subheadline.bold())
            Text("\(hotelTravelText("firstPlace")) · \(venueText(selectedVenue(0), 0))")
                .font(.subheadline)
            if hotelQuery.isEmpty {
                Label(hotelTravelText("notChosen"), systemImage: "info.circle")
                    .font(.subheadline).foregroundStyle(journeyGold)
            }
            if !hotelSearching {
                journeyAction(journeyText("findHotels"), systemImage: "magnifyingglass", accent: PlannerTheme.amber) { searchHotels() }
            } else {
                ProgressView(journeyText("searchingHotels"))
            }
            if hotelSearchError { Text(journeyText("hotelsUnavailable")).font(.footnote) }
            if !hotelResults.isEmpty {
                Text(hotelTravelText(hotelResults.contains(where: { $0.distance < 0 }) ? "registeredStay" : "nearestFive"))
                    .font(.caption).foregroundStyle(.secondary)
            }
            if hotelResults.contains(where: { $0.distance >= 0 }) {
                Picker(hotelTravelText("sortHotels"), selection: $hotelSortByWalking) {
                    Text(hotelTravelText("walkSort")).tag(true)
                    Text(hotelTravelText("straightDistance")).tag(false)
                }.pickerStyle(.segmented)
            }
            ForEach(sortedHotelResults) { hotel in
                VStack(alignment: .leading, spacing: 10) {
                    Text(hotel.name).font(.headline)
                    Text(hotel.address).font(.subheadline).foregroundStyle(.secondary)
                    if hotel.distance >= 0 {
                        Text(String(format: journeyText("distance"), locale: language.locale, arguments: [Int(hotel.distance.rounded())])).font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text(hotelTravelText("registeredStay")).font(.caption).foregroundStyle(.secondary)
                    }
                    if hotel.distance >= 0 {
                        if let value = hotelWalkingTimes[hotel.id] {
                            Text("\(hotelTravelText("walking")) · \(travelTimeText(value))")
                                .font(.subheadline.bold()).fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text(hotelTravelText(hotelSearching ? "checkingRoute" : "walkUnconfirmed"))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if let url = locationURL(hotel.query) { journeyLink(extra("hotelMap"), url: url, systemImage: "mappin.and.ellipse") }
                    if let url = hotel.website.flatMap(URL.init(string:)) { translatedGuideLink(extra("rate"), url: url) }
                    if let phone = hotel.phone, let url = URL(string: "tel:\(phone)") { journeyLink("\(extra("call")) · \(phone)", url: url, systemImage: "phone") }
                    let isSelected = hotelChoice == "suggested" && selectedSuggestedHotel?.id == hotel.id
                    journeyAction(isSelected ? hotelTravelText("selectedHotel") : journeyText("chooseThisHotel"), systemImage: "checkmark.circle", accent: PlannerTheme.amber) {
                        chooseSuggestedHotel(hotel)
                    }
                    if isSelected {
                        hotelTravelSummary
                            .id("selectedHotelTravel")
                            .task(id: hotelTravelKey) { await updateHotelTravelTimes() }
                    }
                }
                .padding(12)
                .background(PlannerTheme.raised, in: RoundedRectangle(cornerRadius: 10))
            }
            if hotelChoice == "suggested", let hotel = selectedSuggestedHotel, !selectedSearchedHotelVisible {
                Text(hotelTravelText("selectedHotel")).font(.caption).foregroundStyle(journeyGold)
                visibleChoice(hotel.name, selected: true) { saveHotelValue("suggested") }
                hotelTravelSummary.task(id: hotelTravelKey) { await updateHotelTravelTimes() }
                Text(hotel.address).font(.subheadline).foregroundStyle(.secondary)
                if let url = hotel.website.flatMap(URL.init(string:)) { translatedGuideLink(extra("rate"), url: url) }
                if let url = locationURL(hotel.query) { journeyLink(extra("hotelMap"), url: url, systemImage: "mappin.and.ellipse") }
                if let phone = hotel.phone, let url = URL(string: "tel:\(phone)") {
                    journeyLink("\(extra("call")) · \(phone)", url: url, systemImage: "phone")
                }
            }
            Divider()
            visibleChoice(journeyText("ownHotel"), selected: hotelChoice == "custom") { saveHotelValue("custom") }
            if hotelChoice == "custom" {
                TextField(journeyText("hotelInput"), text: Binding(get: { customHotel }, set: { saveHotelValue($0, custom: true) }))
                    .textFieldStyle(.roundedBorder)
                Text(journeyText("hotelInputNote")).font(.footnote).foregroundStyle(.secondary)
                if !hotelQuery.isEmpty {
                    hotelTravelSummary.task(id: hotelTravelKey) { await updateHotelTravelTimes() }
                }
            }
            Text(hotelTravelText("afterChoosing"))
                .font(.footnote).foregroundStyle(journeyGold)
            Text(journeyText("hotelChoiceNote")).font(.footnote).foregroundStyle(.secondary)
        }
    }
    private var selectedSearchedHotelVisible: Bool {
        guard hotelChoice == "suggested", let selected = selectedSuggestedHotel else { return false }
        return hotelResults.contains { $0.id == selected.id }
    }
    private func clearHotelSearch() {
        hotelSearchID = UUID()
        hotelResults = []
        hotelSearching = false
        hotelSearchError = false
    }
    // Towns and streets are not always indexed as a single Apple Maps POI.
    // Use their actual local center, never the prefectural capital.
    private var pinnedFirstVenueCoordinate: CLLocationCoordinate2D? {
        return pinnedVenueCoordinate(selectedVenue(0))
    }
    private func pinnedVenueCoordinate(_ venue: Venue) -> CLLocationCoordinate2D? {
        switch venue.name {
        case "Katsuoji Temple":
            // Osaka Prefecture's published site reference coordinate:
            // https://www.pref.osaka.lg.jp/o130170/kenshi_kikaku/viewspotosakaproject/4rdviewspot_minoh1.html
            return CLLocationCoordinate2D(latitude: 34.865736, longitude: 135.491608)
        case "Meiji Jingu Shrine":
            // Fixed entrance-area coordinate for reliable route calculations.
            return CLLocationCoordinate2D(latitude: 35.669868, longitude: 139.702255)
        case "Takeshita Street":
            // Fixed street reference point near the Harajuku/Takeshita entrance.
            return CLLocationCoordinate2D(latitude: 35.67125, longitude: 139.70481)
        case "Omotesando Tokyo":
            // Published street reference point at the Aoyama-dori end.
            // https://en.wikipedia.org/wiki/Omotesand%C5%8D
            return CLLocationCoordinate2D(latitude: 35.66513, longitude: 139.71248)
        case "Hachiko Square Shibuya":
            // Statue in the square, not a different Hachiko landmark in Tokyo.
            // https://en.wikipedia.org/wiki/Statue_of_Hachik%C5%8D
            return CLLocationCoordinate2D(latitude: 35.659056, longitude: 139.700583)
        case "Takachiho Shrine":
            // Kokugakuin University shrine database, WGS84 location.
            return CLLocationCoordinate2D(latitude: 32.706639, longitude: 131.302306)
        case "Motonosumi torii path":
            // Facility entrance anchor; intra-site travel is labelled separately.
            return pinnedVenueCoordinate(named: "Motonosumi Shrine")
        case "Chichibugahama Beach":
            // Beach access area, not a point offshore. Official tourist map:
            // https://www.mitoyo-kanko.com/chichibugahama/
            return CLLocationCoordinate2D(latitude: 34.189485, longitude: 133.648966)
        case "Motonosumi Shrine":
            return CLLocationCoordinate2D(latitude: 34.41965524340437, longitude: 131.06256008148193)
        case "Nio port town":
            return CLLocationCoordinate2D(latitude: 34.20401, longitude: 133.6369)
        case "Ginzan Onsen town":
            return CLLocationCoordinate2D(latitude: 38.5699, longitude: 140.5307)
        case "Kawagoe Ichibangai":
            return CLLocationCoordinate2D(latitude: 35.9235, longitude: 139.483333)
        case "Kokusai Dori Naha":
            return CLLocationCoordinate2D(latitude: 26.214756, longitude: 127.683636)
        default:
            return nil
        }
    }
    private func pinnedVenueCoordinate(named name: String) -> CLLocationCoordinate2D? {
        guard let venue = route.stops.flatMap({ $0.choices }).first(where: { $0.name == name }) else { return nil }
        return pinnedVenueCoordinate(venue)
    }
    private func localVenueName(_ venue: Venue) -> String {
        FeaturedRoutes.names[venue.name]?[0] ?? NationwideRoutes.japanesePlaces[venue.name]
            ?? GuideTranslations.venues[venue.name]?[0][0] ?? venue.name
    }
    private func normalizedPlaceName(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .widthInsensitive], locale: Locale(identifier: "ja_JP"))
            .components(separatedBy: .whitespacesAndNewlines).joined()
            .replacingOccurrences(of: "ヶ", with: "ケ")
            .replacingOccurrences(of: "嶋", with: "島")
            .replacingOccurrences(of: "東横イン", with: "東横inn")
            .replacingOccurrences(of: "・", with: "")
            .replacingOccurrences(of: "-", with: "")
    }
    private func parentSiteName(_ venue: Venue) -> String? {
        ["Motonosumi torii path": "Motonosumi Shrine",
         "Ginzan River bridges": "Ginzan Onsen town",
         "Olive Park Greek windmill": "Shodoshima Olive Park",
         "Olive Park olive groves": "Shodoshima Olive Park"][venue.name]
    }
    private func venueMapItem(_ venue: Venue, in prefecture: PrefectureOption) async throws -> MKMapItem? {
        let cacheKey = "\(prefecture.id)|\(venue.name)"
        if let cached = cachedRoutePlace(cacheKey) { return cached }
        if let coordinate = pinnedVenueCoordinate(venue) {
            let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
            item.name = localVenueName(venue)
            rememberRoutePlace(item, key: cacheKey)
            return item
        }
        if let parent = parentSiteName(venue),
           let parentVenue = route.stops.flatMap({ $0.choices }).first(where: { $0.name == parent }) {
            return try await venueMapItem(parentVenue, in: prefecture)
        }
        let expected = localVenueName(venue)
        let aliases = ["仁尾の港町": "仁尾町", "銀山温泉街": "銀山温泉",
                       "本町通り（富士みち）": "下吉田本町通り",
                       "嵯峨鳥居本町並み保存地区": "嵯峨鳥居本",
                       "箕面駅前商店街": "箕面駅", "箕面滝道入口": "箕面公園",
                       "高千穂峡の遊歩道": "高千穂峡", "真名井の滝の展望場所": "真名井の滝",
                       "龍宮の潮吹の展望場所": "龍宮の潮吹", "白銀公園入口": "白銀公園"]
        // Display labels are not necessarily names indexed by the map provider.
        // Search known local aliases, the original name and bundled map query.
        let mapAliases: [String: [String]] = [
            "ハチ公前広場": ["忠犬ハチ公像", "ハチ公像", "ハチ公広場", "Hachiko Statue"],
            "表参道": ["表参道通り", "Omotesando"],
            "渋谷スクランブル交差点": ["渋谷駅前交差点", "Shibuya Scramble Crossing"],
            "道頓堀": ["Dotonbori"],
            "祇園の路地": ["祇園", "Gion"],
            "嵯峨鳥居本町並み保存地区": ["嵯峨鳥居本伝統的建造物群保存地区"]
        ]
        var names = [expected]
        if let alias = aliases[expected] { names.append(alias) }
        names += mapAliases[expected] ?? []
        names.append(venue.name)
        if let components = URLComponents(string: venue.url),
           components.host?.contains("google.") == true,
           let query = components.queryItems?.first(where: { $0.name == "query" })?.value {
            let local = query.replacingOccurrences(of: prefecture.ja, with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !local.isEmpty { names.append(local) }
        }
        var seen = Set<String>()
        names = names.filter { seen.insert(normalizedPlaceName($0)).inserted }
        let requests = names.map { "\($0), \(prefecture.ja), Japan" }
        let needles = names.map(normalizedPlaceName)
        func matchesName(_ value: String) -> Bool {
            let label = normalizedPlaceName(value)
            return needles.contains { needle in
                label == needle || label.hasPrefix(needle + "(") || label.hasPrefix(needle + "（")
                    || label.hasPrefix(needle + "入口")
                    || (needle.count >= 4 && label.contains(needle) && !needle.hasSuffix("駅"))
            }
        }
        for query in requests {
            guard !Task.isCancelled else { return nil }
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            request.resultTypes = [.address, .pointOfInterest]
            if let response = try? await MKLocalSearch(request: request).start() {
                let candidates = response.mapItems.filter { item in
                    let point = item.placemark.coordinate
                    guard CLLocationCoordinate2DIsValid(point), point.latitude != 0,
                          item.placemark.isoCountryCode == nil || item.placemark.isoCountryCode == "JP" else { return false }
                    return hotelPlace(item, isIn: prefecture) && matchesName(item.name ?? "")
                }
                let exact = candidates.first { needles.contains(normalizedPlaceName($0.name ?? "")) }
                if let item = exact ?? candidates.first {
                    rememberRoutePlace(item, key: cacheKey)
                    return item
                }
            }
        }
        // Street and trail names may be absent from the POI index. Try their
        // published address/name as an address, still retaining the prefecture.
        for name in names {
            guard !Task.isCancelled else { return nil }
            if let marks = try? await CLGeocoder().geocodeAddressString("\(prefecture.ja) \(name)", in: nil, preferredLocale: Locale(identifier: "ja_JP")),
               let mark = marks.first(where: { mark in
                   guard let point = mark.location?.coordinate, CLLocationCoordinate2DIsValid(point) else { return false }
                   let item = MKMapItem(placemark: MKPlacemark(placemark: mark))
                   return hotelPlace(item, isIn: prefecture) && matchesName(mark.name ?? "")
               }) {
                let item = MKMapItem(placemark: MKPlacemark(placemark: mark))
                rememberRoutePlace(item, key: cacheKey)
                return item
            }
        }
        let publishedAddresses = [
            // GO TOKYO official listing: https://www.gotokyo.org/jp/spot/86/index.html
            "Hachiko Square Shibuya": "東京都渋谷区道玄坂2-1"
        ]
        if let address = publishedAddresses[venue.name], !Task.isCancelled,
           let marks = try? await CLGeocoder().geocodeAddressString(address, in: nil,
                                      preferredLocale: Locale(identifier: "ja_JP")),
           let mark = marks.first(where: { mark in
               guard let point = mark.location?.coordinate,
                     CLLocationCoordinate2DIsValid(point) else { return false }
               return hotelPlace(MKMapItem(placemark: MKPlacemark(placemark: mark)), isIn: prefecture)
           }) {
            let item = MKMapItem(placemark: MKPlacemark(placemark: mark))
            item.name = expected
            rememberRoutePlace(item, key: cacheKey)
            return item
        }
        return nil
    }
    private func firstVenueMapItem(in prefecture: PrefectureOption) async throws -> MKMapItem? {
        try await venueMapItem(selectedVenue(0), in: prefecture)
    }
    // Confirmed local stays keep area-based courses useful even when Apple Maps
    // omits small inns or classifies them outside the hotel category.
    private func verifiedFallbackHotel(near coordinate: CLLocationCoordinate2D) -> HotelSuggestion? {
        let stay: (String, String, Double, Double, String?, String)?
        switch selectedVenue(0).name {
        case "Takachiho Shrine":
            stay = ("ホテル高千穂", "宮崎県西臼杵郡高千穂町三田井1037-4",
                    32.705174, 131.299699, "0982723255", "https://h-takachiho.com/")
        case "Nio port town":
            stay = ("夕波の宿 渡海屋", "香川県三豊市仁尾町仁尾丁1446-20",
                    34.2053766, 133.63872, "09095538436", "https://www.fujita-suisan.co.jp/stay/")
        case "Ginzan Onsen town":
            stay = ("能登屋旅館", "山形県尾花沢市大字銀山新畑446",
                    38.56939, 140.531525, "0237282327", "https://www.ginzanonsen.jp/yado/notoya.html")
        case "Motonosumi Shrine":
            stay = ("kitohana_YUYA", "山口県長門市油谷角山138-2",
                    34.3831932, 131.0371874, nil, "https://kitohana.jp/")
        case "Kawagoe Ichibangai":
            stay = ("松村屋旅館", "埼玉県川越市元町1-1-11",
                    35.924428, 139.485153, "0492220107", "https://coedomatsumuraya.com/")
        case "Kokusai Dori Naha":
            stay = ("ホテルパームロイヤルリゾート国際通り", "沖縄県那覇市牧志3-9-10",
                    26.216499, 127.6898927, nil, "https://palmroyal.co.jp/")
        default:
            stay = nil
        }
        guard let stay else { return nil }
        let distance = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            .distance(from: CLLocation(latitude: stay.2, longitude: stay.3))
        guard distance < 12_000 else { return nil }
        return HotelSuggestion(id: "verified|\(selectedVenue(0).name)", name: stay.0, address: stay.1,
                               latitude: stay.2, longitude: stay.3, phone: stay.4, website: stay.5,
                               distance: distance, anchorLatitude: coordinate.latitude,
                               anchorLongitude: coordinate.longitude)
    }
    private func cachedRoutePlace(_ key: String) -> MKMapItem? {
        if let item = resolvedPlaceCache[key] { return item }
        guard let data = UserDefaults.standard.array(forKey: "japanDay.routePlace.v2." + key) as? [Double],
              data.count == 3, Date().timeIntervalSince1970 - data[2] < 30 * 86400 else { return nil }
        let point = CLLocationCoordinate2D(latitude: data[0], longitude: data[1])
        guard CLLocationCoordinate2DIsValid(point), point.latitude != 0 else { return nil }
        return MKMapItem(placemark: MKPlacemark(coordinate: point))
    }
    private func rememberRoutePlace(_ item: MKMapItem, key: String) {
        let point = item.placemark.coordinate
        guard CLLocationCoordinate2DIsValid(point), point.latitude != 0 else { return }
        resolvedPlaceCache[key] = item
        UserDefaults.standard.set([point.latitude, point.longitude, Date().timeIntervalSince1970],
                                  forKey: "japanDay.routePlace.v2." + key)
    }
    private func publishedHotelPoint(_ query: String) -> CLLocationCoordinate2D? {
        // Exact hotel identity only: also handles saved registered selections
        // from older versions, whose latitude/longitude were both zero.
        // Osaka Convention & Tourism Bureau's embedded map, checked 2026-10-09:
        // https://osaka-info.jp/spot/toyokoinn_osakataniyonkosaten/
        let name = query.components(separatedBy: ",").first ?? query
        guard normalizedPlaceName(name) == normalizedPlaceName("東横INN大阪谷四交差点") else { return nil }
        return CLLocationCoordinate2D(latitude: 34.68117496022067, longitude: 135.51699508265992)
    }
    private func resolvedAnchorMapItem(_ query: String) async throws -> MKMapItem? {
        if let point = publishedHotelPoint(query) {
            return MKMapItem(placemark: MKPlacemark(coordinate: point))
        }
        let parts = query.split(separator: ",")
        if parts.count == 2, let latitude = Double(parts[0]), let longitude = Double(parts[1]),
           (-90...90).contains(latitude), (-180...180).contains(longitude) {
            return MKMapItem(placemark: MKPlacemark(coordinate:
                CLLocationCoordinate2D(latitude: latitude, longitude: longitude)))
        }
        if let cached = cachedRoutePlace(query) { return cached }
        if hotelChoice == "suggested", query == hotelQuery, let hotel = selectedSuggestedHotel, hotel.lookupQuery == nil {
            return MKMapItem(placemark: MKPlacemark(coordinate:
                CLLocationCoordinate2D(latitude: hotel.latitude, longitude: hotel.longitude)))
        }
        if let place = lunchSelection, query == place.query {
            return MKMapItem(placemark: MKPlacemark(coordinate:
                CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)))
        }
        if let place = dinnerSelection, query == place.query {
            return MKMapItem(placemark: MKPlacemark(coordinate:
                CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)))
        }
        if let venue = route.stops.flatMap({ $0.choices }).first(where: { venueQuery($0) == query }),
           let prefecture = NationwideRoutes.prefectures.first(where: { $0.id == routePrefecture }) {
            return try await venueMapItem(venue, in: prefecture)
        }
        // Arrival airports/stations may legitimately be outside the course prefecture.
        if query != hotelQuery || hotelChoice == "custom" {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            // Address results are valid endpoints too, not just indexed businesses.
            request.resultTypes = [.address, .pointOfInterest]
            for _ in 0..<2 {
                guard !Task.isCancelled else { return nil }
                if let response = try? await MKLocalSearch(request: request).start(),
                   let item = response.mapItems.first(where: {
                       $0.placemark.isoCountryCode == "JP" && CLLocationCoordinate2DIsValid($0.placemark.coordinate)
                   }) { rememberRoutePlace(item, key: query); return item }
                try? await Task.sleep(nanoseconds: 600_000_000)
            }
            if let marks = try? await CLGeocoder().geocodeAddressString(query, in: nil, preferredLocale: Locale(identifier: "ja_JP")),
               let mark = marks.first(where: { $0.isoCountryCode == "JP" && $0.location != nil }) {
                let item = MKMapItem(placemark: MKPlacemark(placemark: mark))
                rememberRoutePlace(item, key: query)
                return item
            }
            return nil
        }
        let prefecture = NationwideRoutes.prefectures.first(where: { $0.id == routePrefecture })
        let expectedName = query.components(separatedBy: ",").first ?? query
        let needle = normalizedPlaceName(expectedName)
        let localQuery = query.replacingOccurrences(of: ", Japan", with: "")
        let alternatives = [localQuery,
                            localQuery.replacingOccurrences(of: "東横INN", with: "東横イン"),
                            query]
        var seen = Set<String>()
        for candidate in alternatives where seen.insert(candidate).inserted {
            guard !Task.isCancelled else { return nil }
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = candidate
            request.resultTypes = [.address, .pointOfInterest]
            if let response = try? await MKLocalSearch(request: request).start(),
               let item = response.mapItems.first(where: { item in
                   guard CLLocationCoordinate2DIsValid(item.placemark.coordinate),
                         item.placemark.coordinate.latitude != 0,
                         item.placemark.isoCountryCode == nil || item.placemark.isoCountryCode == "JP",
                         prefecture.map({ hotelPlace(item, isIn: $0) }) ?? false else { return false }
                   let label = normalizedPlaceName(item.name ?? "")
                   return label == needle || (needle.count >= 4 && label.contains(needle))
               }) {
                rememberRoutePlace(item, key: query)
                return item
            }
            try? await Task.sleep(nanoseconds: 350_000_000)
        }
        // A published street address can resolve when a hotel's business name
        // is missing from the POI index. Never substitute a prefectural centre.
        var addresses: [String] = []
        if let hotel = chosenHotel, query == hotelQuery { addresses.append(hotel.addressJP) }
        if hotelChoice == "suggested", query == hotelQuery, let hotel = selectedSuggestedHotel,
           hotel.address.rangeOfCharacter(from: .decimalDigits) != nil { addresses.append(hotel.address) }
        for candidate in addresses + [localQuery] {
            guard !Task.isCancelled else { return nil }
            if let marks = try? await CLGeocoder().geocodeAddressString(candidate, in: nil, preferredLocale: Locale(identifier: "ja_JP")),
               let mark = marks.first(where: { mark in
                   guard let point = mark.location?.coordinate, CLLocationCoordinate2DIsValid(point), point.latitude != 0 else { return false }
                   let item = MKMapItem(placemark: MKPlacemark(placemark: mark))
                   guard prefecture.map({ hotelPlace(item, isIn: $0) }) ?? false else { return false }
                   // Address matches require street-level resolution, not a city centroid.
                   if addresses.contains(candidate) { return mark.thoroughfare != nil && mark.subThoroughfare != nil }
                   return normalizedPlaceName(mark.name ?? "").contains(needle)
               }) {
                let item = MKMapItem(placemark: MKPlacemark(placemark: mark))
                rememberRoutePlace(item, key: query)
                return item
            }
        }
        return nil
    }
    private func registeredHotels() -> [HotelSuggestion] {
        guard let prefecture = NationwideRoutes.prefectures.first(where: { $0.id == routePrefecture }) else { return [] }
        var hotels = availableHotels.map { hotel in
            HotelSuggestion(id: "registered|\(route.id)|\(selectedVenue(0).name)|\(hotel.id)", name: hotel.names[0],
                address: hotel.addressJP, latitude: 0, longitude: 0, phone: hotel.phone,
                website: hotel.officialURL, distance: -1, anchorLatitude: nil, anchorLongitude: nil,
                lookupQuery: "\(hotel.names[0]), \(hotel.addressJP), Japan")
        }
        if hotels.isEmpty, let name = RegisteredStays.names[prefecture.id] {
            hotels.append(HotelSuggestion(id: "registered|\(route.id)|\(selectedVenue(0).name)|\(prefecture.id)", name: name,
                address: prefecture.ja, latitude: 0, longitude: 0, phone: nil,
                website: "https://www.toyoko-inn.com/eng/hotel_list/", distance: -1,
                anchorLatitude: nil, anchorLongitude: nil, lookupQuery: "\(name), \(prefecture.ja), Japan"))
        }
        return hotels
    }
    @MainActor
    private func searchHotels() {
        guard !hotelSearching else { return }
        guard let prefecture = NationwideRoutes.prefectures.first(where: { $0.id == routePrefecture }) else {
            hotelSearchError = true
            return
        }
        let token = UUID()
        hotelSearchID = token
        hotelSearching = true
        hotelSearchError = false
        // Publish real registered stays before any network lookup. Keep them
        // on every error path instead of clearing the screen.
        hotelWalkingTimes = [:]
        hotelResults = registeredHotels()
        Task { @MainActor in
            do {
                let first = try await firstVenueMapItem(in: prefecture)
                guard hotelSearchID == token else { return }
                guard let first else {
                    hotelSearching = false; hotelSearchError = hotelResults.isEmpty; return
                }
                let coordinate = first.placemark.coordinate
                let center = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                var seen = Set<String>()
                var suggestions: [HotelSuggestion] = []
                if let fallback = verifiedFallbackHotel(near: coordinate) {
                    suggestions.append(fallback)
                    seen.insert(fallback.name.folding(options: [.caseInsensitive, .widthInsensitive], locale: .current))
                    hotelResults = [fallback]
                    if selectedVenue(0).name == "Takachiho Shrine" {
                        suggestions.append(HotelSuggestion(id: "verified|solest-takachiho", name: "ソレスト高千穂ホテル",
                            address: "宮崎県西臼杵郡高千穂町三田井1261-1", latitude: 32.7078023, longitude: 131.3048979,
                            phone: "0982830001", website: "https://www.solest-takachiho.jp/",
                            distance: center.distance(from: CLLocation(latitude: 32.7078023, longitude: 131.3048979)),
                            anchorLatitude: coordinate.latitude, anchorLongitude: coordinate.longitude))
                        hotelResults = suggestions
                    }
                }
                // Search multiple lodging categories before expanding. Do not stop at three results.
                for radius in [2000.0, 5000.0, 10000.0, 25000.0, 50000.0] {
                    let poi = MKLocalPointsOfInterestRequest(center: coordinate, radius: radius)
                    poi.pointOfInterestFilter = MKPointOfInterestFilter(including: [.hotel])
                    var nearbyItems: [MKMapItem] = []
                    do {
                        nearbyItems += try await MKLocalSearch(request: poi).start().mapItems
                        guard hotelSearchID == token else { return }
                    } catch {
                        guard hotelSearchID == token else { return }
                    }
                    for term in ["ホテル", "旅館", "民宿", "ゲストハウス", "宿坊", "山荘", "ペンション"] {
                        try? await Task.sleep(nanoseconds: 250_000_000)
                        guard hotelSearchID == token, !Task.isCancelled else { return }
                        let request = MKLocalSearch.Request()
                        request.naturalLanguageQuery = term
                        request.resultTypes = [.address, .pointOfInterest]
                        request.region = MKCoordinateRegion(center: coordinate,
                                                            latitudinalMeters: radius * 2,
                                                            longitudinalMeters: radius * 2)
                        do {
                            nearbyItems += try await MKLocalSearch(request: request).start().mapItems
                            guard hotelSearchID == token else { return }
                        } catch {
                            guard hotelSearchID == token else { return }
                        }
                    }
                    for item in nearbyItems {
                        let point = item.placemark.coordinate
                        let distance = center.distance(from: CLLocation(latitude: point.latitude, longitude: point.longitude))
                        // A nearby hotel across a prefectural border is still nearby.
                        // Distance from the verified landmark is the deciding filter.
                        guard CLLocationCoordinate2DIsValid(point), distance.isFinite, distance <= radius, item.placemark.isoCountryCode == nil || item.placemark.isoCountryCode == "JP",
                              let name = item.name, !name.isEmpty else { continue }
                        let lodgingName = name.lowercased()
                        guard item.pointOfInterestCategory == .hotel || ["ホテル", "旅館", "民宿", "ペンション", "ゲストハウス", "宿坊", "山荘", "ロッジ", "ホテル", "hotel", " inn", "ryokan", "lodge", "guesthouse", "resort"]
                            .contains(where: { lodgingName.contains($0) }) else { continue }
                        let normalizedName = name.folding(options: [.caseInsensitive, .widthInsensitive], locale: .current)
                        let id = "\(normalizedName)|\(Int(point.latitude * 10000))|\(Int(point.longitude * 10000))"
                        guard !suggestions.contains(where: { existing in
                            let sameName = normalizedPlaceName(existing.name) == normalizedPlaceName(name)
                            let nearby = CLLocation(latitude: existing.latitude, longitude: existing.longitude)
                                .distance(from: CLLocation(latitude: point.latitude, longitude: point.longitude)) < 150
                            return sameName && nearby
                        }) else { continue }
                        guard seen.insert(id).inserted else { continue }
                        suggestions.append(HotelSuggestion(id: id, name: name, address: item.placemark.title ?? name,
                                                           latitude: point.latitude, longitude: point.longitude,
                                                           phone: item.phoneNumber, website: item.url?.absoluteString,
                                                           distance: distance, anchorLatitude: coordinate.latitude,
                                                           anchorLongitude: coordinate.longitude))
                    }
                    if suggestions.count >= 8 { break }
                }
                if !suggestions.isEmpty {
                    hotelResults = Array(suggestions.sorted { $0.distance < $1.distance }.prefix(8))
                    // Keep every candidate visible even if its walking route is unavailable.
                    let candidates = hotelResults
                    for hotel in candidates {
                        guard hotelSearchID == token, !Task.isCancelled else { return }
                        let origin = MKMapItem(placemark: MKPlacemark(coordinate:
                            CLLocationCoordinate2D(latitude: hotel.latitude, longitude: hotel.longitude)))
                        let value = await RouteMeasurements.fetch(from: origin, to: first, by: .walking)
                        guard hotelSearchID == token, !Task.isCancelled else { return }
                        if let value { hotelWalkingTimes[hotel.id] = value }
                        try? await Task.sleep(nanoseconds: 400_000_000)
                    }
                }
                hotelSearching = false
                hotelSearchError = hotelResults.isEmpty
            } catch {
                guard hotelSearchID == token else { return }
                hotelSearching = false
                hotelSearchError = hotelResults.isEmpty
            }
        }
    }
    private func hotelPlace(_ item: MKMapItem, isIn prefecture: PrefectureOption) -> Bool {
        let area = (item.placemark.administrativeArea ?? item.placemark.title ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let japaneseName = prefecture.ja.replacingOccurrences(of: "都", with: "")
            .replacingOccurrences(of: "道", with: "")
            .replacingOccurrences(of: "府", with: "")
            .replacingOccurrences(of: "県", with: "")
        let title = item.placemark.title ?? ""
        return title.contains(prefecture.ja) || area.localizedCaseInsensitiveContains(prefecture.en)
            || area.contains(prefecture.ja)
            || area == japaneseName
    }
    private func hotelTravelText(_ key: String) -> String {
        HotelTravelTranslations.ui[key]?[language.index] ?? key
    }
    private func travelDurationText(_ minutes: Int) -> String {
        guard minutes >= 60 else {
            return String(format: hotelTravelText("minutes"), locale: language.locale, arguments: [minutes])
        }
        let hours = minutes / 60
        let remainder = minutes % 60
        if remainder == 0 {
            return String(format: hotelTravelText("hours"), locale: language.locale, arguments: [hours])
        }
        return String(format: hotelTravelText("hoursAndMinutes"), locale: language.locale,
                      arguments: [hours, remainder])
    }
    private func travelTimeText(_ time: TravelTime) -> String {
        let duration = travelDurationText(time.minutes)
        let label = hotelTravelText(time.isApproximate ? "approximate" : "routeEstimate")
        let metres = time.routeMetres ?? time.straightMetres
        let distance = metres.map { String(format: "%.1f km", locale: language.locale, $0 / 1000) }
        let basis = time.routeMetres == nil ? hotelTravelText("straightDistance") : hotelTravelText("routeDistance")
        return "\(label) · \(duration)" + (distance.map { " · \(basis) \($0)" } ?? "")
    }
    private func travelFailureText(mode: String, missingPlace: Bool) -> String {
        hotelTravelText(missingPlace ? "placeUnavailable" : mode == "transit" ? "transitUnavailable" : "unavailable")
    }
    private var hotelTravelSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(extra("toFirst")) · \(venueText(selectedVenue(0), 0))")
                .font(.subheadline.bold()).foregroundStyle(journeyGold)
            if hotelTravelLoading { ProgressView(hotelTravelText("calculating")) }
            ForEach(["transit", "walking", "taxi"], id: \.self) { mode in
                HStack {
                    Text(hotelTravelText(mode))
                    Spacer(minLength: 8)
                    if let minutes = hotelTravelMinutes[mode] {
                        Text(travelTimeText(minutes))
                            .fontWeight(.bold).monospacedDigit()
                    } else if !hotelTravelLoading {
                        Text(travelFailureText(mode: mode, missingPlace: hotelTravelMinutes.isEmpty)).foregroundStyle(.secondary)
                    }
                }.font(.subheadline)
            }
            Text(hotelTravelText("estimateNote"))
                .font(.caption).foregroundStyle(.secondary)
            if !hotelTravelLoading, hotelTravelMinutes.count < 3 || hotelTravelMinutes.values.contains(where: { $0.isApproximate }) {
                Button(hotelTravelText("retry")) {
                    Task { await updateHotelTravelTimes() }
                }.font(.caption.bold()).foregroundStyle(PlannerTheme.cyan)
            }
        }
        .padding(12)
        .background(PlannerTheme.raised, in: RoundedRectangle(cornerRadius: 12))
    }
    @MainActor
    private func updateHotelTravelTimes() async {
        let requestKey = hotelTravelKey
        hotelTravelMinutes = [:]
        hotelTravelLoading = true
        defer { if requestKey == hotelTravelKey { hotelTravelLoading = false } }
        do {
            // Pause while a manually entered hotel name is still being typed.
            try await Task.sleep(nanoseconds: 500_000_000)
            guard let origin = try await resolvedAnchorMapItem(hotelQuery) else {
                if !Task.isCancelled && requestKey == hotelTravelKey { hotelTravelLoading = false }
                return
            }
            guard let prefecture = NationwideRoutes.prefectures.first(where: { $0.id == routePrefecture }),
                  let destination = try await firstVenueMapItem(in: prefecture) else {
                if !Task.isCancelled && requestKey == hotelTravelKey { hotelTravelLoading = false }
                return
            }
            guard !Task.isCancelled && requestKey == hotelTravelKey else { return }
            hotelTravelMinutes = planningTimes(from: origin, to: destination)
            // Avoid a three-request burst and show walking/driving before
            // waiting for a rural transit lookup to finish.
            if let w = await travelMinutes(from: origin, to: destination, by: .walking) {
                guard !Task.isCancelled, requestKey == hotelTravelKey else { return }
                hotelTravelMinutes["walking"] = w
            }
            if let a = await travelMinutes(from: origin, to: destination, by: .automobile) {
                guard !Task.isCancelled, requestKey == hotelTravelKey else { return }
                hotelTravelMinutes["taxi"] = a
            }
            if let t = await travelMinutes(from: origin, to: destination, by: .transit) {
                guard !Task.isCancelled, requestKey == hotelTravelKey else { return }
                hotelTravelMinutes["transit"] = t
            }
            guard !Task.isCancelled, requestKey == hotelTravelKey else { return }
            hotelTravelLoading = false
        } catch {
            if !Task.isCancelled && requestKey == hotelTravelKey { hotelTravelLoading = false }
        }
    }
    private func planningTimes(from origin: MKMapItem, to destination: MKMapItem) -> [String: TravelTime] {
        var result: [String: TravelTime] = [:]
        result["walking"] = TravelTime.rough(from: origin.placemark.coordinate, to: destination.placemark.coordinate, by: .walking)
        result["taxi"] = TravelTime.rough(from: origin.placemark.coordinate, to: destination.placemark.coordinate, by: .automobile)
        return result
    }
    private func travelMinutes(from origin: MKMapItem, to destination: MKMapItem,
                               by transport: MKDirectionsTransportType) async -> TravelTime? {
        if let measured = await RouteMeasurements.fetch(from: origin, to: destination, by: transport) { return measured }
        guard !Task.isCancelled else { return nil }
        return TravelTime.rough(from: origin.placemark.coordinate, to: destination.placemark.coordinate, by: transport)
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
                            .foregroundStyle(Color.black)
                            .background(PlannerTheme.accent(index % 5), in: Circle())
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
        journeyPanel(accent: PlannerTheme.coral) {
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
        return journeyPanel(accent: PlannerTheme.coral) {
            Label(journeyText("lunchSearch"), systemImage: "fork.knife").font(.title3.bold())
            Text("\(venueText(previous, 0)) · \(journeyText("nearby"))")
                .font(.subheadline).foregroundStyle(.secondary)
            Text(journeyText("lunchNote")).font(.subheadline)
            journeyAction(journeyText("findLunch"), systemImage: "magnifyingglass", accent: PlannerTheme.coral) { searchLunch(near: anchor) }
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
                    journeyAction(journeyText(lunchSelection?.id == place.id ? "selectedLunch" : "selectLunch"), systemImage: "checkmark.circle", accent: PlannerTheme.coral) {
                        lunchSelection = place
                    }
                }
                .padding(12)
                .background(PlannerTheme.raised, in: RoundedRectangle(cornerRadius: 12))
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
                let first = try await resolvedAnchorMapItem(anchor)
                guard lunchSearchID == token else { return }
                guard let first else {
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
        journeyPanel(accent: PlannerTheme.coral) {
            Label(journeyText(dinnerNearHotel ? "dinnerHotel" : "dinnerLast"), systemImage: "fork.knife").font(.title3.bold())
            Text(dinnerAnchorName).font(.subheadline.bold())
            Text(journeyText(dinnerNearHotel ? "earlyNote" : "lateNote")).font(.subheadline)
            if dinnerAnchorQuery.isEmpty {
                Text(journeyText("enterHotel")).foregroundStyle(journeyGold)
            } else {
                journeyAction(journeyText("findDinner"), systemImage: "magnifyingglass", accent: PlannerTheme.coral) { searchDinner() }
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
                    journeyAction(journeyText(dinnerSelection?.id == place.id ? "selectedDinner" : "selectDinner"), systemImage: dinnerSelection?.id == place.id ? "checkmark.circle.fill" : "fork.knife", accent: PlannerTheme.coral) {
                        dinnerSelection = place
                    }
                }
                .padding(14)
                .background(PlannerTheme.raised, in: RoundedRectangle(cornerRadius: 12))
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
                let centerItem = try await resolvedAnchorMapItem(anchor)
                guard dinnerSearchID == token else { return }
                guard let centerItem else {
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
        // Use fixed coordinates for known streets, squares and major sites.
        // This avoids a transient MapKit name-search failure hiding route times.
        if let point = pinnedVenueCoordinate(venue) {
            return "\(point.latitude),\(point.longitude)"
        }
        // Japanese names avoid ambiguous translated or romanized businesses.
        let localName = FeaturedRoutes.names[venue.name]?[0] ?? NationwideRoutes.japanesePlaces[venue.name] ?? GuideTranslations.venues[venue.name]?[0][0] ?? venue.name
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
        let key = routeLegKey(origin: origin, destination: destination)
        let internalWalk = isInternalSiteTransfer(origin: origin, destination: destination)
        return VStack(alignment: .leading, spacing: 10) {
            if !internalWalk, let url = mapURL(origin: origin, destination: destination, mode: "transit") {
                timedRouteLink(extra("transitRoute"), url: url, systemImage: "tram.fill", key: key, mode: "transit", canEstimate: origin?.isEmpty == false)
            }
            if let url = mapURL(origin: origin, destination: destination, mode: "walking") {
                timedRouteLink(extra("walkRoute"), url: url, systemImage: "figure.walk", key: key, mode: "walking", canEstimate: origin?.isEmpty == false)
            }
            if internalWalk { Text(hotelTravelText("siteWalk")).font(.caption).foregroundStyle(PlannerTheme.amber) }
            if !internalWalk, let url = mapURL(origin: origin, destination: destination, mode: "driving") {
                timedRouteLink(extra("driveRoute"), url: url, systemImage: "car.fill", key: key, mode: "taxi", canEstimate: origin?.isEmpty == false)
            }
            Text(hotelTravelText("estimateNote")).font(.caption).foregroundStyle(.secondary)
            if let omotesando = route.stops.flatMap({ $0.choices }).first(where: { $0.name == "Omotesando Tokyo" }),
               origin == venueQuery(omotesando) || destination == venueQuery(omotesando) {
                Text(["表参道は青山通り側の地点を基準に計算しています。",
                      "오모테산도는 아오야마 거리 쪽 지점을 기준으로 계산합니다.",
                      "表参道以青山通路口一侧为计算基准。",
                      "Omotesando times use the Aoyama-dori end of the street.",
                      "เวลาของโอโมเตะซันโดคำนวณจากฝั่งถนนอาโอยามะ"][language.index])
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let origin, !origin.isEmpty, !routeLegLoading.contains(key), let times = routeLegTimes[key],
               times.count < 3 || times.values.contains(where: { $0.isApproximate }) {
                Button(hotelTravelText("retry")) {
                    routeLegTimes[key] = nil
                    Task { await updateRouteLegTimes(origin: origin, destination: destination, key: key) }
                }.font(.caption.bold()).foregroundStyle(PlannerTheme.cyan)
            }
        }
        .task(id: key) {
            guard let origin, !origin.isEmpty else { return }
            await updateRouteLegTimes(origin: origin, destination: destination, key: key)
        }
    }
    private func isInternalSiteTransfer(origin: String?, destination: String) -> Bool {
        guard let origin else { return false }
        let names = ["Motonosumi Shrine", "Motonosumi torii path"]
        let queries = route.stops.flatMap({ $0.choices }).filter { names.contains($0.name) }.map(venueQuery)
        return origin != destination && queries.contains(origin) && queries.contains(destination)
    }
    private func routeLegKey(origin: String?, destination: String) -> String {
        "\(route.id)|\(origin ?? "")|\(destination)"
    }
    private func timedRouteLink(_ title: String, url: URL, systemImage: String, key: String, mode: String, canEstimate: Bool) -> some View {
        let accent = mode == "walking" ? PlannerTheme.coral : mode == "taxi" ? PlannerTheme.amber : PlannerTheme.cyan
        return Button {
            presentedMap = PlannerMapRequest(url: localizedMapURL(url), title: title)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: systemImage).font(.headline)
                    .frame(width: 36, height: 36)
                    .background(accent.opacity(0.15), in: Circle())
                Text(title).frame(maxWidth: .infinity, alignment: .leading)
                if let minutes = routeLegTimes[key]?[mode] {
                    Text(travelTimeText(minutes))
                        .monospacedDigit().fixedSize(horizontal: false, vertical: true).multilineTextAlignment(.trailing)
                } else if routeLegLoading.contains(key) {
                    ProgressView().tint(accent)
                } else if routeLegTimes[key] != nil {
                    Text(travelFailureText(mode: mode, missingPlace: routeLegTimes[key]?.isEmpty == true)).font(.caption).multilineTextAlignment(.trailing)
                } else if canEstimate {
                    ProgressView().tint(accent)
                }
            }
            .font(.subheadline.bold()).fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .foregroundStyle(accent)
            .background(PlannerTheme.raised, in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(accent.opacity(0.35), lineWidth: 1))
        }.buttonStyle(.plain)
    }
    @MainActor
    private func updateRouteLegTimes(origin: String, destination: String, key: String) async {
        guard routeLegTimes[key]?.isEmpty != false, !routeLegLoading.contains(key) else { return }
        if isInternalSiteTransfer(origin: origin, destination: destination) {
            routeLegTimes[key] = ["walking": TravelTime(minutes: 5, isApproximate: true)]
            return
        }
        routeLegLoading.insert(key)
        defer {
            routeLegLoading.remove(key)
            if Task.isCancelled, routeLegTimes[key]?.isEmpty != false { routeLegTimes[key] = nil }
        }
        do {
            let start = try await resolvedAnchorMapItem(origin)
            let end = try await resolvedAnchorMapItem(destination)
            guard !Task.isCancelled else { return }
            guard let start, let end else {
                routeLegTimes[key] = [:]
                return
            }
            routeLegTimes[key] = planningTimes(from: start, to: end)
            for (mode, transport) in [("walking", MKDirectionsTransportType.walking),
                                      ("taxi", MKDirectionsTransportType.automobile),
                                      ("transit", MKDirectionsTransportType.transit)] {
                let time = await travelMinutes(from: start, to: end, by: transport)
                guard !Task.isCancelled else { return }
                if let time { routeLegTimes[key]?[mode] = time }
            }
        } catch {
            if !Task.isCancelled { routeLegTimes[key] = [:] }
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
        .background(PlannerTheme.surface, in: RoundedRectangle(cornerRadius: 16))
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
                journeyLink(extra("hotelMap"), url: url, systemImage: "mappin.and.ellipse")
            }
            if let url = URL(string: hotel.rateURL) {
                Link(destination: translatedGuideURL(url) ?? url) { Label(extra("rate"), systemImage: "yensign.circle.fill") }
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
                Link(destination: translatedGuideURL(url) ?? url) { Label(extra("contact"), systemImage: "globe") }
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
        .background(PlannerTheme.surface, in: RoundedRectangle(cornerRadius: 16))
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
            if isInternalSiteTransfer(origin: venueQuery(from), destination: venueQuery(to)) {
                Text(hotelTravelText("siteWalk")).font(.subheadline)
            } else if let info = FeaturedRoutes.info[route.id] {
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
        .background(PlannerTheme.surface, in: RoundedRectangle(cornerRadius: 16))
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(text("tagline")).font(.caption.bold()).tracking(2).foregroundStyle(PlannerTheme.amber)
            Text(text("headline")).font(.largeTitle.bold()).foregroundStyle(.white)
            Text(text("intro"))
                .foregroundStyle(.white.opacity(0.88))
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(22)
        .background(PlannerTheme.surface, in: RoundedRectangle(cornerRadius: 18))
    }

    private func featuredText(_ key: String) -> String { FeaturedRoutes.ui[key]?[language.index] ?? key }

    private func visibleChoice(_ title: String, selected: Bool, subtitle: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 9) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.body).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.subheadline.bold())
                    if let subtitle = subtitle { Text(subtitle).font(.caption) }
                }.fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .foregroundStyle(selected ? Color.black : Color.white)
            .background(selected ? journeyGold : PlannerTheme.raised, in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(journeyGold.opacity(selected ? 1 : 0.3), lineWidth: 1))
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? [.isSelected] : [])
    }
    private func roundChoice(_ title: String, symbol: String, selected: Bool, accent: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: selected ? "checkmark" : symbol)
                    .font(.title2.bold()).frame(width: 60, height: 60)
                    .foregroundStyle(selected ? Color.black : accent)
                    .background(selected ? accent : accent.opacity(0.14), in: Circle())
                    .overlay(Circle().stroke(accent, lineWidth: 2))
                    .accessibilityHidden(true)
                Text(title).font(.subheadline.bold()).foregroundStyle(.white)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            }.padding(.vertical, 6).frame(maxWidth: .infinity, minHeight: 100)
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private func selectCourse(_ item: DayRoute) {
        guard routeID != item.id else { return }
        resetHotelSelection()
        resetJourney()
        let pref = item.prefecture ?? NationwideRoutes.existingPrefectures[item.id] ?? "tokyo"
        prefectureID = pref
        regionID = NationwideRoutes.prefectures.first(where: { $0.id == pref })?.region ?? "kanto"
        routeID = item.id
        swapIndex = nil
    }

    private func courseButton(_ item: DayRoute) -> some View {
        let outline = item.stops.filter { $0.type != "food" }.compactMap { $0.choices.first }.map { venueText($0, 0) }.joined(separator: " → ")
        let rank = FeaturedRoutes.routes.firstIndex(where: { $0.id == item.id })
        let title = rank.map { "\($0 + 1). \(routeText(item, 0))" } ?? routeText(item, 0)
        let accent = PlannerTheme.accent((rank ?? 0) % 5)
        let selected = routeID == item.id
        return Button { selectCourse(item) } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: "map.fill").font(.title2)
                        .foregroundStyle(accent).frame(width: 52, height: 52)
                        .background(accent.opacity(0.17), in: Circle()).accessibilityHidden(true)
                    Text(title).font(.headline).foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Image(systemName: selected ? "checkmark.circle.fill" : "arrow.right.circle.fill")
                        .font(.title2).foregroundStyle(accent).accessibilityHidden(true)
                }
                Text(outline).font(.subheadline).foregroundStyle(.white.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(LinearGradient(colors: [accent.opacity(selected ? 0.22 : 0.09), PlannerTheme.surface], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(accent.opacity(selected ? 1 : 0.38), lineWidth: selected ? 2 : 1))
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private var plannerHeading: some View {
        VStack(alignment: .leading, spacing: 12) {
            languageSelectionButton
            Text(text("headline")).font(.title.bold()).foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            PlannerTravelBanner().frame(height: 120).clipShape(RoundedRectangle(cornerRadius: 22))
        }
    }
    private var selectedRouteHeading: some View {
        HStack(spacing: 12) {
            Image(systemName: "map.fill").font(.title2)
                .foregroundStyle(PlannerTheme.cyan).frame(width: 52, height: 52)
                .background(PlannerTheme.cyan.opacity(0.14), in: Circle())
            Text(routeText(route, 0)).font(.title2.bold())
                .fixedSize(horizontal: false, vertical: true)
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(PlannerTheme.surface, in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(PlannerTheme.cyan.opacity(0.5), lineWidth: 1))
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(featuredText("featured"), systemImage: "sparkles").font(.headline).foregroundStyle(journeyGold)
            Text(featuredText("featuredNote")).font(.caption).foregroundStyle(.secondary)
            ForEach(FeaturedRoutes.routes) { item in courseButton(item) }
            originalCourseEntry
            Divider()
            Text(journeyText("region")).font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 105), spacing: 8)], spacing: 8) {
                ForEach(NationwideRoutes.regions) { item in
                    roundChoice(label(item.japanese, item.english), symbol: "globe.asia.australia", selected: regionID == item.id, accent: PlannerTheme.cyan) { selectRegion(item.id) }
                }
            }
            Text(journeyText("prefecture")).font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 105), spacing: 8)], spacing: 8) {
                ForEach(prefecturesInRegion) { item in
                    roundChoice(label(item.ja, item.en), symbol: "mappin.and.ellipse", selected: prefectureID == item.id, accent: PlannerTheme.violet) { selectPrefecture(item.id) }
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
        .padding(14).background(journeySurface, in: RoundedRectangle(cornerRadius: 22))
    }

    private var originalCourseEntry: some View {
        VStack(alignment: .leading, spacing: 9) {
            NavigationLink {
                OriginalCourseView(language: language)
            } label: {
                HStack(spacing: 13) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 22, weight: .bold))
                        .frame(width: 44, height: 44)
                        .background(Color(red: 0.96, green: 0.66, blue: 0.15), in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.65), lineWidth: 1.5))
                    VStack(alignment: .leading, spacing: 5) {
                        Text(OriginalCourseText.get("open", language))
                            .font(.system(size: 16, weight: .heavy))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .allowsTightening(true)
                        Text(OriginalCourseText.get("tagline", language))
                            .font(.caption2.bold())
                            .foregroundStyle(Color(red: 1.0, green: 0.91, blue: 0.68))
                            .padding(.horizontal, 9).padding(.vertical, 4)
                            .background(Color(red: 0.14, green: 0.20, blue: 0.25), in: RoundedRectangle(cornerRadius: 6))
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right").font(.headline.bold())
                }
                .foregroundStyle(Color(red: 0.10, green: 0.14, blue: 0.18))
                .padding(.horizontal, 14).padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LinearGradient(colors: [Color(red: 1, green: 0.82, blue: 0.42), Color(red: 0.93, green: 0.66, blue: 0.21)], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(red: 1, green: 0.92, blue: 0.68), lineWidth: 1.5))
            }
            Text(OriginalCourseText.get("entryNote", language))
                .font(.subheadline)
                .foregroundStyle(Color(red: 0.84, green: 0.88, blue: 0.90))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(13)
                .background(Color(red: 0.12, green: 0.13, blue: 0.13), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(red: 0.38, green: 0.32, blue: 0.20), lineWidth: 1))
        }
        .padding(.vertical, 3)
    }

    private var featuredHomeEntry: some View {
        Button {
            showingGuide = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 58, height: 58)
                    Image(systemName: "sparkles")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(featuredHomeTitle)
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(featuredHomeNote)
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.95))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.96, green: 0.38, blue: 0.12),
                        Color(red: 0.76, green: 0.12, blue: 0.38),
                        Color(red: 0.35, green: 0.12, blue: 0.62)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 22)
            )
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.72), lineWidth: 1.5))
            .shadow(color: Color(red: 0.85, green: 0.18, blue: 0.35).opacity(0.42), radius: 10, y: 5)
        }
        .buttonStyle(.plain)
    }

    private var featuredHomeTitle: String {
        ["厳選観光コース", "엄선 관광 코스", "精选观光路线", "Selected Japan Tours", "เส้นทางท่องเที่ยวคัดสรร"][language.index]
    }

    private var featuredHomeNote: String {
        ["SNSで注目のコースをすぐに選べます", "SNS에서 주목받는 코스를 바로 선택하세요", "立即选择社交媒体热门路线", "Choose a social-media favorite", "เลือกเส้นทางยอดนิยมจากโซเชียลได้ทันที"][language.index]
    }

    private func stopCard(_ index: Int) -> some View {
        let stop = route.stops[index]
        let venue = selectedVenue(index)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Text("\(index + 1)").font(.headline.bold())
                    .foregroundStyle(.black).frame(width: 38, height: 38)
                    .background(PlannerTheme.accent(index % 5), in: Circle())
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

// Language and country options follow the supplied visitor ranking.
private enum GuideLanguage: String, CaseIterable, Identifiable {
    case ja, ko, zh, zht, en, th, fil, vi, id, ms, fr, de, hi, it, es, ru, nl, pt, sv, mn, ar, tr, pl, my, ne, si, da, fi, no, km, he, cs, el, ro, hu, bn, ur, uk, hr
    var id: String { rawValue }
    var index: Int {
        switch self { case .ja: return 0; case .ko: return 1; case .zh: return 2; case .en: return 3; case .th: return 4; case .zht: return 2; default: return 3 }
    }
    var title: String {
        [
        "ja": "日本語",
        "ko": "한국어",
        "zh": "简体中文",
        "zht": "繁體中文",
        "en": "English",
        "th": "ภาษาไทย",
        "fil": "Filipino",
        "vi": "Tiếng Việt",
        "id": "Bahasa Indonesia",
        "ms": "Bahasa Melayu",
        "fr": "Français",
        "de": "Deutsch",
        "hi": "हिन्दी",
        "it": "Italiano",
        "es": "Español",
        "ru": "Русский",
        "nl": "Nederlands",
        "pt": "Português",
        "sv": "Svenska",
        "mn": "Монгол",
        "ar": "العربية",
        "tr": "Türkçe",
        "pl": "Polski",
        "my": "မြန်မာဘာသာ",
        "ne": "नेपाली",
        "si": "සිංහල",
        "da": "Dansk",
        "fi": "Suomi",
        "no": "Norsk",
        "km": "ខ្មែរ",
        "he": "עברית",
        "cs": "Čeština",
        "el": "Ελληνικά",
        "ro": "Română",
        "hu": "Magyar",
        "bn": "বাংলা",
        "ur": "اردو",
        "uk": "Українська",
        "hr": "Hrvatski",
    ][rawValue] ?? rawValue
    }
    var countryTitle: String {
        [
        "ja": "🇯🇵 日本",
        "ko": "🇰🇷 한국",
        "zh": "🇨🇳 中国",
        "zht": "🇹🇼 台灣",
        "en": "🇺🇸 USA",
        "th": "🇹🇭 ไทย",
        "fil": "🇵🇭 Pilipinas",
        "vi": "🇻🇳 Việt Nam",
        "id": "🇮🇩 Indonesia",
        "ms": "🇲🇾 Malaysia",
        "fr": "🇫🇷 France",
        "de": "🇩🇪 Deutschland",
        "hi": "🇮🇳 भारत",
        "it": "🇮🇹 Italia",
        "es": "🇪🇸 España",
        "ru": "🇷🇺 Россия",
        "nl": "🇳🇱 Nederland",
        "pt": "🇧🇷 Brasil",
        "sv": "🇸🇪 Sverige",
        "mn": "🇲🇳 Монгол",
        "ar": "🇦🇪 الإمارات",
        "tr": "🇹🇷 Türkiye",
        "pl": "🇵🇱 Polska",
        "my": "🇲🇲 မြန်မာ",
        "ne": "🇳🇵 नेपाल",
        "si": "🇱🇰 ශ්‍රී ලංකාව",
        "da": "🇩🇰 Danmark",
        "fi": "🇫🇮 Suomi",
        "no": "🇳🇴 Norge",
        "km": "🇰🇭 កម្ពុជា",
        "he": "🇮🇱 ישראל",
        "cs": "🇨🇿 Česko",
        "el": "🇬🇷 Ελλάδα",
        "ro": "🇷🇴 România",
        "hu": "🇭🇺 Magyarország",
        "bn": "🇧🇩 বাংলাদেশ",
        "ur": "🇵🇰 پاکستان",
        "uk": "🇺🇦 Україна",
        "hr": "🇭🇷 Hrvatska",
    ][rawValue] ?? rawValue
    }
    var locale: Locale {
        [
        "ja": "ja_JP",
        "ko": "ko_KR",
        "zh": "zh_CN",
        "zht": "zh_TW",
        "en": "en_US",
        "th": "th_TH",
        "fil": "fil_PH",
        "vi": "vi_VN",
        "id": "id_ID",
        "ms": "ms_MY",
        "fr": "fr_FR",
        "de": "de_DE",
        "hi": "hi_IN",
        "it": "it_IT",
        "es": "es_ES",
        "ru": "ru_RU",
        "nl": "nl_NL",
        "pt": "pt_BR",
        "sv": "sv_SE",
        "mn": "mn_MN",
        "ar": "ar_AE",
        "tr": "tr_TR",
        "pl": "pl_PL",
        "my": "my_MM",
        "ne": "ne_NP",
        "si": "si_LK",
        "da": "da_DK",
        "fi": "fi_FI",
        "no": "nb_NO",
        "km": "km_KH",
        "he": "he_IL",
        "cs": "cs_CZ",
        "el": "el_GR",
        "ro": "ro_RO",
        "hu": "hu_HU",
        "bn": "bn_BD",
        "ur": "ur_PK",
        "uk": "uk_UA",
        "hr": "hr_HR",
    ][rawValue].map(Locale.init) ?? Locale(identifier: "en_US")
    }
    var webLanguageCode: String {
        [
        "ja": "ja",
        "ko": "ko",
        "zh": "zh-CN",
        "zht": "zh-TW",
        "en": "en",
        "th": "th",
        "fil": "tl",
        "vi": "vi",
        "id": "id",
        "ms": "ms",
        "fr": "fr",
        "de": "de",
        "hi": "hi",
        "it": "it",
        "es": "es",
        "ru": "ru",
        "nl": "nl",
        "pt": "pt",
        "sv": "sv",
        "mn": "mn",
        "ar": "ar",
        "tr": "tr",
        "pl": "pl",
        "my": "my",
        "ne": "ne",
        "si": "si",
        "da": "da",
        "fi": "fi",
        "no": "no",
        "km": "km",
        "he": "he",
        "cs": "cs",
        "el": "el",
        "ro": "ro",
        "hu": "hu",
        "bn": "bn",
        "ur": "ur",
        "uk": "uk",
        "hr": "hr",
    ][rawValue] ?? "en"
    }
}

private struct PlannerInstructionsView: View {
    let language: GuideLanguage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(language.title).font(.title2.bold()).foregroundStyle(PlannerTheme.amber)
                    ForEach(PlannerInstructions.sections(language).indices, id: \.self) { index in
                        let section = PlannerInstructions.sections(language)[index]
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .center, spacing: 12) {
                                Text("\(index + 1)").font(.headline.bold())
                                    .foregroundStyle(.black).frame(width: 36, height: 36)
                                    .background(PlannerTheme.accent(index % 5), in: Circle())
                                Text(section.0).font(.headline).foregroundStyle(.white)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .accessibilityAddTraits(.isHeader)
                            }
                            Text(section.1).font(.body).foregroundStyle(.white)
                                .lineSpacing(5)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(PlannerTheme.surface, in: RoundedRectangle(cornerRadius: 14))
                    }
                }.padding(20)
            }
            .background(Color.black)
            .navigationTitle(PlannerInstructions.buttonTitle(language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(PlannerInstructions.closeTitle(language)) { dismiss() }
                }
            }
        }
        .environment(\.locale, language.locale)
        .preferredColorScheme(.dark)
        .tint(PlannerTheme.cyan)
    }
}

private enum PlannerInstructions {
    static func buttonTitle(_ language: GuideLanguage) -> String {
        ["ja":"使い方", "ko":"사용 방법", "zh":"使用指南", "zht":"使用指南", "en":"Guide", "th":"คู่มือ", "fr":"Guide", "de":"Anleitung", "es":"Guía", "it":"Guida", "pt":"Guia", "hi":"मार्गदर्शिका", "vi":"Hướng dẫn", "id":"Panduan", "ms":"Panduan", "fil":"Gabay", "ru":"Инструкция", "nl":"Handleiding", "tr":"Kılavuz", "pl":"Instrukcja", "ar":"دليل", "my":"လမ်းညွှန်", "ne":"मार्गदर्शन", "si":"මාර්ගෝපදේශය", "km":"មគ្គុទេសក៍", "he":"מדריך", "uk":"Посібник"][language.rawValue] ?? "Guide"
    }
    static func closeTitle(_ language: GuideLanguage) -> String {
        ["ja":"閉じる", "ko":"닫기", "zh":"关闭", "zht":"關閉", "en":"Close", "th":"ปิด", "fr":"Fermer", "de":"Schließen", "es":"Cerrar", "it":"Chiudi", "pt":"Fechar", "hi":"बंद करें", "vi":"Đóng", "id":"Tutup", "ms":"Tutup", "fil":"Isara", "ru":"Закрыть", "nl":"Sluiten", "tr":"Kapat", "pl":"Zamknij", "ar":"إغلاق", "my":"ပိတ်ရန်", "ne":"बन्द", "si":"වසන්න", "km":"បិទ", "he":"סגירה", "uk":"Закрити"][language.rawValue] ?? "Close"
    }
    static func sections(_ language: GuideLanguage) -> [(String, String)] {
        switch language {
        case .ja:
            return [
                ("このアプリでできること", "日本各地の一日観光コースを選び、観光地・昼食・ホテル・夕食を組み合わせて旅程を作れます。おすすめコースやSNSで話題のコースから選ぶこともできます。まずコースと出発時刻、宿泊するホテルを設定してください。"),
                ("言語を選ぶ", "トップ画面の左側にある言語ボタンを押すと、その言語の観光画面が開きます。右側の「使い方」は、横にある言語の説明だけを開きます。説明を閉じてから左側の言語ボタンを押して始めてください。観光画面の「言語選択」から、このトップ画面に戻れます。"),
                ("地域・コース・出発時刻", "おすすめのコースボタンを押すか、地域 → 都道府県 → 観光コースの順に選びます。出発時刻を変更すると、各立ち寄り先の予定時刻と終了予定時刻が更新されます。コースや出発時刻を変更すると、旅の進行は最初に戻ります。"),
                ("ホテルを設定する", "ホテルの候補から宿泊先を選びます。自分で予約したホテルを使う場合は「自分のホテルを入力」を選び、ホテル名と地域・住所を入力してください。周辺ホテル検索で見つかった候補を選ぶこともできます。表示される地図、料金確認、公式サイト、電話などのボタンで詳細を確認します。ホテルの選択だけでは予約は完了しません。"),
                ("旅程を進める", "旅の順番には、ホテルからの出発、観光、食事、ホテルへの帰着が並びます。一覧の行を押すと、その段階の案内が開きます。順に進む場合は画面下の次へ進むボタンを押し、戻る場合は前へ戻るボタンを押してください。必要なホテルや食事を選ぶまでは、次へ進めない段階があります。"),
                ("観光地・昼食を変更する", "観光地の「立ち寄り先を変更」や昼食の選択ボタンを押し、表示された候補から選びます。変更後は旅程の予定時刻が更新されます。昼食を周辺から検索するコースでは、昼食検索ボタンを押し、住所やメニュー・営業時間を確認して店を選んでください。候補が出ない場合は、追加の地図検索リンクから探せます。"),
                ("地図・移動経路を見る", "電車・バスなどの公共交通、徒歩、車の経路ボタンから、出発地と目的地の地図を開きます。地図はアプリ内で表示されます。公共交通のページでは乗車駅、乗り換え、所要時間などを確認してください。地図画面を閉じると旅程に戻ります。表示される時刻は目安なので、実際の出発時刻に合わせて経路を確認してください。"),
                ("夕食とホテルへの帰り方", "夕食エリアは自動、ホテル周辺、最後の観光地周辺から選べます。自動では観光終了が18時より前ならホテル周辺、18時以降なら最後の観光地周辺を選びます。夕食検索ボタンで店を探し、店を選択してから経路を確認します。食後は選んだホテルへの帰り道を確認できます。"),
                ("公式情報・翻訳・旅程共有", "観光地や店の公式情報ボタンで、営業時間・料金・チケット・予約条件を確認します。日本語以外ではリンク先の翻訳表示を優先しますが、翻訳できないページや固有名詞が元の言語で表示される場合があります。観光画面右上の共有ボタンで、旅程をメッセージやメモなどへ送れます。"),
                ("保存と困ったとき", "言語、コース、出発時刻、観光地の選択は端末に保存されます。ホテルは新しいコースや最初の観光地を選ぶたびに選び直し、アプリを開き直した場合も再入力します。検索した昼食・夕食や旅の進行も再設定が必要になる場合があります。検索が出ない場合は通信を確認し、ホテル名に地域や住所を加えて再検索してください。予定時刻・移動時間・料金は目安です。出発前に公式情報と地図で最新の条件を確認してください。")
            ]
        case .ko:
            return [
                ("앱에서 할 수 있는 일", "일본 각지의 당일 관광 코스를 고르고 관광지, 점심, 호텔, 저녁을 조합하여 일정을 만듭니다. 추천 코스나 SNS에서 주목받는 코스도 선택할 수 있습니다. 먼저 코스, 출발 시간, 숙박할 호텔을 설정하세요."),
                ("언어 선택", "첫 화면 왼쪽의 언어 버튼을 누르면 해당 언어의 여행 화면이 열립니다. 오른쪽 사용 방법 버튼은 같은 줄에 있는 언어의 설명만 엽니다. 설명을 닫고 왼쪽 언어 버튼을 눌러 시작하세요. 여행 화면의 언어 선택 버튼으로 첫 화면에 돌아갈 수 있습니다."),
                ("지역, 코스, 출발 시간", "추천 코스를 누르거나 지역 → 도도부현 → 관광 코스 순서로 선택하세요. 출발 시간을 바꾸면 각 장소의 예정 시간과 종료 예정 시간이 갱신됩니다. 코스나 출발 시간을 바꾸면 여행 진행 단계가 처음으로 돌아갑니다."),
                ("호텔 설정", "호텔 후보에서 숙박할 곳을 선택하세요. 직접 예약한 호텔은 내 호텔 입력을 선택한 뒤 호텔 이름과 지역 또는 주소를 입력하세요. 주변 호텔 검색으로 찾은 후보도 선택할 수 있습니다. 표시되는 지도, 요금 확인, 공식 사이트, 전화 버튼으로 상세 정보를 확인하세요. 호텔을 선택하는 것만으로 예약되지는 않습니다."),
                ("일정 진행", "순서 목록에는 호텔 출발, 관광, 식사, 호텔 복귀가 표시됩니다. 목록의 항목을 누르면 해당 단계의 안내가 열립니다. 순서대로 진행하려면 아래의 다음 단계 버튼을, 돌아가려면 이전 단계 버튼을 누르세요. 필요한 호텔이나 식당을 선택해야 다음으로 넘어갈 수 있는 단계도 있습니다."),
                ("관광지와 점심 변경", "관광지 변경 또는 점심 선택 버튼을 누르고 후보를 선택하세요. 변경하면 일정의 예정 시간이 갱신됩니다. 주변 점심 식당을 검색하는 코스에서는 점심 검색 버튼으로 찾고 주소, 메뉴, 영업시간을 확인한 뒤 식당을 선택하세요. 결과가 없으면 추가 지도 검색 링크를 이용하세요."),
                ("지도와 이동 경로", "대중교통, 도보, 자동차 경로 버튼으로 출발지와 목적지의 지도를 엽니다. 지도는 앱 안에서 표시됩니다. 대중교통 페이지에서 승차역, 환승, 소요 시간 등을 확인하세요. 지도를 닫으면 일정으로 돌아갑니다. 예정 시간은 추정치이므로 실제 출발 시간에 맞춰 경로를 확인하세요."),
                ("저녁과 호텔 복귀", "저녁 장소는 자동, 호텔 주변, 마지막 관광지 주변 중에서 고릅니다. 자동은 관광이 18시 전에 끝나면 호텔 주변, 18시부터는 마지막 관광지 주변을 선택합니다. 저녁 검색 버튼으로 식당을 찾고 선택한 뒤 경로를 확인하세요. 식사 후에는 선택한 호텔로 돌아가는 길을 확인할 수 있습니다."),
                ("공식 정보, 번역, 공유", "관광지와 식당의 공식 정보 버튼으로 영업시간, 요금, 입장권, 예약 조건을 확인하세요. 일본어 이외의 언어에서는 번역 페이지를 우선 표시하지만 일부 페이지나 고유명사는 원래 언어로 나올 수 있습니다. 여행 화면 오른쪽 위 공유 버튼으로 일정을 메시지나 메모 등에 보낼 수 있습니다."),
                ("저장 및 문제 해결", "언어, 코스, 출발 시간과 관광지 선택은 기기에 저장됩니다. 새 코스나 첫 관광지를 선택할 때마다 호텔을 다시 선택해야 하며 앱을 다시 열어도 호텔을 다시 입력해야 합니다. 검색한 점심·저녁과 여행 진행 단계도 다시 설정해야 할 수 있습니다. 검색이 안 되면 인터넷 연결을 확인하고 호텔 이름에 지역이나 주소를 더해 다시 검색하세요. 시간, 이동 간격, 요금은 참고용입니다. 출발 전에 공식 정보와 지도에서 최신 조건을 확인하세요.")
            ]
        case .zh:
            return [
                ("这个应用可以做什么", "选择日本各地的一日观光路线，组合景点、午餐、酒店和晚餐，制定行程。也可以选择推荐路线或在社交媒体上受关注的路线。请先设置路线、出发时间和入住酒店。"),
                ("选择语言", "点击首页左侧的语言按钮，进入该语言的旅游页面。右侧的使用说明按钮只打开同一行语言的说明。关闭说明后，点击左侧语言按钮开始。在旅游页面点击选择语言，可以返回首页。"),
                ("地区、路线和出发时间", "点击推荐路线，或按地区 → 都道府县 → 观光路线的顺序选择。修改出发时间后，各站预计时间和预计结束时间会更新。更改路线或出发时间后，行程进度会回到第一步。"),
                ("设置酒店", "从酒店候选中选择入住地点。如已自行预订，请选择输入自己的酒店，并输入酒店名称及地区或地址。也可以通过周边酒店搜索选择候选。使用页面显示的地图、价格查询、官网、电话等按钮查看详情。选择酒店本身不会完成预订。"),
                ("按步骤游览", "行程顺序中列出酒店出发、观光、用餐和返回酒店。点击列表中的一项，即可查看该阶段的说明。按顺序游览时，点击底部的下一步；需要返回时，点击上一步。某些阶段需要先选定酒店或餐厅，才能继续。"),
                ("更换景点和午餐", "点击更换景点或选择午餐按钮，再从候选中选择。更改后，行程预计时间会更新。需要搜索附近午餐的路线，请点击午餐搜索，确认餐厅地址、菜单和营业时间后选择餐厅。没有结果时，可以使用更多地图搜索链接。"),
                ("查看地图和交通路线", "点击公共交通、步行或驾车路线按钮，打开出发地与目的地的地图。地图在应用内显示。请在公共交通页面确认上车站、换乘和所需时间等信息。关闭地图后返回行程。预计时间仅供参考，请按实际出发时间确认路线。"),
                ("晚餐和返回酒店", "晚餐区域可选自动、酒店附近或最后景点附近。自动模式下，观光在18点前结束时选择酒店附近，18点及之后选择最后景点附近。点击晚餐搜索，选定餐厅后查看路线。餐后可以查看返回所选酒店的路线。"),
                ("官方信息、翻译和分享", "通过景点或餐厅的官方信息按钮确认营业时间、价格、门票和预订条件。使用日语以外的语言时，会优先打开翻译页面，但部分网页或专有名称可能仍显示原文。点击旅游页面右上角的分享按钮，可将行程发送到消息、备忘录等。"),
                ("保存和问题处理", "语言、路线、出发时间和景点选择会保存在设备上。每次更换路线或第一处景点，都需要重新选择酒店；重新打开应用后也需要重新输入酒店。搜索得到的午餐、晚餐和行程进度也可能需要重新设置。搜索无结果时，请检查网络，并在酒店名后加上地区或地址再搜索。时间、交通间隔和价格仅供参考。出发前请通过官方信息和地图确认最新条件。")
            ]
        case .en:
            return [
                ("What you can do", "Build a day trip in Japan by choosing a sightseeing route, places to visit, lunch, a hotel and dinner. You can also choose featured routes and routes highlighted on social media. Start by setting your route, departure time and hotel."),
                ("Choose a language", "Tap a language button on the left of the home screen to open the planner in that language. The User guide button on the right opens instructions in the language on the same row. Close the guide, then tap the language button to begin. Use Languages in the planner to return home."),
                ("Choose your route and start time", "Tap a featured route, or choose a region, prefecture and sightseeing route in that order. Changing the start time updates the planned times at each stop and the estimated finish time. Changing the route or start time returns your journey progress to the first stage."),
                ("Set your hotel", "Choose a hotel from the suggestions. If you have booked elsewhere, choose Enter your own hotel and enter its name with the area or address. You can also search for nearby hotels and select a result. Use the available map, rate, website and phone buttons to check details. Selecting a hotel does not make a booking."),
                ("Follow your itinerary", "The order list shows departure from the hotel, sightseeing, meals and return to the hotel. Tap a row to open that stage. To follow the trip in order, use the next-stage button at the bottom; use the previous-stage button to go back. Some stages require a hotel or restaurant selection before you can continue."),
                ("Change a stop or lunch", "Tap Swap this stop or Choose lunch and pick an alternative. The planned times update after a change. On routes that search for nearby lunch, use the lunch search button, check the address, menu and opening hours, then select a restaurant. If no results appear, use the additional map search link."),
                ("Open maps and directions", "Use the public transport, walking or driving buttons to open a map between the origin and destination. Maps appear inside the app. Check boarding stations, transfers and travel times on the public transport page. Close the map to return to your itinerary. Planned times are estimates; check directions for your actual departure time."),
                ("Plan dinner and return to your hotel", "Choose Auto, Near hotel or Near final stop for dinner. Auto chooses the hotel area when sightseeing ends before 18:00, and the final stop area from 18:00 onwards. Search for dinner, select a restaurant and check the directions. After dinner, view the route back to your selected hotel."),
                ("Official details, translation and sharing", "Open official information for each attraction or restaurant to check hours, prices, tickets and reservation conditions. For languages other than Japanese, translated pages are preferred, but some pages and proper names may remain in their original language. Use the share button at the top right of the planner to send your itinerary to messages, notes or another app."),
                ("Saved settings and troubleshooting", "Your language, route, start time and sightseeing choices are saved on your device. Choose a hotel again whenever you change the route or first stop, and after reopening the app. Lunch and dinner search selections and journey progress may also need to be set again. If a search returns no results, check your connection and add an area or address to the hotel name before searching again. Times, transfer gaps and prices are estimates. Check current conditions using official information and maps before you leave.")
            ]
        case .th:
            return [
                ("แอปนี้ทำอะไรได้บ้าง", "วางแผนเที่ยวญี่ปุ่นหนึ่งวันโดยเลือกเส้นทาง สถานที่ท่องเที่ยว มื้อกลางวัน โรงแรม และมื้อเย็น เลือกได้ทั้งเส้นทางแนะนำและเส้นทางที่ได้รับความสนใจบนโซเชียลมีเดีย เริ่มจากกำหนดเส้นทาง เวลาออกเดินทาง และโรงแรมที่จะพัก"),
                ("เลือกภาษา", "กดปุ่มภาษาทางซ้ายของหน้าแรกเพื่อเปิดหน้าวางแผนในภาษานั้น ปุ่มวิธีใช้งานทางขวาจะเปิดคำอธิบายเป็นภาษาเดียวกับปุ่มในแถวเดียวกัน ปิดคำอธิบายแล้วกดปุ่มภาษาเพื่อเริ่มใช้งาน กดปุ่มเลือกภาษาในหน้าวางแผนเพื่อกลับหน้าแรก"),
                ("เลือกพื้นที่ เส้นทาง และเวลา", "กดเส้นทางแนะนำ หรือเลือกภูมิภาค → จังหวัด → เส้นทางท่องเที่ยวตามลำดับ เมื่อเปลี่ยนเวลาเริ่ม เวลาแต่ละจุดและเวลาสิ้นสุดโดยประมาณจะปรับตาม เมื่อเปลี่ยนเส้นทางหรือเวลาเริ่ม ความคืบหน้าของทริปจะกลับไปขั้นแรก"),
                ("กำหนดโรงแรม", "เลือกที่พักจากรายชื่อโรงแรม หากจองที่อื่นไว้แล้ว ให้เลือกตัวเลือกระบุโรงแรมของคุณ แล้วกรอกชื่อพร้อมพื้นที่หรือที่อยู่ สามารถค้นหาโรงแรมใกล้เคียงและเลือกผลการค้นหาได้ ใช้ปุ่มแผนที่ ตรวจสอบราคา เว็บไซต์ หรือโทรศัพท์ที่แสดงเพื่อดูรายละเอียด การเลือกโรงแรมไม่ได้เป็นการจองห้องพัก"),
                ("เดินทางตามแผน", "รายการลำดับทริปแสดงการออกจากโรงแรม การเที่ยว มื้ออาหาร และการกลับโรงแรม กดรายการเพื่อเปิดคำแนะนำของขั้นนั้น หากต้องการเดินทางตามลำดับ ให้กดปุ่มขั้นถัดไปด้านล่าง หรือกดปุ่มขั้นก่อนหน้าเพื่อย้อนกลับ บางขั้นต้องเลือกโรงแรมหรือร้านอาหารก่อนจึงจะไปต่อได้"),
                ("เปลี่ยนสถานที่หรือมื้อกลางวัน", "กดปุ่มเปลี่ยนสถานที่หรือเลือกมื้อกลางวัน แล้วเลือกจากตัวเลือกที่แสดง เวลาตามแผนจะปรับหลังเปลี่ยน สำหรับเส้นทางที่ค้นหาร้านมื้อกลางวันใกล้เคียง ให้กดค้นหา ตรวจสอบที่อยู่ เมนู และเวลาเปิด แล้วเลือกร้าน หากไม่มีผลลัพธ์ ให้ใช้ลิงก์ค้นหาเพิ่มเติมบนแผนที่"),
                ("ดูแผนที่และเส้นทาง", "กดปุ่มขนส่งสาธารณะ เดิน หรือรถยนต์ เพื่อเปิดแผนที่จากจุดเริ่มต้นไปยังจุดหมาย แผนที่แสดงภายในแอป ตรวจสอบสถานีขึ้นรถ จุดเปลี่ยนรถ และเวลาเดินทางในหน้าขนส่งสาธารณะ ปิดแผนที่เพื่อกลับไปยังแผนทริป เวลาเป็นค่าประมาณ ควรตรวจสอบเส้นทางตามเวลาออกเดินทางจริง"),
                ("มื้อเย็นและการกลับโรงแรม", "เลือกพื้นที่มื้อเย็นแบบอัตโนมัติ ใกล้โรงแรม หรือใกล้สถานที่สุดท้าย แบบอัตโนมัติจะเลือกใกล้โรงแรมเมื่อเที่ยวเสร็จก่อน 18:00 และใกล้สถานที่สุดท้ายเมื่อเสร็จตั้งแต่ 18:00 เป็นต้นไป กดค้นหามื้อเย็น เลือกร้าน แล้วตรวจสอบเส้นทาง หลังรับประทานอาหารสามารถดูทางกลับโรงแรมที่เลือกไว้ได้"),
                ("ข้อมูลทางการ คำแปล และการแชร์", "เปิดข้อมูลทางการของสถานที่หรือร้านอาหารเพื่อตรวจสอบเวลาเปิด ราคา ตั๋ว และเงื่อนไขการจอง เมื่อใช้ภาษาอื่นที่ไม่ใช่ญี่ปุ่น แอปจะเปิดหน้าคำแปลก่อน แต่บางหน้าหรือชื่อเฉพาะอาจยังเป็นภาษาต้นฉบับ กดปุ่มแชร์มุมขวาบนของหน้าวางแผนเพื่อส่งแผนทริปไปยังข้อความ โน้ต หรือแอปอื่น"),
                ("การบันทึกและการแก้ปัญหา", "ภาษา เส้นทาง เวลาเริ่ม และสถานที่เที่ยวที่เลือกจะบันทึกไว้ในอุปกรณ์ ต้องเลือกโรงแรมใหม่ทุกครั้งเมื่อเปลี่ยนเส้นทางหรือจุดเที่ยวแรก และเมื่อเปิดแอปใหม่ ร้านมื้อกลางวันและมื้อเย็นที่ค้นหา รวมถึงความคืบหน้าของทริป อาจต้องเลือกใหม่ หากค้นหาไม่พบ ให้ตรวจสอบอินเทอร์เน็ตและเพิ่มพื้นที่หรือที่อยู่ต่อท้ายชื่อโรงแรมแล้วค้นหาอีกครั้ง เวลา ช่วงการเดินทาง และราคาเป็นค่าประมาณ ก่อนออกเดินทางควรตรวจสอบข้อมูลล่าสุดจากเว็บไซต์ทางการและแผนที่")
            ]
        default:
            return sections(.en)
        }
    }
}

private enum HotelTravelTranslations {
    static let ui: [String: [String]] = [
        "registeredStay": ["事前登録の地域内候補です。出発地からの距離は地図で確認してください。", "지역 내 등록 숙소입니다. 출발지와의 거리는 지도에서 확인하세요.", "区域内预存住宿候选，请在地图确认与起点的距离。", "Registered regional alternative. Check its distance from your starting point on the map.", "ที่พักสำรองในภูมิภาค โปรดตรวจสอบระยะทางจากจุดเริ่มต้นบนแผนที่"],
        "siteWalk": ["同じ施設内の移動です。鳥居参道は徒歩で進み、車・タクシーは駐車場までです。", "같은 시설 내부 이동입니다. 도리이 길은 도보이며 차량은 주차장까지만 이용하세요.", "同一景点内部移动。鸟居步道请步行，车辆仅到停车场。", "Within the same attraction. Walk along the torii path; cars and taxis stop at the parking area.", "เดินภายในสถานที่เดียวกัน ทางโทริอิต้องเดิน รถยนต์และแท็กซี่ถึงลานจอดเท่านั้น"],

        "chooseNow": ["次は宿泊するホテルを選ぶ", "다음 단계: 숙박할 호텔 선택", "下一步：选择入住酒店", "Next: choose your hotel", "ขั้นต่อไป: เลือกโรงแรมที่พัก"],
        "firstPlace": ["最初の観光地", "첫 관광지", "第一处景点", "First sightseeing stop", "จุดเที่ยวแรก"],
        "notChosen": ["ホテルはまだ選ばれていません。近くのホテルを探すか、自分のホテルを入力してください。", "아직 호텔을 선택하지 않았습니다. 주변 호텔을 찾거나 예약한 호텔을 입력하세요.", "尚未选择酒店。请搜索附近酒店或输入已预订的酒店。", "No hotel selected yet. Find one nearby or enter your booked hotel.", "ยังไม่ได้เลือกโรงแรม ค้นหาโรงแรมใกล้เคียงหรือระบุโรงแรมที่จองไว้"],
        "selectedHotel": ["選択中のホテル", "선택한 호텔", "已选酒店", "Selected hotel", "โรงแรมที่เลือก"],
        "afterChoosing": ["ホテルを選ぶと、その下に最初の観光地までの所要時間が表示されます。次は旅の順番へ進んでください。", "호텔을 고르면 바로 아래에 첫 관광지까지의 이동 시간이 표시됩니다. 다음에는 여행 순서를 확인하세요.", "选择酒店后，下方会显示到第一处景点的所需时间。接着查看行程顺序。", "Choose a hotel to see travel times to the first stop directly below it. Then follow the trip order.", "เลือกโรงแรมแล้วดูเวลาเดินทางไปยังจุดเที่ยวแรกด้านล่าง จากนั้นทำตามลำดับทริป"],
        "sortHotels": ["ホテルの並べ方", "숙소 정렬", "住宿排序", "Sort stays", "เรียงที่พัก"],
        "walkSort": ["徒歩経路が近い順", "도보 경로 거리순", "步行路线距离", "Walking route distance", "ระยะทางเดิน"],
        "straightDistance": ["直線距離", "직선거리", "直线距离", "Straight-line distance", "ระยะทางเส้นตรง"],
        "routeDistance": ["経路距離", "경로 거리", "路线距离", "Route distance", "ระยะทางตามเส้นทาง"],
        "routeEstimate": ["経路の予測", "경로 예상", "路线预计", "Route estimate", "เวลาคาดการณ์ตามเส้นทาง"],
        "checkingRoute": ["徒歩経路を確認中…", "도보 경로 확인 중…", "正在确认步行路线…", "Checking walking route…", "กำลังตรวจทางเดิน…"],
        "walkUnconfirmed": ["徒歩経路は未確認・地図で確認", "도보 경로 미확인 · 지도에서 확인", "步行路线未确认，请查看地图", "Walking route unconfirmed · check map", "ยังไม่ยืนยันทางเดิน โปรดตรวจแผนที่"],
        "nearestFive": ["最初の観光地周辺の候補・最大8件。徒歩順は経路を確認できた宿を優先し、未確認の宿は後に表示。全宿泊施設の網羅・空室は保証しません。", "첫 관광지 주변 후보 최대 8곳. 도보순은 경로 확인 숙소 우선, 미확인은 뒤에 표시. 모든 숙소·빈방을 보장하지 않습니다.", "第一站周边最多8家候选。步行排序优先已确认路线，未确认的列在后面。不保证涵盖所有住宿或有空房。", "Up to 8 nearby candidates. Walking order lists confirmed routes first, unconfirmed stays after them. Coverage and vacancies are not guaranteed.", "ที่พักใกล้จุดแรกสูงสุด 8 แห่ง เรียงเดินโดยแสดงเส้นทางที่ตรวจได้ก่อน ที่ยังตรวจไม่ได้อยู่ท้าย ไม่รับรองว่าครบทุกแห่งหรือมีห้องว่าง"],
        "calculating": ["経路の所要時間を確認中…", "경로 소요 시간 확인 중…", "正在查询路线时间…", "Checking travel times…", "กำลังตรวจสอบเวลาเดินทาง…"],
        "transit": ["電車・バス", "전철·버스", "电车・公交", "Train / bus", "รถไฟ / รถบัส"],
        "walking": ["徒歩", "도보", "步行", "Walking", "เดิน"],
        "taxi": ["車・タクシー", "차량·택시", "汽车・出租车", "Car / taxi", "รถยนต์ / แท็กซี่"],
        "minutes": ["約%d分", "약 %d분", "约%d分钟", "About %d min", "ประมาณ %d นาที"],
        "hours": ["約%d時間", "약 %d시간", "约%d小时", "About %d hr", "ประมาณ %d ชม."],
        "hoursAndMinutes": ["約%d時間%d分", "약 %d시간 %d분", "约%d小时%d分钟", "About %d hr %d min", "ประมาณ %d ชม. %d นาที"],
        "approximate": ["概算", "대략", "粗略估算", "Rough estimate", "คำนวณคร่าว ๆ"],
        "retry": ["所要時間を再検索", "소요 시간 다시 검색", "重新查询时间", "Retry travel times", "ค้นหาเวลาอีกครั้ง"],
        "placeUnavailable": ["場所を確認できません・地図で確認", "위치 확인 필요 · 지도 확인", "地点未确认，请查看地图", "Location unresolved · check map", "ยังระบุตำแหน่งไม่ได้ ดูแผนที่"],
        "transitUnavailable": ["運行・時刻未確認・乗換を確認", "운행·시간 미확인 · 환승 확인", "班次时间未确认，请查询换乘", "Timetable unconfirmed · check transit", "ยังยืนยันตารางรถไม่ได้ ดูการต่อรถ"],
        "unavailable": ["経路を取得できません", "경로를 가져올 수 없음", "无法获取路线", "Route unavailable", "ไม่พบเส้นทาง"],
        "estimateNote": ["「経路の予測」は地図サービスの経路距離と予測時間です。出発時刻・坂道・通行規制などで変わります。「概算」は直線距離からの粗い目安で、道路のつながりを確認していません。電車・バスは取得できた運行情報のみ表示します。宿坊などは利用条件も確認してください。", "경로 예상은 지도 서비스의 거리·시간입니다. 출발 시각·경사·통제로 달라집니다. 대략은 직선거리 기반으로 도로 연결을 확인하지 않았습니다. 대중교통은 확인된 정보만 표시합니다. 사찰 숙박 등의 이용 조건도 확인하세요.", "路线预计采用地图服务的路线距离及时间，会受出发时间、坡道及通行限制影响。粗略估算基于直线距离，未确认道路连通。公交仅显示取得的运行信息。寺院等住宿请确认使用条件。", "Route estimates use map-service distances and times; departure time, slopes and closures can affect them. Rough estimates use straight-line distance and do not confirm road access. Transit is shown only when returned by the service. Check conditions for temple and other restricted lodging.", "เวลาคาดการณ์ใช้ระยะและเวลาจากแผนที่ อาจเปลี่ยนตามเวลาออก ทางลาด และการปิดทาง ค่าคร่าว ๆ ใช้ระยะเส้นตรง ไม่ยืนยันถนนเชื่อมต่อ ขนส่งสาธารณะแสดงเฉพาะข้อมูลที่ได้รับ โปรดตรวจเงื่อนไขที่พักวัดและที่พักอื่น"]
    ]
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
        "planningGap": ["計画上の移動枠：約%d分（下の各経路の所要時間とは別）", "계획상 이동 여유: 약 %d분 (아래 경로별 소요 시간과 별도)", "行程预留交通时间：约%d分钟（与下方各路线时间不同）", "Time allowed in the plan: about %d min (separate from route times below)", "เวลาเผื่อเดินทางในแผนประมาณ %d นาที (แยกจากเวลาแต่ละเส้นทางด้านล่าง)"],
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
    let anchorLatitude: Double?
    let anchorLongitude: Double?
    var lookupQuery: String? = nil
    var query: String { lookupQuery ?? "\(latitude),\(longitude)" }
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
[{"id":"sns-gotokuji","prefecture":"tokyo","label":"Tokyo · Lucky cats & Setagaya tram","title":"Tokyo · Lucky cats & Setagaya tram","description":"Visit the temple whose lucky cats drew overseas social media attention, then local shopping streets.","area":"tokyo","gap":20,"stops":[{"type":"sight","duration":55,"choices":[["Gotokuji Temple","Check official information before visiting.","https://gotokuji.jp/"]]},{"type":"walk","duration":55,"choices":[["Gotokuji shopping street","Check official information before visiting.","https://www.google.com/maps/search/?api=1&query=%E8%B1%AA%E5%BE%B3%E5%AF%BA%E5%95%86%E5%BA%97%E8%A1%97+Japan"]]},{"type":"food","duration":60,"choices":[["Lunch near Gotokuji Station","Choose a nearby restaurant.","https://www.google.com/maps/search/?api=1&query=restaurants+Gotokuji+Station"]]},{"type":"break","duration":55,"choices":[["Sangenjaya shopping streets","Check official information before visiting.","https://www.google.com/maps/search/?api=1&query=%E4%B8%89%E8%BB%92%E8%8C%B6%E5%B1%8B%E3%81%AE%E5%95%86%E5%BA%97%E8%A1%97+Japan"]]}]},{"id":"sns-katsuoji","prefecture":"osaka","label":"Osaka · Katsuoji daruma & Minoh","title":"Osaka · Katsuoji daruma & Minoh","description":"Explore Katsuoji, popular with international visitors, then Minoh Station and the waterfall trail entrance.","area":"osaka","gap":45,"stops":[{"type":"sight","duration":55,"choices":[["Katsuoji Temple","Check official information before visiting.","https://katsuo-ji-temple.or.jp/"]]},{"type":"walk","duration":55,"choices":[["Minoh Station shopping street","Check official information before visiting.","https://www.google.com/maps/search/?api=1&query=%E7%AE%95%E9%9D%A2%E9%A7%85%E5%89%8D%E5%95%86%E5%BA%97%E8%A1%97+Japan"]]},{"type":"food","duration":60,"choices":[["Lunch near Minoh Station","Choose a nearby restaurant.","https://www.google.com/maps/search/?api=1&query=restaurants+Minoh+Station"]]},{"type":"break","duration":55,"choices":[["Minoh waterfall trail entrance","Check official information before visiting.","https://www.google.com/maps/search/?api=1&query=%E7%AE%95%E9%9D%A2%E6%BB%9D%E9%81%93%E5%85%A5%E5%8F%A3+Japan"]]}]},{"id":"sns-okusaga","prefecture":"kyoto","label":"Kyoto · Okusaga stone figures & old lanes","title":"Kyoto · Okusaga stone figures & old lanes","description":"Start at Otagi Nenbutsuji, attracting international visitors, and walk downhill through Saga Toriimoto.","area":"kyoto","gap":20,"stops":[{"type":"sight","duration":55,"choices":[["Otagi Nenbutsuji Temple","Check official information before visiting.","https://www.otagiji.com/visit-en"]]},{"type":"walk","duration":55,"choices":[["Saga Toriimoto preserved street","Check official information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%B5%AF%E5%B3%A8%E9%B3%A5%E5%B1%85%E6%9C%AC%E7%94%BA%E4%B8%A6%E3%81%BF%E4%BF%9D%E5%AD%98%E5%9C%B0%E5%8C%BA+Japan"]]},{"type":"food","duration":60,"choices":[["Lunch near Saga Toriimoto","Choose a nearby restaurant.","https://www.google.com/maps/search/?api=1&query=restaurants+Saga+Toriimoto+Kyoto"]]},{"type":"sight","duration":55,"choices":[["Adashino Nenbutsuji Temple","Check official information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%8C%96%E9%87%8E%E5%BF%B5%E4%BB%8F%E5%AF%BA+Japan"]]},{"type":"break","duration":55,"choices":[["Saga Arashiyama Station","Check official information before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%B5%AF%E5%B3%A8%E5%B5%90%E5%B1%B1%E9%A7%85+Japan"]]}]},{"id":"sns-chichibugahama","prefecture":"kagawa","label":"Kagawa · Chichibugahama mirror beach & Nio","title":"Kagawa · Chichibugahama mirror beach & Nio","description":"Explore Nio port town and the beach attracting international social media attention.","area":"kagawa","gap":20,"stops":[{"type":"sight","duration":55,"choices":[["Nio port town","Check official information before visiting.","https://www.google.com/maps/search/?api=1&query=%E4%BB%81%E5%B0%BE%E3%81%AE%E6%B8%AF%E7%94%BA+Japan"]]},{"type":"walk","duration":55,"choices":[["Nio Hachiman Shrine","Check official information before visiting.","https://www.google.com/maps/search/?api=1&query=%E4%BB%81%E5%B0%BE%E5%85%AB%E5%B9%A1%E7%A5%9E%E7%A4%BE+Japan"]]},{"type":"food","duration":60,"choices":[["Lunch near Nio Mitoyo","Choose a nearby restaurant.","https://www.google.com/maps/search/?api=1&query=restaurants+Nio+Mitoyo"]]},{"type":"break","duration":55,"choices":[["Chichibugahama Beach","Check official information before visiting.","https://www.mitoyo-kanko.com/chichibugahama/"]]}]},{"id":"sns-ginzan","prefecture":"yamagata","label":"Yamagata · Ginzan Onsen old town","title":"Yamagata · Ginzan Onsen old town","description":"Walk past wooden inns along the Ginzan River; check park access before exploring Shirogane Park.","area":"yamagata","gap":15,"stops":[{"type":"sight","duration":45,"choices":[["Ginzan Onsen town","Check official information and current access before visiting.","https://www.ginzanonsen.jp/index.html"]]},{"type":"walk","duration":35,"choices":[["Ginzan River bridges","Check official information and current access before visiting.","https://www.google.com/maps/search/?api=1&query=%E9%8A%80%E5%B1%B1%E5%B7%9D%E3%81%AE%E6%A9%8B%E3%81%A8%E9%81%8A%E6%AD%A9%E9%81%93%2C+Japan"]]},{"type":"food","duration":60,"choices":[["Lunch in Ginzan Onsen","Check official information and current access before visiting.","https://www.google.com/maps/search/?api=1&query=%E9%8A%80%E5%B1%B1%E6%B8%A9%E6%B3%89%E8%A1%97%E3%81%A7%E6%98%BC%E9%A3%9F%2C+Japan"]]},{"type":"break","duration":45,"choices":[["Shirogane Park entrance","Check official information and current access before visiting.","https://www.google.com/maps/search/?api=1&query=%E7%99%BD%E9%8A%80%E5%85%AC%E5%9C%92%E5%85%A5%E5%8F%A3%2C+Japan"]]}]},{"id":"sns-fujiyoshida","prefecture":"yamanashi","label":"Yamanashi · Honcho Street & Arakurayama","title":"Yamanashi · Honcho Street & Arakurayama","description":"Explore the Fuji street view highlighted by the local tourism guide, then Arakurayama viewpoints.","area":"yamanashi","gap":25,"stops":[{"type":"sight","duration":25,"choices":[["Shimoyoshida Station","Check official information and current access before visiting.","https://www.google.com/maps/search/?api=1&query=%E4%B8%8B%E5%90%89%E7%94%B0%E9%A7%85%2C+Japan"]]},{"type":"walk","duration":60,"choices":[["Honcho Street (Fujimichi)","Check official information and current access before visiting.","https://fujiyoshida.net/spot/index.php?p=410"]]},{"type":"food","duration":60,"choices":[["Lunch in Shimoyoshida","Check official information and current access before visiting.","https://www.google.com/maps/search/?api=1&query=%E4%B8%8B%E5%90%89%E7%94%B0%E3%81%AE%E5%95%86%E5%BA%97%E8%A1%97%E3%81%A7%E6%98%BC%E9%A3%9F%2C+Japan"]]},{"type":"sight","duration":90,"choices":[["Arakurayama Sengen Park","Check official information and current access before visiting.","https://www.google.com/maps/search/?api=1&query=%E6%96%B0%E5%80%89%E5%B1%B1%E6%B5%85%E9%96%93%E5%85%AC%E5%9C%92%2C+Japan"]]}]},{"id":"sns-biei","prefecture":"hokkaido","label":"Hokkaido · Biei Blue Pond & Shirahige Falls","title":"Hokkaido · Biei Blue Pond & Shirahige Falls","description":"Explore Shirogane scenery: the blue pond, standing trees and Shirahige Falls.","area":"hokkaido","gap":25,"stops":[{"type":"sight","duration":50,"choices":[["Shirogane Blue Pond","Check official information and current access before visiting.","https://www.biei-hokkaido.jp/ja/shirogane-blue-pond"]]},{"type":"sight","duration":35,"choices":[["Shirahige Falls","Check official information and current access before visiting.","https://www.google.com/maps/search/?api=1&query=%E7%99%BD%E3%81%B2%E3%81%92%E3%81%AE%E6%BB%9D%2C+Japan"]]},{"type":"food","duration":60,"choices":[["Lunch in Biei Shirogane Onsen","Check official information and current access before visiting.","https://www.google.com/maps/search/?api=1&query=%E7%BE%8E%E7%91%9B%E7%99%BD%E9%87%91%E6%B8%A9%E6%B3%89%E3%81%A7%E6%98%BC%E9%A3%9F%2C+Japan"]]},{"type":"break","duration":35,"choices":[["Biei Shirogane Birke roadside station","Check official information and current access before visiting.","https://www.google.com/maps/search/?api=1&query=%E9%81%93%E3%81%AE%E9%A7%85%E3%81%B3%E3%81%88%E3%81%84%E7%99%BD%E9%87%91%E3%83%93%E3%83%AB%E3%82%B1%2C+Japan"]]}]},{"id":"sns-shodoshima","prefecture":"kagawa","label":"Kagawa · Shodoshima windmill & magic broom","title":"Kagawa · Shodoshima windmill & magic broom","description":"Enjoy the sea-view windmill and broom photos within Shodoshima Olive Park.","area":"kagawa","gap":10,"stops":[{"type":"sight","duration":35,"choices":[["Shodoshima Olive Park","Check official information and current access before visiting.","https://www.olive-pk.jp/"]]},{"type":"walk","duration":45,"choices":[["Olive Park Greek windmill","Check official information and current access before visiting.","https://www.olive-pk.jp/en/broom/index.html"]]},{"type":"food","duration":60,"choices":[["Lunch at Shodoshima Olive Park","Check official information and current access before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%B0%8F%E8%B1%86%E5%B3%B6%E3%82%AA%E3%83%AA%E3%83%BC%E3%83%96%E5%85%AC%E5%9C%92%E3%81%A7%E6%98%BC%E9%A3%9F%2C+Japan"]]},{"type":"break","duration":45,"choices":[["Olive Park olive groves","Check official information and current access before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%B0%8F%E8%B1%86%E5%B3%B6%E3%82%AA%E3%83%AA%E3%83%BC%E3%83%96%E5%85%AC%E5%9C%92%E3%81%AE%E3%82%AA%E3%83%AA%E3%83%BC%E3%83%96%E7%95%91%2C+Japan"]]}]},{"id":"sns-motonosumi","prefecture":"yamaguchi","label":"Yamaguchi · Motonosumi red gates & sea","title":"Yamaguchi · Motonosumi red gates & sea","description":"See the coastal red gates featured in international travel guides.","area":"yamaguchi","gap":15,"stops":[{"type":"sight","duration":55,"choices":[["Motonosumi Shrine","Check official information and current access before visiting.","https://nanavi.jp/sightseeing/motonosumiinarijinja/"]]},{"type":"walk","duration":30,"choices":[["Motonosumi torii path","Check official information and current access before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%85%83%E4%B9%83%E9%9A%85%E7%A5%9E%E7%A4%BE%E3%81%AE%E9%B3%A5%E5%B1%85%E5%8F%82%E9%81%93%2C+Japan"]]},{"type":"food","duration":60,"choices":[["Lunch near Motonosumi Shrine","Check official information and current access before visiting.","https://www.google.com/maps/search/?api=1&query=%E5%85%83%E4%B9%83%E9%9A%85%E7%A5%9E%E7%A4%BE%E5%91%A8%E8%BE%BA%E3%81%A7%E6%98%BC%E9%A3%9F%2C+Japan"]]},{"type":"break","duration":30,"choices":[["Ryugu sea-spray viewpoint","Check official information and current access before visiting.","https://www.google.com/maps/search/?api=1&query=%E9%BE%8D%E5%AE%AE%E3%81%AE%E6%BD%AE%E5%90%B9%E3%81%AE%E5%B1%95%E6%9C%9B%E5%A0%B4%E6%89%80%2C+Japan"]]}]},{"id":"sns-takachiho","prefecture":"miyazaki","label":"Miyazaki · Takachiho Gorge & shrine","title":"Miyazaki · Takachiho Gorge & shrine","description":"View Manai Falls and the gorge from paths and viewpoints, with a stop at Takachiho Shrine.","area":"miyazaki","gap":25,"stops":[{"type":"sight","duration":40,"choices":[["Takachiho Shrine","Check official information and current access before visiting.","https://www.google.com/maps/search/?api=1&query=%E9%AB%98%E5%8D%83%E7%A9%82%E7%A5%9E%E7%A4%BE%2C+Japan"]]},{"type":"food","duration":60,"choices":[["Lunch in central Takachiho","Check official information and current access before visiting.","https://www.google.com/maps/search/?api=1&query=%E9%AB%98%E5%8D%83%E7%A9%82%E7%94%BA%E4%B8%AD%E5%BF%83%E9%83%A8%E3%81%A7%E6%98%BC%E9%A3%9F%2C+Japan"]]},{"type":"walk","duration":60,"choices":[["Takachiho Gorge paths","Check official information and current access before visiting.","https://takachiho-kanko.info/sightseeing/18/"]]},{"type":"break","duration":30,"choices":[["Manai Falls viewpoint","Check official information and current access before visiting.","https://takachiho-kanko.info/boat/"]]}]}]
"""#
        guard let result = try? JSONDecoder().decode([DayRoute].self, from: Data(json.utf8)) else { preconditionFailure("Invalid featured routes") }
        return result
    }()
    static let info: [String: FeaturedRouteInfo] = {
        let json = #"""
{"sns-gotokuji":{"fields":[["東京・豪徳寺の招き猫と世田谷線","東京・豪徳寺の招き猫と世田谷線","招き猫が海外SNSで話題の豪徳寺から、世田谷の商店街へ。","東京・豪徳寺の招き猫と世田谷線"],["도쿄·고토쿠지 고양이와 세타가야선","도쿄·고토쿠지 고양이와 세타가야선","해외 SNS에서 주목받는 고토쿠지와 세타가야 상점가.","도쿄·고토쿠지 고양이와 세타가야선"],["东京·豪德寺招财猫与世田谷线","东京·豪德寺招财猫与世田谷线","从海外社交媒体关注的豪德寺，游览世田谷商店街。","东京·豪德寺招财猫与世田谷线"],["Tokyo · Lucky cats & Setagaya tram","Tokyo · Lucky cats & Setagaya tram","Visit the temple whose lucky cats drew overseas social media attention, then local shopping streets.","Tokyo · Lucky cats & Setagaya tram"],["โตเกียว·แมวกวักและรถรางเซตากายะ","โตเกียว·แมวกวักและรถรางเซตากายะ","ชมแมวกวักที่เป็นที่สนใจบนโซเชียลต่างประเทศแล้วเดินย่านร้านค้าท้องถิ่น","โตเกียว·แมวกวักและรถรางเซตากายะ"]],"notes":["宮の坂駅から徒歩約5分。招き猫は動かさず、住宅街では通行の妨げにならないように。","미야노사카역에서 도보 약 5분. 고양이상을 옮기지 말고 주거지 통행을 방해하지 마세요.","宫之坂站步行约5分钟。请勿移动猫像或妨碍住宅区通行。","About 5 minutes on foot from Miyanosaka Station. Leave cat figures in place and keep residential paths clear.","เดินประมาณ 5 นาทีจากสถานีมิยาโนะซากะ ไม่เคลื่อนย้ายรูปแมวและไม่กีดขวางทาง"],"accessURL":"https://gotokuji.jp/","sourceURL":"https://www.fnn.jp/articles/-/965434"},"sns-katsuoji":{"fields":[["大阪・勝尾寺のだるまと箕面","大阪・勝尾寺のだるまと箕面","外国人旅行者にも人気の勝尾寺と、箕面の駅前・滝道入口を巡る。","大阪・勝尾寺のだるまと箕面"],["오사카·가쓰오지 달마와 미노오","오사카·가쓰오지 달마와 미노오","외국인에게도 인기 있는 가쓰오지와 미노오 역·산책로 입구.","오사카·가쓰오지 달마와 미노오"],["大阪·胜尾寺达摩与箕面","大阪·胜尾寺达摩与箕面","游览海外游客喜爱的胜尾寺及箕面站与瀑布步道入口。","大阪·胜尾寺达摩与箕面"],["Osaka · Katsuoji daruma & Minoh","Osaka · Katsuoji daruma & Minoh","Explore Katsuoji, popular with international visitors, then Minoh Station and the waterfall trail entrance.","Osaka · Katsuoji daruma & Minoh"],["โอซาก้า·ดารุมะวัดคัตสึโอจิและมิโน","โอซาก้า·ดารุมะวัดคัตสึโอจิและมิโน","ชมวัดคัตสึโอจิที่นักท่องเที่ยวต่างชาติชื่นชอบแล้วเดินบริเวณสถานีมิโน","โอซาก้า·ดารุมะวัดคัตสึโอจิและมิโน"]],"notes":["勝尾寺へは箕面萱野駅からバス。寺から箕面駅周辺は公共交通・タクシーの経路を確認。山道の徒歩移動を前提にしません。","미노오카야노역에서 버스. 사찰에서 미노오역까지 대중교통·택시 경로를 확인하세요. 산길 도보 코스가 아닙니다.","从箕面萱野站乘巴士。寺院到箕面站请查看公交或出租车路线，不按山路步行安排。","Take a bus from Minoh-kayano. Check transit or taxi routing to Minoh Station; this plan does not assume walking mountain roads.","นั่งรถบัสจากมิโนคายาโนะ ตรวจสอบขนส่งหรือแท็กซี่ไปสถานีมิโน ไม่วางแผนเดินถนนบนเขา"],"accessURL":"https://katsuo-ji-temple.or.jp/access/index.php","sourceURL":"https://prtimes.jp/main/html/rd/p/000000030.000111535.html"},"sns-okusaga":{"fields":[["京都・奥嵯峨の羅漢と古い街並み","京都・奥嵯峨の羅漢と古い街並み","海外旅行者が注目する愛宕念仏寺から、嵯峨鳥居本を下る散策。","京都・奥嵯峨の羅漢と古い街並み"],["교토·오쿠사가 석상과 옛 거리","교토·오쿠사가 석상과 옛 거리","해외 여행자가 주목하는 오타기넨부쓰지에서 사가토리이모토로 내려가는 산책.","교토·오쿠사가 석상과 옛 거리"],["京都·奥嵯峨罗汉与古街","京都·奥嵯峨罗汉与古街","从海外游客关注的爱宕念佛寺，沿嵯峨鸟居本下行漫步。","京都·奥嵯峨罗汉与古街"],["Kyoto · Okusaga stone figures & old lanes","Kyoto · Okusaga stone figures & old lanes","Start at Otagi Nenbutsuji, attracting international visitors, and walk downhill through Saga Toriimoto.","Kyoto · Okusaga stone figures & old lanes"],["เกียวโต·รูปหินและถนนเก่าโอคุซากะ","เกียวโต·รูปหินและถนนเก่าโอคุซากะ","เริ่มวัดโอตากิเน็นบุตสึจิที่นักท่องเที่ยวต่างชาติสนใจแล้วเดินลงผ่านซากะโทริอิโมโตะ","เกียวโต·รูปหินและถนนเก่าโอคุซากะ"]],"notes":["寺へは先にバス・タクシーで上がり、帰りは下り坂。公式案内では水曜・土曜休み。訪問前に営業日を確認してください。","먼저 버스·택시로 올라가고 내려오는 코스입니다. 공식 안내는 수·토 휴무. 방문 전 확인하세요.","先乘巴士或出租车上山，再沿下坡游览。官网目前周三、周六休息，出发前请确认。","Go uphill by bus or taxi, then walk downhill. The official site currently lists Wednesday and Saturday closures; recheck before visiting.","ขึ้นไปด้วยรถบัสหรือแท็กซี่แล้วเดินลง เว็บไซต์แจ้งหยุดพุธและเสาร์ ตรวจสอบก่อนเดินทาง"],"accessURL":"https://www.otagiji.com/visit-jp","sourceURL":"https://mezamashi.media/articles/-/186389"},"sns-chichibugahama":{"fields":[["香川・父母ヶ浜の天空の鏡と仁尾","香川・父母ヶ浜の天空の鏡と仁尾","海外SNSでも注目される父母ヶ浜へ。仁尾の港町散策と海辺の写真を楽しむ。","香川・父母ヶ浜の天空の鏡と仁尾"],["가가와·지치부가하마 거울 바다와 니오","가가와·지치부가하마 거울 바다와 니오","해외 SNS에서도 주목받는 해변. 니오 항구 산책과 바다 사진.","가가와·지치부가하마 거울 바다와 니오"],["香川·父母之滨天空之镜与仁尾","香川·父母之滨天空之镜与仁尾","前往海外社交媒体关注的海滩，漫步仁尾港镇并欣赏海景。","香川·父母之滨天空之镜与仁尾"],["Kagawa · Chichibugahama mirror beach & Nio","Kagawa · Chichibugahama mirror beach & Nio","Explore Nio port town and the beach attracting international social media attention.","Kagawa · Chichibugahama mirror beach & Nio"],["คางาวะ·หาดกระจกจิจิบุกาฮามะและนิโอ","คางาวะ·หาดกระจกจิจิบุกาฮามะและนิโอ","เดินเมืองท่านิโอและชมหาดที่ได้รับความสนใจบนโซเชียลต่างประเทศ","คางาวะ·หาดกระจกจิจิบุกาฮามะและนิโอ"]],"notes":["天空の鏡は干潮・日没・弱い風が条件。表示時刻は目安なので、公式カレンダーに合わせて出発時間を調整。帰りの交通も先に確認。","거울 풍경은 간조·일몰·약한 바람이 조건입니다. 시간은 예시이므로 공식 달력에 맞춰 출발을 조정하고 귀가 교통도 확인하세요.","镜面景观需退潮、日落与微风。行程时间为参考，请按官网日历调整出发时间并提前确认返程交通。","Mirror photos need low tide, sunset and calm wind. Times are estimates: adjust departure to the official calendar and check return transport.","ภาพกระจกต้องช่วงน้ำลง พระอาทิตย์ตก และลมสงบ เวลาเป็นประมาณการ ปรับตามปฏิทินและตรวจสอบรถกลับ"],"accessURL":"https://www.mitoyo-kanko.com/chichibugahama/","sourceURL":"https://www.mitoyo-kanko.com/author/mitoyokokusaikanko/"},"sns-ginzan":{"fields":[["山形・銀山温泉のレトロな街並み","山形・銀山温泉のレトロな街並み","木造旅館が並ぶ温泉街と銀山川を散策。白銀公園は通行状況を確認して訪問。","山形・銀山温泉のレトロな街並み"],["야마가타·긴잔온천 옛 거리","야마가타·긴잔온천 옛 거리","목조 료칸과 긴잔강을 산책하고 시로가네 공원은 통행 상황을 확인하세요.","야마가타·긴잔온천 옛 거리"],["山形·银山温泉复古街景","山形·银山温泉复古街景","漫步木造旅馆与银山川；先确认白银公园的通行情况。","山形·银山温泉复古街景"],["Yamagata · Ginzan Onsen old town","Yamagata · Ginzan Onsen old town","Walk past wooden inns along the Ginzan River; check park access before exploring Shirogane Park.","Yamagata · Ginzan Onsen old town"],["ยามากาตะ·ย่านเก่าออนเซ็นกินซัน","ยามากาตะ·ย่านเก่าออนเซ็นกินซัน","เดินชมเรียวกังไม้ริมแม่น้ำกินซัน ตรวจสอบทางเข้าก่อนเที่ยวสวนชิโรกาเนะ","ยามากาตะ·ย่านเก่าออนเซ็นกินซัน"]],"notes":["大石田駅からバスで移動。帰りの最終便、冬の入場・車両規制、店舗営業を公式で確認。夜景を見る場合は宿泊や帰路を先に確保し、積雪時は公園散策を省略。","오이시다역에서 버스. 막차·겨울 입장 및 차량 제한·영업을 확인하세요. 야경은 숙박이나 귀가편을 먼저 확보하고 눈이 쌓이면 공원을 생략하세요.","从大石田站乘巴士。确认末班车、冬季入场及车辆限制和商店营业。看夜景须提前安排住宿或返程；积雪时略过公园。","Take the bus from Oishida Station. Check the last return bus, winter entry and vehicle restrictions, and shop hours. Arrange lodging or a return trip for evening views; skip park trails in snow.","นั่งรถบัสจากสถานีโออิชิดะ ตรวจสอบรถกลับเที่ยวสุดท้าย ข้อจำกัดฤดูหนาวและเวลาเปิดร้าน หากชมกลางคืนให้จัดที่พักหรือรถกลับก่อน งดเดินสวนเมื่อมีหิมะ"],"accessURL":"https://www.ginzanonsen.jp/index.html","sourceURL":"https://www.japan.travel/en/spot/1798/"},"sns-fujiyoshida":{"fields":[["山梨・本町通りの富士山と新倉山","山梨・本町通りの富士山と新倉山","SNSで話題の富士山と商店街の景色へ。下吉田から新倉山の展望を巡る。","山梨・本町通りの富士山と新倉山"],["야마나시·혼초도리 후지산과 아라쿠라야마","야마나시·혼초도리 후지산과 아라쿠라야마","SNS에서 화제인 후지산과 상점가 풍경, 시모요시다와 아라쿠라야마 전망.","야마나시·혼초도리 후지산과 아라쿠라야마"],["山梨·本町通富士山与新仓山","山梨·本町通富士山与新仓山","游览社交媒体热议的富士山商店街景色与新仓山展望。","山梨·本町通富士山与新仓山"],["Yamanashi · Honcho Street & Arakurayama","Yamanashi · Honcho Street & Arakurayama","Explore the Fuji street view highlighted by the local tourism guide, then Arakurayama viewpoints.","Yamanashi · Honcho Street & Arakurayama"],["ยามานาชิ·ถนนฮอนโจและอาราคุระยามะ","ยามานาชิ·ถนนฮอนโจและอาราคุระยามะ","ชมวิวฟูจิและย่านร้านค้าที่ได้รับความสนใจบนโซเชียล แล้วไปจุดชมวิวอาราคุระยามะ","ยามานาชิ·ถนนฮอนโจและอาราคุระยามะ"]],"notes":["下吉田駅から徒歩で街へ。撮影は歩道から行い、車道に立ち止まらないでください。富士山は天候次第。新倉山は階段・坂が多いため、体力や混雑に合わせて省略できます。","시모요시다역에서 도보. 인도에서 촬영하고 차도에 멈추지 마세요. 후지산은 날씨에 따라 보입니다. 아라쿠라야마는 계단과 경사가 많아 혼잡·체력에 따라 생략하세요.","从下吉田站步行入街；在步道拍照，不在车道停留。富士山能见度取决于天气。新仓山台阶及坡道多，可按体力和拥挤程度省略。","Walk from Shimoyoshida Station. Photograph from sidewalks and keep roads clear. Fuji visibility depends on weather. Arakurayama has many steps and slopes; skip it if crowds or fitness make it unsuitable.","เดินจากสถานีชิโมโยชิดะ ถ่ายภาพจากทางเท้า อย่ายืนบนถนน วิวฟูจิขึ้นกับอากาศ อาราคุระยามะมีบันไดและทางลาดมาก สามารถข้ามตามกำลังและความหนาแน่น"],"accessURL":"https://fujiyoshida.net/spot/index.php?p=410","sourceURL":"https://fujiyoshida.net/spot/index.php?p=410"},"sns-biei":{"fields":[["北海道・美瑛の青い池と白ひげの滝","北海道・美瑛の青い池と白ひげの滝","青い水面と立ち枯れの木々、白ひげの滝を巡る白金エリアの写真散策。","北海道・美瑛の青い池と白ひげの滝"],["홋카이도·비에이 푸른 연못과 시라히게 폭포","홋카이도·비에이 푸른 연못과 시라히게 폭포","푸른 수면과 고사목, 시라히게 폭포를 둘러보는 시로가네 사진 코스.","홋카이도·비에이 푸른 연못과 시라히게 폭포"],["北海道·美瑛青池与白须瀑布","北海道·美瑛青池与白须瀑布","游览青色水面、枯木与白须瀑布的白金地区摄影路线。","北海道·美瑛青池与白须瀑布"],["Hokkaido · Biei Blue Pond & Shirahige Falls","Hokkaido · Biei Blue Pond & Shirahige Falls","Explore Shirogane scenery: the blue pond, standing trees and Shirahige Falls.","Hokkaido · Biei Blue Pond & Shirahige Falls"],["ฮอกไกโด·บ่อน้ำสีฟ้าบิเอะและน้ำตกชิราฮิเงะ","ฮอกไกโด·บ่อน้ำสีฟ้าบิเอะและน้ำตกชิราฮิเงะ","เที่ยวถ่ายภาพย่านชิโรกาเนะ ชมบ่อน้ำสีฟ้า ต้นไม้ และน้ำตกชิราฮิเงะ","ฮอกไกโด·บ่อน้ำสีฟ้าบิเอะและน้ำตกชิราฮิเงะ"]],"notes":["美瑛駅から白金方面のバス・タクシー・車を確認。青い池と滝の間は車両移動を基本にし、徒歩前提にしません。水の色や冬の見え方は天候・季節次第。立入禁止区域には入らないでください。","비에이역에서 시로가네 방향 버스·택시·차량을 확인하세요. 연못과 폭포 사이는 차량 이동을 기본으로 합니다. 물빛과 겨울 풍경은 날씨·계절에 따라 다릅니다. 통제구역에 들어가지 마세요.","确认美瑛站前往白金方向的巴士、出租车或自驾路线。青池至瀑布以车辆移动为主。水色及冬季景观随天气、季节变化；勿进入禁止区域。","Check buses, taxis or driving from Biei Station toward Shirogane. Use vehicle transport between the pond and falls. Water color and winter views vary with weather and season. Respect closed areas.","ตรวจสอบรถบัส แท็กซี่ หรือรถจากสถานีบิเอะไปชิโรกาเนะ ใช้รถระหว่างบ่อน้ำกับน้ำตก สีและวิวฤดูหนาวขึ้นกับอากาศและฤดูกาล ห้ามเข้าพื้นที่ปิด"],"accessURL":"https://www.biei-hokkaido.jp/ja/shirogane-blue-pond","sourceURL":"https://www.biei-hokkaido.jp/en/shirogane-blue-pond"},"sns-shodoshima":{"fields":[["香川・小豆島の風車と魔法のほうき","香川・小豆島の風車と魔法のほうき","オリーブ公園で海を見渡す風車と、ほうきを使った記念写真を楽しむ。","香川・小豆島の風車と魔法のほうき"],["가가와·쇼도시마 풍차와 마법 빗자루","가가와·쇼도시마 풍차와 마법 빗자루","올리브 공원에서 바다가 보이는 풍차와 빗자루 기념사진을 즐기세요.","가가와·쇼도시마 풍차와 마법 빗자루"],["香川·小豆岛风车与魔法扫帚","香川·小豆岛风车与魔法扫帚","在橄榄公园欣赏海景风车，体验扫帚纪念摄影。","香川·小豆岛风车与魔法扫帚"],["Kagawa · Shodoshima windmill & magic broom","Kagawa · Shodoshima windmill & magic broom","Enjoy the sea-view windmill and broom photos within Shodoshima Olive Park.","Kagawa · Shodoshima windmill & magic broom"],["คางาวะ·กังหันลมและไม้กวาดวิเศษโชโดชิมะ","คางาวะ·กังหันลมและไม้กวาดวิเศษโชโดชิมะ","ชมกังหันลมวิวทะเลและถ่ายภาพไม้กวาดในสวนโอลีฟโชโดชิมะ","คางาวะ·กังหันลมและไม้กวาดวิเศษโชโดชิมะ"]],"notes":["小豆島へはフェリーで移動し、港から公園までは島内バス・車を確認。貸出ほうきは園内で使い、返却してください。風が強い日は無理なジャンプ撮影を避け、帰りのフェリー時刻も確認。","페리로 쇼도시마에 도착 후 항구에서 공원까지 버스·차량을 확인하세요. 대여 빗자루는 공원 안에서 쓰고 반납하세요. 강풍 시 무리한 점프 촬영을 피하고 귀가 페리 시간을 확인하세요.","乘渡轮到小豆岛，确认港口至公园的岛内巴士或车辆路线。借用扫帚仅在园内使用并归还；强风时避免勉强跳跃拍照，提前确认返程渡轮。","Reach Shodoshima by ferry, then check island buses or driving to the park. Use borrowed brooms within the park and return them. Avoid risky jumping photos in strong wind and check the return ferry.","นั่งเรือเฟอร์รีไปโชโดชิมะ แล้วตรวจรถบัสหรือรถจากท่าเรือถึงสวน ใช้ไม้กวาดยืมเฉพาะในสวนและคืน หลีกเลี่ยงกระโดดถ่ายภาพเมื่อมีลมแรง และเช็กเรือกลับ"],"accessURL":"https://www.olive-pk.jp/","sourceURL":"https://www.olive-pk.jp/en/broom/index.html"},"sns-motonosumi":{"fields":[["山口・元乃隅神社の赤い鳥居と海","山口・元乃隅神社の赤い鳥居と海","海外の旅行案内でも紹介される、海に向かって並ぶ赤い鳥居の景色へ。","山口・元乃隅神社の赤い鳥居と海"],["야마구치·모토노스미 신사 붉은 도리이와 바다","야마구치·모토노스미 신사 붉은 도리이와 바다","해외 여행 안내에도 소개되는 바다를 향해 늘어선 붉은 도리이 풍경.","야마구치·모토노스미 신사 붉은 도리이와 바다"],["山口·元乃隅神社红色鸟居与海","山口·元乃隅神社红色鸟居与海","游览海外旅行指南介绍的海边红色鸟居景色。","山口·元乃隅神社红色鸟居与海"],["Yamaguchi · Motonosumi red gates & sea","Yamaguchi · Motonosumi red gates & sea","See the coastal red gates featured in international travel guides.","Yamaguchi · Motonosumi red gates & sea"],["ยามากุจิ·เสาโทริอิสีแดงและทะเลโมโตโนสุมิ","ยามากุจิ·เสาโทริอิสีแดงและทะเลโมโตโนสุมิ","ชมเสาโทริอิสีแดงริมทะเลที่ได้รับการแนะนำในคู่มือท่องเที่ยวต่างประเทศ","ยามากุจิ·เสาโทริอิสีแดงและทะเลโมโตโนสุมิ"]],"notes":["長門古市駅などからタクシー・車を手配。駅から徒歩で行くコースではありません。海沿いは強風に注意し、柵を越えず、立入制限に従ってください。飲食店の営業と帰りの車も先に確認。","나가토후루이치역 등에서 택시·차량을 준비하세요. 역에서 도보 코스가 아닙니다. 해안 강풍에 주의하고 울타리를 넘지 마세요. 식당 영업과 귀가 차량도 확인하세요.","从长门古市站等安排出租车或自驾，并非从车站步行路线。注意海岸强风，勿越过围栏，遵守通行限制；先确认餐厅营业及返程车辆。","Arrange a taxi or car from Nagato-Furuichi or another station. This is not a station-to-shrine walking route. Watch coastal winds, stay behind barriers and follow closures. Confirm food options and return transport.","จัดแท็กซี่หรือรถจากสถานีนางาโตะฟุรุอิจิหรือสถานีอื่น ไม่ใช่เส้นทางเดินจากสถานี ระวังลมชายฝั่ง ห้ามข้ามรั้วและปฏิบัติตามป้ายปิด ตรวจร้านอาหารและรถกลับก่อน"],"accessURL":"https://nanavi.jp/sightseeing/motonosumiinarijinja/","sourceURL":"https://www.japan.travel/en/spot/866/"},"sns-takachiho":{"fields":[["宮崎・高千穂峡の滝と神社","宮崎・高千穂峡の滝と神社","真名井の滝と峡谷の景色を、歩道・展望場所から楽しむ。高千穂神社にも立ち寄る。","宮崎・高千穂峡の滝と神社"],["미야자키·다카치호협곡 폭포와 신사","미야자키·다카치호협곡 폭포와 신사","산책로와 전망 장소에서 마나이 폭포와 협곡을 보고 다카치호 신사에도 들르세요.","미야자키·다카치호협곡 폭포와 신사"],["宫崎·高千穗峡瀑布与神社","宫崎·高千穗峡瀑布与神社","从步道及观景处欣赏真名井瀑布与峡谷，并参访高千穗神社。","宫崎·高千穗峡瀑布与神社"],["Miyazaki · Takachiho Gorge & shrine","Miyazaki · Takachiho Gorge & shrine","View Manai Falls and the gorge from paths and viewpoints, with a stop at Takachiho Shrine.","Miyazaki · Takachiho Gorge & shrine"],["มิยาซากิ·หุบเขาทาคาจิโฮะและศาลเจ้า","มิยาซากิ·หุบเขาทาคาจิโฮะและศาลเจ้า","ชมวิวหุบเขาและน้ำตกมานาอิจากทางเดินและจุดชมวิว พร้อมแวะศาลเจ้าทาคาจิโฮะ","มิยาซากิ·หุบเขาทาคาจิโฮะและศาลเจ้า"]],"notes":["高千穂バスセンターから神社・峡谷への交通を確認。峡谷には坂・階段があり、遊歩道の通行状況も確認。ボートは別途予約・運航確認が必要で、このコースの所要時間には含めていません。","다카치호 버스센터에서 신사·협곡까지 교통을 확인하세요. 경사·계단과 산책로 통제를 확인하세요. 보트는 별도 예약·운항 확인이 필요하며 코스 시간에 포함하지 않습니다.","确认高千穗巴士中心至神社及峡谷的交通。峡谷有坡道及台阶，须确认步道开放情况。游船需另行预约并确认运营，不计入本路线时间。","Check transport from Takachiho Bus Center to the shrine and gorge. Expect slopes and stairs; check path closures. Boats need separate reservation and operating checks and are not included in the route time.","ตรวจการเดินทางจากศูนย์รถบัสทาคาจิโฮะไปศาลเจ้าและหุบเขา มีทางลาดและบันได ให้ตรวจทางเดินที่เปิด เรือจำเป็นต้องจองและตรวจการเดินเรือแยก เวลาล่องเรือไม่รวมในเส้นทาง"],"accessURL":"https://takachiho-kanko.info/boat/detail.php","sourceURL":"https://www.japan.travel/en/spot/615/"}}
"""#
        guard let result = try? JSONDecoder().decode([String: FeaturedRouteInfo].self, from: Data(json.utf8)) else { preconditionFailure("Invalid featured info") }
        return result
    }()
    static let names: [String: [String]] = {
        let json = #"""
{"Gotokuji Temple":["豪徳寺","고토쿠지","豪德寺","Gotokuji Temple","วัดโกโทคุจิ"],"Gotokuji shopping street":["豪徳寺商店街","고토쿠지 상점가","豪德寺商店街","Gotokuji shopping street","ย่านร้านค้าโกโทคุจิ"],"Sangenjaya shopping streets":["三軒茶屋の商店街","산겐자야 상점가","三轩茶屋商店街","Sangenjaya shopping streets","ย่านร้านค้าซังเก็นจายะ"],"Katsuoji Temple":["勝尾寺","가쓰오지","胜尾寺","Katsuoji Temple","วัดคัตสึโอจิ"],"Minoh Station shopping street":["箕面駅前商店街","미노오역 상점가","箕面站前商店街","Minoh Station shopping street","ย่านร้านค้าสถานีมิโน"],"Minoh waterfall trail entrance":["箕面滝道入口","미노오 폭포 산책로 입구","箕面瀑布步道入口","Minoh waterfall trail entrance","ทางเข้าทางเดินน้ำตกมิโน"],"Otagi Nenbutsuji Temple":["愛宕念仏寺","오타기넨부쓰지","爱宕念佛寺","Otagi Nenbutsuji Temple","วัดโอตากิเน็นบุตสึจิ"],"Saga Toriimoto preserved street":["嵯峨鳥居本町並み保存地区","사가토리이모토 옛 거리","嵯峨鸟居本传统街区","Saga Toriimoto preserved street","ถนนอนุรักษ์ซากะโทริอิโมโตะ"],"Adashino Nenbutsuji Temple":["化野念仏寺","아다시노넨부쓰지","化野念佛寺","Adashino Nenbutsuji Temple","วัดอาดาชิโนะเน็นบุตสึจิ"],"Saga Arashiyama Station":["嵯峨嵐山駅","사가아라시야마역","嵯峨岚山站","Saga Arashiyama Station","สถานีซากะอาราชิยามะ"],"Nio port town":["仁尾の港町","니오 항구마을","仁尾港镇","Nio port town","เมืองท่านิโอ"],"Nio Hachiman Shrine":["仁尾八幡神社","니오하치만 신사","仁尾八幡神社","Nio Hachiman Shrine","ศาลเจ้านิโอฮาจิมัง"],"Chichibugahama Beach":["父母ヶ浜","지치부가하마","父母之滨","Chichibugahama Beach","หาดจิจิบุกาฮามะ"],"Ginzan Onsen town":["銀山温泉街","긴잔온천 거리","银山温泉街","Ginzan Onsen town","ย่านออนเซ็นกินซัน"],"Ginzan River bridges":["銀山川の橋と遊歩道","긴잔강 다리와 산책길","银山川桥梁与步道","Ginzan River bridges","สะพานริมแม่น้ำกินซัน"],"Lunch in Ginzan Onsen":["銀山温泉街で昼食","긴잔온천에서 점심","银山温泉街午餐","Lunch in Ginzan Onsen","อาหารกลางวันในออนเซ็นกินซัน"],"Shirogane Park entrance":["白銀公園入口","시로가네 공원 입구","白银公园入口","Shirogane Park entrance","ทางเข้าสวนชิโรกาเนะ"],"Shimoyoshida Station":["下吉田駅","시모요시다역","下吉田站","Shimoyoshida Station","สถานีชิโมโยชิดะ"],"Honcho Street (Fujimichi)":["本町通り（富士みち）","혼초도리(후지미치)","本町通（富士道）","Honcho Street (Fujimichi)","ถนนฮอนโจ (ฟูจิมิจิ)"],"Lunch in Shimoyoshida":["下吉田の商店街で昼食","시모요시다 상점가 점심","下吉田商店街午餐","Lunch in Shimoyoshida","อาหารกลางวันในชิโมโยชิดะ"],"Arakurayama Sengen Park":["新倉山浅間公園","아라쿠라야마 센겐 공원","新仓山浅间公园","Arakurayama Sengen Park","สวนอาราคุระยามะเซ็นเก็น"],"Shirogane Blue Pond":["白金青い池","시로가네 푸른 연못","白金青池","Shirogane Blue Pond","บ่อน้ำสีฟ้าชิโรกาเนะ"],"Shirahige Falls":["白ひげの滝","시라히게 폭포","白须瀑布","Shirahige Falls","น้ำตกชิราฮิเงะ"],"Lunch in Biei Shirogane Onsen":["美瑛白金温泉で昼食","비에이 시로가네온천 점심","美瑛白金温泉午餐","Lunch in Biei Shirogane Onsen","อาหารกลางวันในออนเซ็นชิโรกาเนะบิเอะ"],"Biei Shirogane Birke roadside station":["道の駅びえい白金ビルケ","미치노에키 비에이 시로가네 비르케","美瑛白金Birke道之站","Biei Shirogane Birke roadside station","จุดพักรถบิเอะชิโรกาเนะบีร์เค"],"Shodoshima Olive Park":["小豆島オリーブ公園","쇼도시마 올리브 공원","小豆岛橄榄公园","Shodoshima Olive Park","สวนโอลีฟโชโดชิมะ"],"Olive Park Greek windmill":["小豆島オリーブ公園のギリシャ風車","쇼도시마 올리브 공원 그리스 풍차","小豆岛橄榄公园希腊风车","Olive Park Greek windmill","กังหันลมกรีกในสวนโอลีฟ"],"Lunch at Shodoshima Olive Park":["小豆島オリーブ公園で昼食","쇼도시마 올리브 공원 점심","小豆岛橄榄公园午餐","Lunch at Shodoshima Olive Park","อาหารกลางวันในสวนโอลีฟโชโดชิมะ"],"Olive Park olive groves":["小豆島オリーブ公園のオリーブ畑","쇼도시마 올리브 공원 올리브밭","小豆岛橄榄公园橄榄园","Olive Park olive groves","สวนมะกอกในสวนโอลีฟโชโดชิมะ"],"Motonosumi Shrine":["元乃隅神社","모토노스미 신사","元乃隅神社","Motonosumi Shrine","ศาลเจ้าโมโตโนสุมิ"],"Motonosumi torii path":["元乃隅神社の鳥居参道","모토노스미 신사 도리이 길","元乃隅神社鸟居参道","Motonosumi torii path","ทางเดินโทริอิศาลเจ้าโมโตโนสุมิ"],"Lunch near Motonosumi Shrine":["元乃隅神社周辺で昼食","모토노스미 신사 주변 점심","元乃隅神社周边午餐","Lunch near Motonosumi Shrine","อาหารกลางวันใกล้ศาลเจ้าโมโตโนสุมิ"],"Ryugu sea-spray viewpoint":["龍宮の潮吹の展望場所","류구노시오후키 전망 장소","龙宫潮吹观景处","Ryugu sea-spray viewpoint","จุดชมวิวริวกุโนะชิโอฟุกิ"],"Takachiho Shrine":["高千穂神社","다카치호 신사","高千穗神社","Takachiho Shrine","ศาลเจ้าทาคาจิโฮะ"],"Lunch in central Takachiho":["高千穂町中心部で昼食","다카치호 중심가 점심","高千穗町中心午餐","Lunch in central Takachiho","อาหารกลางวันในใจกลางทาคาจิโฮะ"],"Takachiho Gorge paths":["高千穂峡の遊歩道","다카치호협곡 산책로","高千穗峡步道","Takachiho Gorge paths","ทางเดินหุบเขาทาคาจิโฮะ"],"Manai Falls viewpoint":["真名井の滝の展望場所","마나이 폭포 전망 장소","真名井瀑布观景处","Manai Falls viewpoint","จุดชมวิวน้ำตกมานาอิ"]}
"""#
        guard let result = try? JSONDecoder().decode([String: [String]].self, from: Data(json.utf8)) else { preconditionFailure("Invalid featured names") }
        return result
    }()
    static let ui: [String: [String]] = {
        let json = #"""
{"featured":["SNS・海外旅行者の注目コース10選","SNS·해외 여행자 주목 코스 10선","社交媒体与海外游客关注路线10选","10 social media & international visitor picks","10 เส้นทางน่าสนใจจากโซเชียลและนักท่องเที่ยวต่างชาติ"],"featuredNote":["10コースのボタンから直接選べます。SNSで話題の場所・海外旅行者向けの写真スポットを選定。番号は一覧順で、投稿数による人気順位ではありません。","10개 코스 버튼에서 바로 선택하세요. SNS 화제 장소와 해외 여행객 사진 명소를 선정했습니다. 번호는 목록 순서이며 게시물 수 순위가 아닙니다.","直接点击10条路线选择。精选社交媒体话题景点与海外游客摄影景点。编号为列表顺序，不是按帖子数排名。","Choose directly from 10 course buttons. Selected social media highlights and photo spots for international visitors. Numbers show list order, not a ranking by post counts.","เลือกได้โดยตรงจากปุ่ม 10 เส้นทาง คัดเลือกสถานที่บนโซเชียลและจุดถ่ายภาพสำหรับนักท่องเที่ยวต่างชาติ ตัวเลขเป็นลำดับรายการ ไม่ใช่อันดับจำนวนโพสต์"],"access":["営業時間・交通・撮影条件を確認","운영 시간·교통·촬영 조건 확인","查看开放时间、交通与拍摄条件","Check hours, access & photo conditions","ตรวจสอบเวลา การเดินทาง และเงื่อนไขถ่ายภาพ"],"source":["注目されている理由・調査元","주목받는 이유·출처","关注原因与资料来源","Why it is featured · source","เหตุผลที่ได้รับความสนใจและแหล่งข้อมูล"],"visitNote":["営業時間や撮影ルールは公式情報で確認。移動は下の徒歩・公共交通リンクから。","공식 운영 시간과 촬영 규칙을 확인하세요. 아래 도보·대중교통 링크를 이용하세요.","请在官网查看开放时间与拍摄规则。下方提供步行和公共交通路线。","Check official hours and photo rules. Use the walking and transit links below.","ตรวจสอบเวลาเปิดและกฎถ่ายภาพ ใช้ลิงก์เดินหรือขนส่งสาธารณะด้านล่าง"]}
"""#
        guard let result = try? JSONDecoder().decode([String: [String]].self, from: Data(json.utf8)) else { preconditionFailure("Invalid featured ui") }
        return result
    }()
}


private enum OriginalCourseText {
    private static let strings: [String: [String]] = [
        "open": ["オリジナルコースを作る", "나만의 코스 만들기", "创建原创路线", "Create my own itinerary", "สร้างเส้นทางของฉัน"],
        "tagline": ["自分だけの旅へ", "나만의 여행으로", "开启专属旅程", "Your own journey", "ทริปในแบบของคุณ"],
        "entryNote": ["行きたい場所だけを選んで、観光・食事・ホテルを自由に組み立てられます。", "가고 싶은 곳만 골라 관광·식사·호텔을 자유롭게 구성할 수 있습니다.", "只选想去的地方，自由安排景点、餐饮与酒店。", "Choose only the places you want, and arrange sights, meals and your hotel freely.", "เลือกเฉพาะสถานที่ที่อยากไป แล้วจัดที่เที่ยว อาหาร และโรงแรมได้อย่างอิสระ"],
        "intro": ["ホテルと行き先を入力し、順番と滞在時間を調整してください。入力内容はこの端末に保存されます。", "호텔과 목적지를 입력하고 순서와 체류 시간을 조정하세요. 이 기기에 저장됩니다.", "输入酒店和目的地，调整顺序与停留时间。内容保存在此设备。", "Enter your hotel and stops, then adjust their order and visit times. Saved on this device.", "ป้อนโรงแรมและสถานที่ แล้วปรับลำดับและเวลาพัก ข้อมูลบันทึกในเครื่องนี้"],
        "hotel": ["ホテル", "호텔", "酒店", "Hotel", "โรงแรม"],
        "sight": ["観光", "관광", "观光", "Sightseeing", "เที่ยวชม"],
        "lunch": ["昼食", "점심", "午餐", "Lunch", "อาหารกลางวัน"],
        "dinner": ["夕食", "저녁", "晚餐", "Dinner", "อาหารเย็น"],
        "place": ["ホテル名・店名・観光地名を入力", "호텔·식당·관광지 이름 입력", "输入酒店、餐厅或景点名称", "Enter a hotel, restaurant or attraction", "ป้อนชื่อโรงแรม ร้านอาหาร หรือสถานที่"],
        "map": ["地図で場所を確認", "지도에서 장소 확인", "在地图中确认地点", "Check place on map", "ตรวจสอบสถานที่บนแผนที่"],
        "candidate": ["検索候補を選んで場所を確定", "검색 결과에서 장소 선택", "从搜索结果选择地点", "Select the correct search result", "เลือกสถานที่จากผลการค้นหา"],
        "unresolved": ["場所を確認できません。名前に住所・市区町村を加えてください。", "장소를 찾지 못했습니다. 주소나 지역을 추가하세요.", "无法确认地点，请添加地址或城市。", "Place not found. Add an address or city.", "ไม่พบสถานที่ กรุณาเพิ่มที่อยู่หรือเมือง"],
        "duration": ["滞在", "체류", "停留", "Visit", "พัก"],
        "arrival": ["予定", "예정", "计划", "Planned", "กำหนด"],
        "add": ["行き先を追加", "장소 추가", "添加地点", "Add a stop", "เพิ่มสถานที่"],
        "remove": ["削除", "삭제", "删除", "Remove", "ลบ"],
        "up": ["上へ", "위로", "上移", "Move up", "เลื่อนขึ้น"],
        "down": ["下へ", "아래로", "下移", "Move down", "เลื่อนลง"],
        "walk": ["徒歩", "도보", "步行", "Walk", "เดิน"],
        "taxi": ["車・タクシー", "차·택시", "汽车·出租车", "Car / taxi", "รถ/แท็กซี่"],
        "transit": ["電車・バス", "전철·버스", "铁路·巴士", "Transit", "ขนส่งสาธารณะ"],
        "approx": ["概算", "추정", "估算", "estimate", "ประมาณ"],
        "minutes": ["分", "분", "分钟", "min", "นาที"],
        "route": ["経路を開く", "경로 열기", "打开路线", "Open directions", "เปิดเส้นทาง"],
        "timeNote": ["時刻は到着の目安です。移動時間は地図の経路を優先し、取得できない徒歩・車は直線距離から概算します。交通機関の時刻・道路事情は地図で確認してください。", "도착 시각은 예상입니다. 도보와 차량은 경로가 없을 때 직선 거리로 추정합니다. 교통 시간표는 지도에서 확인하세요.", "到达时间为参考。步行及驾车无路线时按直线距离估算。请在地图核对班次与路况。", "Arrival times are estimates. Walking and driving fall back to straight-line distance when routing fails. Check services and traffic on the map.", "เวลาเป็นการประมาณ หากไม่พบเส้นทางเดินหรือรถจะคำนวณจากระยะตรง ตรวจสอบตารางเดินรถในแผนที่"],
        "return": ["ホテルへ戻る", "호텔로 돌아가기", "返回酒店", "Return to hotel", "กลับโรงแรม"],
        "choose": ["昼食・夕食の枠も観光に変更できます。時刻は15分ずつ調整できます。", "점심·저녁도 관광으로 변경할 수 있습니다. 시간은 15분씩 조정할 수 있습니다.", "午餐和晚餐时段也可改为观光，时间可按15分钟调整。", "Lunch and dinner slots can be sightseeing instead. Adjust times in 15-minute steps.", "ช่วงมื้ออาหารเปลี่ยนเป็นเที่ยวชมได้ ปรับเวลาทีละ 15 นาที"],
        "nearSight": ["近くの観光地", "근처 관광지", "附近景点", "Nearby sights", "ที่เที่ยวใกล้เคียง"],
        "nearLunch": ["近くで昼食", "근처 점심", "附近午餐", "Lunch nearby", "อาหารกลางวันใกล้ๆ"],
        "nearDinner": ["近くで夕食", "근처 저녁", "附近晚餐", "Dinner nearby", "อาหารเย็นใกล้ๆ"],
        "nearbyHint": ["この場所を起点に近くを検索", "이 장소 근처 검색", "以此地点搜索附近", "Search around this stop", "ค้นหาใกล้สถานที่นี้"],
        "searching": ["近くの場所を検索中…", "근처 장소 검색 중…", "正在搜索附近地点…", "Searching nearby…", "กำลังค้นหาสถานที่ใกล้เคียง…"],
        "nearEmpty": ["近くに候補が見つかりませんでした。地名を詳しく入力するか、地図で確認してください。", "근처 장소를 찾지 못했습니다. 장소 이름을 자세히 입력하세요.", "附近没有找到候选地点。请补充详细地址。", "No nearby results. Add a more precise place name or check the map.", "ไม่พบสถานที่ใกล้เคียง โปรดระบุชื่อให้ชัดเจนขึ้น"],
        "nearSelect": ["この場所をコースに追加", "이 장소를 코스에 추가", "将此地点加入路线", "Add to itinerary", "เพิ่มในแผนเที่ยว"],
        "nearNeedsPlace": ["先にこの場所の検索候補を選んでください。", "먼저 이 장소의 검색 결과를 선택하세요.", "请先选择此地点的搜索结果。", "Select this stop's place first.", "เลือกสถานที่นี้จากผลค้นหาก่อน"],
        "nearMeters": ["約%d m", "약 %d m", "约%d米", "about %d m", "ประมาณ %d ม."]
    ]
    static func get(_ key: String, _ language: GuideLanguage) -> String { strings[key]?[language.index] ?? key }
}

private struct OriginalStop: Codable, Equatable, Identifiable {
    var id = UUID()
    var kind: String
    var name = ""
    var address = ""
    var latitude: Double?
    var longitude: Double?
    var target: Int
    var duration: Int
    var mode = "walking"
    static var initial: [OriginalStop] {
        [OriginalStop(kind: "hotel", target: 540, duration: 0),
         OriginalStop(kind: "sight", target: 600, duration: 75),
         OriginalStop(kind: "lunch", target: 720, duration: 60),
         OriginalStop(kind: "sight", target: 840, duration: 75),
         OriginalStop(kind: "dinner", target: 1080, duration: 75),
         OriginalStop(kind: "return", target: 1200, duration: 0)]
    }
    init(kind: String, target: Int, duration: Int) {
        self.kind = kind; self.target = target; self.duration = duration
    }
}

private struct OriginalPlace: Identifiable {
    var id: String { "\(latitude),\(longitude)" }
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
}

private struct OriginalNearbyPlace: Identifiable {
    var id: String { place.id }
    let place: OriginalPlace
    let distance: Int
}

private struct OriginalCourseView: View {
    let language: GuideLanguage
    @AppStorage("japanDay.originalCourse.v1") private var savedCourse = ""
    @State private var stops = OriginalStop.initial
    @State private var loaded = false
    @State private var candidates: [UUID: [OriginalPlace]] = [:]
    @State private var times: [String: [String: TravelTime]] = [:]
    @State private var nearbyAnchor: UUID?
    @State private var nearbyKind = "sight"
    @State private var nearbyResults: [OriginalNearbyPlace] = []
    @State private var nearbySearching = false
    @State private var nearbyError: String?
    @State private var nearbySearchID = UUID()

    private func t(_ key: String) -> String { OriginalCourseText.get(key, language) }
    private func clock(_ minutes: Int) -> String {
        String(format: "%02d:%02d", (minutes / 60) % 24, minutes % 60)
    }
    private var searchKey: String { stops.map { "\($0.id):\($0.name)" }.joined(separator: "|") }
    private var routeKey: String {
        stops.map { "\($0.id):\($0.latitude ?? 0):\($0.longitude ?? 0)" }.joined(separator: "|")
    }
    private func legKey(_ index: Int) -> String {
        "\(stops[index - 1].id)|\(stops[index].id)"
    }
    private func placeQuery(_ stop: OriginalStop) -> String {
        if let latitude = stop.latitude, let longitude = stop.longitude { return "\(latitude),\(longitude)" }
        return stop.address.isEmpty ? stop.name : "\(stop.name), \(stop.address)"
    }
    private func url(_ query: String) -> URL? {
        var parts = URLComponents(string: "https://www.google.com/maps/search/")
        parts?.queryItems = [URLQueryItem(name: "api", value: "1"), URLQueryItem(name: "query", value: query)]
        return parts?.url
    }
    private func directions(_ index: Int, mode: String) -> URL? {
        var parts = URLComponents(string: "https://www.google.com/maps/dir/")
        parts?.queryItems = [URLQueryItem(name: "api", value: "1"),
                             URLQueryItem(name: "origin", value: placeQuery(stops[index - 1])),
                             URLQueryItem(name: "destination", value: placeQuery(stops[index])),
                             URLQueryItem(name: "travelmode", value: mode == "taxi" ? "driving" : mode)]
        return parts?.url
    }
    private func estimatedTime(_ index: Int, mode: String) -> TravelTime? {
        guard index > 0, let a = stops[index - 1].latitude, let b = stops[index - 1].longitude,
              let c = stops[index].latitude, let d = stops[index].longitude else { return nil }
        if let exact = times[legKey(index)]?[mode] { return exact }
        guard mode != "transit" else { return nil }
        return TravelTime.rough(from: CLLocationCoordinate2D(latitude: a, longitude: b),
                                to: CLLocationCoordinate2D(latitude: c, longitude: d),
                                by: mode == "taxi" ? .automobile : .walking)
    }
    private func arrival(_ index: Int) -> Int {
        guard index > 0 else { return stops[0].target }
        let previous = arrival(index - 1) + stops[index - 1].duration
        let mode = stops[index].mode
        let travel = estimatedTime(index, mode: mode)?.minutes ?? estimatedTime(index, mode: "walking")?.minutes ?? 0
        return max(stops[index].target, previous + travel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(t("intro")).font(.subheadline)
                Text(t("choose")).font(.caption).foregroundStyle(.secondary)
                ForEach(stops.indices, id: \.self) { index in
                    stopCard(index)
                    if index + 1 < stops.count { transfer(index + 1) }
                }
                Button {
                    stops.insert(OriginalStop(kind: "sight", target: min(1425, stops[stops.count - 2].target + 90), duration: 60), at: stops.count - 1)
                } label: { Label(t("add"), systemImage: "plus.circle.fill").frame(maxWidth: .infinity).padding(14) }
                    .background(PlannerTheme.cyan.opacity(0.18), in: RoundedRectangle(cornerRadius: 14))
                Text(t("timeNote")).font(.caption).foregroundStyle(.secondary)
            }.padding()
        }
        .background(PlannerTheme.background)
        .navigationTitle(t("open"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !loaded else { return }
            loaded = true
            if let data = savedCourse.data(using: .utf8), let decoded = try? JSONDecoder().decode([OriginalStop].self, from: data),
               decoded.count >= 2, decoded.first?.kind == "hotel", decoded.last?.kind == "return" { stops = decoded }
        }
        .onChange(of: stops) { updated in
            if loaded, let data = try? JSONEncoder().encode(updated), let value = String(data: data, encoding: .utf8) { savedCourse = value }
        }
        .task(id: searchKey) { await searchPlaces() }
        .task(id: routeKey) { await calculateRoutes() }
    }

    private func stopCard(_ index: Int) -> some View {
        let item = stops[index]
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(item.kind == "return" ? t("return") : t(item.kind)).font(.headline)
                Spacer()
                Text(clock(arrival(index))).font(.headline.monospacedDigit()).foregroundStyle(PlannerTheme.cyan)
            }
            if index > 0 && index < stops.count - 1 {
                Picker(t("choose"), selection: binding(index, \.kind)) {
                    Text(t("sight")).tag("sight")
                    Text(t("lunch")).tag("lunch")
                    Text(t("dinner")).tag("dinner")
                }.pickerStyle(.segmented)
            }
            if item.kind != "return" {
                TextField(t("place"), text: Binding(get: { stops[index].name }, set: { value in
                    stops[index].name = value
                    stops[index].address = ""
                    stops[index].latitude = nil
                    stops[index].longitude = nil
                    candidates[item.id] = nil
                    if nearbyAnchor == item.id { nearbyAnchor = nil; nearbySearchID = UUID() }
                }))
                    .textInputAutocapitalization(.words).submitLabel(.search)
                    .padding(12).background(PlannerTheme.background, in: RoundedRectangle(cornerRadius: 12))
            } else if stops[0].name.isEmpty {
                Text(t("hotel")).foregroundStyle(.secondary)
            } else {
                Text(stops[0].name)
            }
            if !item.name.isEmpty {
                if let link = url(placeQuery(item)) { Link(destination: link) { Label(t("map"), systemImage: "map") } }
                if let options = candidates[item.id], !options.isEmpty {
                    Text(t("candidate")).font(.caption).foregroundStyle(.secondary)
                    ForEach(options) { place in
                        Button {
                            stops[index].address = place.address
                            stops[index].latitude = place.latitude
                            stops[index].longitude = place.longitude
                        } label: {
                            HStack { Image(systemName: item.latitude == place.latitude && item.longitude == place.longitude ? "checkmark.circle.fill" : "circle")
                                VStack(alignment: .leading) { Text(place.name); Text(place.address).font(.caption).foregroundStyle(.secondary) }
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                } else if item.latitude == nil { Text(t("unresolved")).font(.caption).foregroundStyle(.secondary) }
            }
            if item.kind != "return" { nearbyControls(index) }
            HStack {
                Text(t("arrival"))
                Button("−15") { stops[index].target = max(0, stops[index].target - 15) }
                Text(clock(item.target)).monospacedDigit()
                Button("+15") { stops[index].target = min(1425, stops[index].target + 15) }
                Spacer()
            }.font(.subheadline)
            if item.kind == "lunch" || item.kind == "dinner" {
                HStack(spacing: 7) {
                    ForEach(item.kind == "lunch" ? [660, 720, 780, 840] : [1020, 1080, 1140], id: \.self) { value in
                        Button(clock(value)) { stops[index].target = value }
                            .buttonStyle(.bordered)
                            .tint(item.target == value ? PlannerTheme.cyan : .gray)
                    }
                }.font(.caption)
            }
            if index > 0 && index < stops.count - 1 {
                HStack {
                    Text("\(t("duration")) \(item.duration)\(t("minutes"))")
                    Button("−15") { stops[index].duration = max(15, stops[index].duration - 15) }
                    Button("+15") { stops[index].duration = min(240, stops[index].duration + 15) }
                    Spacer()
                }.font(.subheadline)
                HStack {
                    if index > 1 { Button(t("up")) { stops.swapAt(index, index - 1) } }
                    if index < stops.count - 2 { Button(t("down")) { stops.swapAt(index, index + 1) } }
                    Spacer()
                    Button(t("remove"), role: .destructive) { stops.remove(at: index) }
                }.font(.caption)
            }
        }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(PlannerTheme.surface, in: RoundedRectangle(cornerRadius: 18))
    }
    private func binding(_ index: Int, _ keyPath: WritableKeyPath<OriginalStop, String>) -> Binding<String> {
        Binding(get: { stops[index][keyPath: keyPath] }, set: { stops[index][keyPath: keyPath] = $0 })
    }
    private func nearbyControls(_ index: Int) -> some View {
        let item = stops[index]
        return VStack(alignment: .leading, spacing: 9) {
            Text(t("nearbyHint")).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                ForEach(["sight", "lunch", "dinner"], id: \.self) { kind in
                    Button {
                        searchNearby(from: index, kind: kind)
                    } label: {
                        Text(t(kind == "sight" ? "nearSight" : kind == "lunch" ? "nearLunch" : "nearDinner"))
                            .font(.caption.bold()).frame(maxWidth: .infinity).multilineTextAlignment(.center)
                            .padding(.vertical, 9)
                    }
                    .buttonStyle(.bordered)
                    .tint(kind == "sight" ? PlannerTheme.cyan : PlannerTheme.amber)
                }
            }
            if nearbyAnchor == item.id {
                if nearbySearching { ProgressView(t("searching")).font(.caption) }
                if let nearbyError { Text(t(nearbyError)).font(.caption).foregroundStyle(.secondary) }
                if !nearbyResults.isEmpty {
                    Text(t(nearbyKind == "sight" ? "nearSight" : nearbyKind == "lunch" ? "nearLunch" : "nearDinner"))
                        .font(.subheadline.bold())
                    ForEach(nearbyResults) { result in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(result.place.name).font(.subheadline.bold())
                            Text(result.place.address).font(.caption).foregroundStyle(.secondary)
                            Text(String(format: t("nearMeters"), result.distance)).font(.caption)
                            HStack {
                                Button(t("nearSelect")) { selectNearby(result, after: item.id) }
                                    .font(.caption.bold())
                                Spacer()
                                if let link = url("\(result.place.latitude),\(result.place.longitude)") {
                                    Link(destination: link) { Label(t("map"), systemImage: "map") }.font(.caption)
                                }
                            }
                        }.padding(9).frame(maxWidth: .infinity, alignment: .leading)
                            .background(PlannerTheme.background, in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
    }
    private func searchNearby(from index: Int, kind: String) {
        let anchor = stops[index]
        let token = UUID()
        nearbySearchID = token
        nearbyAnchor = anchor.id
        nearbyKind = kind
        nearbyResults = []
        nearbyError = nil
        guard let latitude = anchor.latitude, let longitude = anchor.longitude else {
            nearbySearching = false
            nearbyError = "nearNeedsPlace"
            return
        }
        nearbySearching = true
        Task {
            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            let center = CLLocation(latitude: latitude, longitude: longitude)
            var found: [String: OriginalNearbyPlace] = [:]
            let queries = kind == "sight" ? ["観光名所", "博物館", "公園"] : ["レストラン", "食堂"]
            for query in queries {
                guard nearbySearchID == token else { return }
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = query
                request.resultTypes = .pointOfInterest
                request.region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 7000, longitudinalMeters: 7000)
                if kind != "sight" {
                    request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.restaurant])
                }
                guard let response = try? await MKLocalSearch(request: request).start() else { continue }
                guard nearbySearchID == token else { return }
                for mapItem in response.mapItems {
                    guard let name = mapItem.name, !name.isEmpty else { continue }
                    let point = mapItem.placemark.coordinate
                    let distance = center.distance(from: CLLocation(latitude: point.latitude, longitude: point.longitude))
                    guard distance >= 30, distance <= 5000 else { continue }
                    let place = OriginalPlace(name: name, address: mapItem.placemark.title ?? name,
                                              latitude: point.latitude, longitude: point.longitude)
                    found[place.id] = OriginalNearbyPlace(place: place, distance: Int(distance.rounded()))
                }
            }
            guard nearbySearchID == token else { return }
            nearbyResults = Array(found.values.sorted { $0.distance < $1.distance }.prefix(8))
            nearbySearching = false
            if nearbyResults.isEmpty { nearbyError = "nearEmpty" }
        }
    }
    private func selectNearby(_ result: OriginalNearbyPlace, after anchorID: UUID) {
        guard let index = stops.firstIndex(where: { $0.id == anchorID }) else { return }
        let kind = nearbyKind
        if kind != "sight", let emptyIndex = stops.indices.first(where: { $0 > index && stops[$0].kind == kind && stops[$0].name.isEmpty }) {
            stops.remove(at: emptyIndex)
        }
        let minimum = kind == "dinner" ? 1020 : kind == "lunch" ? 660 : 0
        var next = OriginalStop(kind: kind, target: min(1425, max(minimum, arrival(index) + stops[index].duration + 15)),
                                duration: kind == "sight" ? 60 : 75)
        next.name = result.place.name
        next.address = result.place.address
        next.latitude = result.place.latitude
        next.longitude = result.place.longitude
        stops.insert(next, at: index + 1)
        nearbySearchID = UUID()
        nearbyAnchor = nil
        nearbyResults = []
    }
    private func transfer(_ index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "arrow.down")
                Picker(t("route"), selection: binding(index, \.mode)) {
                    Text(t("walk")).tag("walking")
                    Text(t("taxi")).tag("taxi")
                    if times[legKey(index)]?["transit"] != nil { Text(t("transit")).tag("transit") }
                }.pickerStyle(.menu)
                Spacer()
            }
            ForEach(["walking", "taxi", "transit"], id: \.self) { mode in
                if let duration = estimatedTime(index, mode: mode), let link = directions(index, mode: mode),
                   !stops[index - 1].name.isEmpty && !stops[index].name.isEmpty {
                    Link(destination: link) {
                        HStack {
                            Image(systemName: mode == "walking" ? "figure.walk" : mode == "taxi" ? "car.fill" : "tram.fill")
                            Text(t(mode == "walking" ? "walk" : mode))
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                            Text("\(HotelTravelTranslations.ui[duration.isApproximate ? "approximate" : "routeEstimate"]?[language.index] ?? "") · \(duration.minutes)\(t("minutes"))")
                            if let metres = duration.routeMetres ?? duration.straightMetres {
                                Text("\(HotelTravelTranslations.ui[duration.routeMetres == nil ? "straightDistance" : "routeDistance"]?[language.index] ?? "") " + String(format: "%.1f km", locale: language.locale, metres / 1000)).font(.caption)
                            }
                            }.fixedSize(horizontal: false, vertical: true)
                            Image(systemName: "arrow.up.right")
                        }.font(.subheadline)
                    }
                }
            }
            if estimatedTime(index, mode: "walking") == nil {
                Text(t("unresolved")).font(.caption).foregroundStyle(.secondary)
            }
        }.padding(.horizontal, 14)
    }

    private func searchPlaces() async {
        try? await Task.sleep(nanoseconds: 450_000_000)
        guard !Task.isCancelled else { return }
        if let last = stops.indices.last, stops[last].kind == "return", stops[0].name.isEmpty {
            stops[last].name = ""; stops[last].address = ""; stops[last].latitude = nil; stops[last].longitude = nil
        }
        for item in stops where item.kind != "return" && !item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard !Task.isCancelled else { return }
            if item.latitude != nil && candidates[item.id] != nil { continue }
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = item.name
            guard let response = try? await MKLocalSearch(request: request).start(), !Task.isCancelled else { continue }
            let found: [OriginalPlace] = Array(response.mapItems.prefix(4)).compactMap { result in
                guard let name = result.name else { return nil }
                let point = result.placemark.coordinate
                return OriginalPlace(name: name, address: result.placemark.title ?? name, latitude: point.latitude, longitude: point.longitude)
            }
            guard let i = stops.firstIndex(where: { $0.id == item.id && $0.name == item.name }) else { continue }
            candidates[item.id] = found
            if let first = found.first, stops[i].latitude == nil {
                stops[i].latitude = first.latitude; stops[i].longitude = first.longitude; stops[i].address = first.address
            }
        }
        if let last = stops.indices.last, stops[last].kind == "return", stops[0].latitude != nil {
            stops[last].name = stops[0].name
            stops[last].address = stops[0].address
            stops[last].latitude = stops[0].latitude
            stops[last].longitude = stops[0].longitude
        }
    }
    private func calculateRoutes() async {
        times = [:]
        let snapshot = stops
        guard snapshot.count > 1 else { return }
        for index in 1..<snapshot.count {
            guard !Task.isCancelled else { return }
            let from = snapshot[index - 1], to = snapshot[index]
            guard let a = from.latitude, let b = from.longitude, let c = to.latitude, let d = to.longitude else { continue }
            let key = "\(from.id)|\(to.id)"
            for mode in ["walking", "taxi", "transit"] {
                guard !Task.isCancelled else { return }
                let request = MKDirections.Request()
                request.source = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: a, longitude: b)))
                request.destination = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: c, longitude: d)))
                request.transportType = mode == "walking" ? .walking : mode == "taxi" ? .automobile : .transit
                if let origin = request.source, let destination = request.destination,
                   let value = await RouteMeasurements.fetch(from: origin, to: destination, by: request.transportType),
                   !Task.isCancelled {
                    times[key, default: [:]][mode] = value
                }
            }
        }
    }
}

private struct PlannerMapRequest: Identifiable {
    let id = UUID()
    let url: URL
    let title: String
}

private enum PlannerMapText {
    static let values: [String: [String]] = [
        "close": ["閉じる", "닫기", "关闭", "Close", "ปิด"],
        "loading": ["地図を読み込み中…", "지도를 불러오는 중…", "正在加载地图…", "Loading map…", "กำลังโหลดแผนที่…"],
        "retry": ["再読み込み", "새로고침", "重新加载", "Reload", "โหลดใหม่"],
        "error": ["地図を読み込めませんでした。通信状態を確認し、再読み込みしてください。", "지도를 불러오지 못했습니다. 연결을 확인하고 다시 시도하세요.", "无法加载地图，请检查网络并重新加载。", "The map could not load. Check your connection and reload.", "โหลดแผนที่ไม่ได้ ตรวจสอบการเชื่อมต่อแล้วโหลดใหม่"],
        "note": ["選択言語で地図を読み込みます。地名・店舗名は現地表記が残る場合があります。", "선택한 언어로 지도를 요청합니다. 지명·상호는 현지 언어로 남을 수 있습니다.", "以所选语言加载地图；部分地名与店名可能保留当地文字。", "The map is requested in your chosen language. Some place and business names may remain in the local language.", "โหลดแผนที่ตามภาษาที่เลือก ชื่อสถานที่และร้านบางแห่งอาจยังเป็นภาษาท้องถิ่น"]
    ]
    static func text(_ key: String, _ language: GuideLanguage) -> String {
        values[key]?[language.index] ?? key
    }
}

private struct PlannerMapScreen: View {
    let request: PlannerMapRequest
    let language: GuideLanguage
    @Environment(\.dismiss) private var dismiss
    @State private var loading = true
    @State private var failed = false
    @State private var reloadID = UUID()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "globe")
                    Text(language.title).font(.subheadline.bold())
                    Spacer()
                }.padding(.horizontal).padding(.vertical, 8)
                Text(PlannerMapText.text("note", language))
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal).padding(.bottom, 8)
                ZStack {
                    PlannerMapWebView(url: request.url, languageCode: language.rawValue,
                                      loading: $loading, failed: $failed)
                        .id(reloadID)
                    if loading && !failed {
                        ProgressView(PlannerMapText.text("loading", language))
                            .padding(16).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                    if failed {
                        VStack(spacing: 16) {
                            Text(PlannerMapText.text("error", language)).multilineTextAlignment(.center)
                            Button(PlannerMapText.text("retry", language)) { reload() }
                                .buttonStyle(.borderedProminent)
                        }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(.systemBackground))
                    }
                }
            }
            .navigationTitle(request.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(PlannerMapText.text("close", language)) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { reload() } label: { Image(systemName: "arrow.clockwise") }
                        .accessibilityLabel(PlannerMapText.text("retry", language))
                }
            }
        }
        .environment(\.locale, language.locale)
    }
    private func reload() {
        loading = true
        failed = false
        reloadID = UUID()
    }
}

private struct PlannerMapWebView: UIViewRepresentable {
    let url: URL
    let languageCode: String
    @Binding var loading: Bool
    @Binding var failed: Bool

    func makeCoordinator() -> Coordinator { Coordinator(loading: $loading, failed: $failed) }
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        // A fresh map session avoids inheriting a previous signed-in display language.
        configuration.websiteDataStore = .nonPersistent()
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.uiDelegate = context.coordinator
        view.allowsBackForwardNavigationGestures = true
        var request = URLRequest(url: url)
        let code = languageCode == "zh" ? "zh-CN" : languageCode
        request.setValue("\(code),en;q=0.8", forHTTPHeaderField: "Accept-Language")
        view.load(request)
        return view
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.stopLoading()
        uiView.navigationDelegate = nil
        uiView.uiDelegate = nil
    }
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let loading: Binding<Bool>
        let failed: Binding<Bool>
        init(loading: Binding<Bool>, failed: Binding<Bool>) {
            self.loading = loading
            self.failed = failed
        }
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            loading.wrappedValue = true
            failed.wrappedValue = false
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            loading.wrappedValue = false
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            showError(error)
        }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            showError(error)
        }
        private func showError(_ error: Error) {
            if (error as NSError).code == NSURLErrorCancelled { return }
            loading.wrappedValue = false
            failed.wrappedValue = true
        }
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            let scheme = navigationAction.request.url?.scheme?.lowercased()
            // Keep maps in this screen; app-launch schemes do not take over navigation.
            decisionHandler(scheme == "https" || scheme == "http" || scheme == "about" ? .allow : .cancel)
        }
        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                     decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            if navigationResponse.isForMainFrame,
               let response = navigationResponse.response as? HTTPURLResponse, response.statusCode >= 400 {
                loading.wrappedValue = false
                failed.wrappedValue = true
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            loading.wrappedValue = false
            failed.wrappedValue = true
        }
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil,
               let scheme = navigationAction.request.url?.scheme?.lowercased(),
               scheme == "https" || scheme == "http" {
                webView.load(navigationAction.request)
            }
            return nil
        }
    }
}

private enum PlannerTheme {
    static let background = Color(red: 0.025, green: 0.035, blue: 0.045)
    static let surface = Color(red: 0.065, green: 0.080, blue: 0.095)
    static let raised = Color(red: 0.11, green: 0.13, blue: 0.16)
    static let cyan = Color(red: 0.08, green: 0.86, blue: 0.91)
    static let coral = Color(red: 1.0, green: 0.42, blue: 0.44)
    static let violet = Color(red: 0.72, green: 0.56, blue: 1.0)
    static let amber = Color(red: 1.0, green: 0.76, blue: 0.28)
    static let pink = Color(red: 1.0, green: 0.54, blue: 0.76)
    static func accent(_ index: Int) -> Color { [cyan, coral, violet, amber, pink][max(0, index) % 5] }
    static func linkAccent(_ symbol: String) -> Color {
        if symbol.contains("phone") { return amber }
        if symbol.contains("globe") || symbol.contains("book") { return violet }
        if symbol.contains("fork") { return coral }
        return cyan
    }
}
private struct PlannerTravelBanner: View {
    var body: some View {
        GeometryReader { proxy in
            if let image = PlannerArtwork.image {
                Image(uiImage: image).resizable().scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height).clipped()
            } else {
                LinearGradient(colors: [PlannerTheme.background, PlannerTheme.cyan.opacity(0.25)], startPoint: .top, endPoint: .bottom)
            }
        }.accessibilityHidden(true)
    }
}
private enum PlannerArtwork {
    // Bundled travel illustration; no asset upload or network request is needed.
    static let image: UIImage? = {
        guard let data = Data(base64Encoded: encoded, options: .ignoreUnknownCharacters) else { return nil }
        return UIImage(data: data)
    }()
    private static let encoded = """
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
"""
}

// Registered regional alternatives verified against the official hotel list on 2026-10-06.
// These are never labelled nearest, and have no fabricated coordinates or distance.
private enum RegisteredStays {
    static let names: [String: String] = [
        "hokkaido": "東横INN札幌駅南口",
        "aomori": "東横INN青森駅前",
        "iwate": "東横INN盛岡駅前",
        "miyagi": "東横INN仙台駅西口中央",
        "akita": "東横INN秋田駅東口",
        "yamagata": "東横INN山形駅西口",
        "fukushima": "東横INN会津若松駅前",
        "ibaraki": "東横INN水戸駅南口",
        "tochigi": "東横INN宇都宮駅前1",
        "gunma": "東横INN前橋駅前",
        "saitama": "東横INN大宮駅東口",
        "chiba": "東横INN成田空港本館",
        "tokyo": "東横INN新宿御苑前駅3番出口",
        "kanagawa": "東横INN横浜桜木町",
        "niigata": "東横INN新潟駅前",
        "toyama": "東横INN富山駅新幹線口1",
        "ishikawa": "東横INN金沢兼六園香林坊",
        "fukui": "東横INN福井駅前",
        "yamanashi": "東横INN甲府駅南口1",
        "nagano": "東横INN長野駅善光寺口",
        "gifu": "東横INN岐阜",
        "shizuoka": "東横INN静岡駅北口",
        "aichi": "東横INN名古屋金山",
        "mie": "東横INN伊勢市駅",
        "shiga": "東横INN彦根駅東口",
        "kyoto": "東横INN京都四条大宮",
        "osaka": "東横INN大阪谷四交差点",
        "hyogo": "東横INNJR神戸駅北口",
        "nara": "東横INN近鉄奈良駅前",
        "wakayama": "東横INNJR和歌山駅東口",
        "tottori": "東横INN鳥取駅南口",
        "shimane": "東横INN松江駅前",
        "okayama": "東横INN岡山駅東口",
        "hiroshima": "東横INN広島平和大通",
        "yamaguchi": "東横INN新山口駅新幹線口",
        "tokushima": "東横INN徳島駅前",
        "kagawa": "東横INN高松兵庫町",
        "ehime": "東横INN松山一番町",
        "kochi": "東横INN高知",
        "fukuoka": "東横INN福岡天神",
        "saga": "東横INN佐賀駅前",
        "nagasaki": "東横INN長崎駅前",
        "kumamoto": "東横INN熊本城通町筋",
        "oita": "東横INN大分駅前",
        "miyazaki": "東横INN宮崎駅前",
        "kagoshima": "東横INN鹿児島天文館1",
        "okinawa": "東横INN那覇国際通り美栄橋駅"
    ]
}
