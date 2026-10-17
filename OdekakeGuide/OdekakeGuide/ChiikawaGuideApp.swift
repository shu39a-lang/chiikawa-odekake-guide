
static func routeTime(
    from origin: MKMapItem,
    to destination: MKMapItem,
    by transport: MKDirectionsTransportType,
    plannedDepartureMinutes: Int? = nil
) async -> TravelTime? {
    let a = origin.placemark.coordinate
    let b = destination.placemark.coordinate

    guard let straight = metres(from: a, to: b),
          straight >= 5 else {
        return nil
    }

    let mode: String = transport == .walking
        ? "walking"
        : transport == .automobile
            ? "taxi"
            : "transit"

    let from = RoutePoint(a)
    let to = RoutePoint(b)

    async let google = GoogleRoutesGateway.shared.minutes(
        from: from,
        to: to,
        mode: mode
    )

    async let native = NativeMapDirections.realRoute(
        from: from,
        to: to,
        mode: mode,
        plannedDepartureMinutes: plannedDepartureMinutes
    )

    let googleMinutes = await google
    let nativeResult = await native

    guard !Task.isCancelled else {
        return nil
    }

    // 徒歩・タクシーは、実際の経路情報を優先する。
    // 電車・バスはApple側で取得できない場合、
    // Google側の実経路結果があれば補助的に表示する。
    if mode == "transit" {
        if let nativeResult {
            return nativeResult
        }

        if let googleMinutes, googleMinutes > 0 {
            return TravelTime(
                minutes: googleMinutes,
                isApproximate: false,
                routeMetres: nil
            )
        }

        return nil
    }

    if let googleMinutes, googleMinutes > 0 {
        return TravelTime(
            minutes: googleMinutes,
            isApproximate: false,
            routeMetres: nativeResult?.routeMetres
        )
    }

    if let nativeResult {
        return nativeResult
    }

    return nil
}
