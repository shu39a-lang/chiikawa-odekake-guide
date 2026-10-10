#!/usr/bin/env python3
"""Patch the current Japan Day Plan Swift source without changing unrelated screens.
Usage: python JapanDayPlan_time_fix.py path/to/ChiikawaGuideApp.swift
"""
from pathlib import Path
import sys
if len(sys.argv) != 2:
    raise SystemExit('Usage: python JapanDayPlan_time_fix.py ChiikawaGuideApp.swift')
p=Path(sys.argv[1]); s=p.read_text(encoding='utf-8')
replacements=[
('guard CLLocationCoordinate2DIsValid(a), CLLocationCoordinate2DIsValid(b), !Task.isCancelled else { return nil }',
'''guard CLLocationCoordinate2DIsValid(a), CLLocationCoordinate2DIsValid(b), !Task.isCancelled else { return nil }
        // Different places can have the same imprecise town-centre coordinate.
        let separation = CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
        guard separation.isFinite, separation >= 15 else { return nil }'''),
('eta.expectedTravelTime / 60 < Double(Int.max) else { return nil }',
'''eta.expectedTravelTime / 60 < Double(Int.max),
                  eta.expectedTravelTime >= 120 else { return nil }'''),
('''$0.expectedTravelTime / 60 < Double(Int.max)
              }).min''',
'''$0.expectedTravelTime / 60 < Double(Int.max) &&
                  $0.distance >= separation * 0.65
              }).min'''),
('''if let cached = cachedRoutePlace(query) { return cached }
        if let hotel = selectedSuggestedHotel, query == hotel.query,
           let ready = item(hotel.latitude, hotel.longitude) { return ready }''',
'''// Selected hotel coordinates take precedence over stale name-search caches.
        if let hotel = selectedSuggestedHotel, query == hotel.query,
           let ready = item(hotel.latitude, hotel.longitude) { return ready }
        if let cached = cachedRoutePlace(query) { return cached }'''),
('''let roughMinutes = straight * 1.4 / metresPerMinute''',
'''guard straight >= 15 else { return nil }
        let roughMinutes = straight * 1.4 / metresPerMinute''')
]
for before,after in replacements:
    n=s.count(before)
    if n!=1: raise SystemExit(f'STOP: expected exactly one matching block, found {n}: {before[:70]}')
    s=s.replace(before,after,1)
out=p.with_name(p.stem+'_fixed'+p.suffix)
out.write_text(s,encoding='utf-8')
print(f'Created {out} ({len(s)} characters), replaced {len(replacements)} blocks')
