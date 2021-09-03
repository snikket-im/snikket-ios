//
//  MKMapExtension.swift
//  Snikket
//
//  Created by Khalid Khan on 9/2/21.
//  Copyright © 2021 Snikket. All rights reserved.
//

import Foundation
import MapKit

extension MKMapView {
  func centerToLocation(
    _ location: CLLocation,
    regionRadius: CLLocationDistance = 1000
  ) {
    let coordinateRegion = MKCoordinateRegion(
      center: location.coordinate,
      latitudinalMeters: regionRadius,
      longitudinalMeters: regionRadius)
    setRegion(coordinateRegion, animated: true)
  }
}

extension CLLocation {
    func makeGeoURL() -> String {
        return self.coordinate.makeGeoURL()
    }
}

extension CLLocationCoordinate2D {
    func makeGeoURL() -> String {
        return "geo:\(self.latitude),\(self.longitude)"
    }
}
