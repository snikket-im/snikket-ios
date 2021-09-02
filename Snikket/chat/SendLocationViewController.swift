//
//  SendLocationViewController.swift
//  Snikket
//
//  Created by Khalid Khan on 9/2/21.
//  Copyright © 2021 Snikket. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation

class SendLocationViewController: UIViewController {
    
    var chat: DBChatProtocol?

    @IBOutlet weak var sendButton: UIBarButtonItem!
    @IBOutlet weak var sendCurrentLocationButton: UIButton!
    @IBOutlet weak var mapView: MKMapView!
    
    var didCenterToUserLocation = false
    
    let locationManager = CLLocationManager()
    let currentAnnotation = MKPointAnnotation()
    var currentCoordinates: CLLocationCoordinate2D?
    var userLocation: CLLocation?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.sendButton.isEnabled = false
        sendCurrentLocationButton.clipsToBounds = true
        sendCurrentLocationButton.layer.cornerRadius = 5
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        self.mapView.addGestureRecognizer(tapGesture)
        showCurrentLocationPin()
    }
    
    @objc func handleTap(_ sender: UITapGestureRecognizer) {
        
        self.sendButton.isEnabled = true
        let touchPoint = sender.location(in: self.mapView)
        let mapCoordinate = self.mapView.convert(touchPoint, toCoordinateFrom: self.mapView)
        currentAnnotation.coordinate = mapCoordinate
        currentCoordinates = mapCoordinate
        self.mapView.addAnnotation(currentAnnotation)
    }

    @IBAction func sendCurrentLocationTapped(_ sender: Any) {
        guard let chat = self.chat as? DBChat, let location = self.userLocation else { return }
        let text = location.makeGeoURL()
        MessageEventHandler.sendMessage(chat: chat, body: text, url: nil, correctedMessageOriginId: nil)
        self.navigationController?.popViewController(animated: true)
    }
    
    @IBAction func sendTapped(_ sender: Any) {
        guard let chat = self.chat as? DBChat, let location = self.currentCoordinates else { return }
        let text = location.makeGeoURL()
        MessageEventHandler.sendMessage(chat: chat, body: text, url: nil, correctedMessageOriginId: nil)
        self.navigationController?.popViewController(animated: true)
    }
    
    @IBAction func cancelTapped(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }
    
    func showCurrentLocationPin() {
        self.locationManager.requestAlwaysAuthorization()
        self.locationManager.requestWhenInUseAuthorization()
        self.mapView.showsUserLocation = true
        self.mapView.delegate = self
        
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            locationManager.startUpdatingLocation()
        }
    }
}

extension SendLocationViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation { return nil }

        let reuseId = "pin"
        var pav: MKPinAnnotationView? = self.mapView.dequeueReusableAnnotationView(withIdentifier: reuseId) as? MKPinAnnotationView
        if pav == nil {
            pav = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
            pav?.isDraggable = true
            pav?.canShowCallout = true
        } else {
            pav?.annotation = annotation
        }
        return pav
    }
    
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, didChange newState: MKAnnotationView.DragState, fromOldState oldState: MKAnnotationView.DragState) {

        if newState == MKAnnotationView.DragState.ending, let annotation = view.annotation {
            currentCoordinates = annotation.coordinate
            print("annotation dropped at: \(annotation.coordinate.latitude),\(annotation.coordinate.longitude)")
        }
    }
}

extension SendLocationViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let userLocation = locations.first else { return }
        
        if !didCenterToUserLocation {
            mapView.centerToLocation(userLocation)
            self.userLocation = userLocation
            didCenterToUserLocation = false
        }
    }
}
