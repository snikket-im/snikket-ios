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
import TigaseSwift
import TigaseSwiftOMEMO

class SendLocationViewController: UIViewController {
    
    var chat: DBChatProtocol?
    var account: BareJID?
    var jid: BareJID?

    @IBOutlet weak var removePinButton: UIButton!
    @IBOutlet weak var sendCurrentLocationButton: UIButton!
    @IBOutlet weak var mapView: MKMapView!
    
    var didCenterToUserLocation = false
    
    let locationManager = CLLocationManager()
    let currentAnnotation = MKPointAnnotation()
    var currentCoordinates: CLLocationCoordinate2D?
    var userLocation: CLLocation?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        sendCurrentLocationButton.clipsToBounds = true
        sendCurrentLocationButton.layer.cornerRadius = 5
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        self.mapView.addGestureRecognizer(tapGesture)
        showCurrentLocationPin()
    }
    
    @objc func handleTap(_ sender: UITapGestureRecognizer) {
        
        let touchPoint = sender.location(in: self.mapView)
        let mapCoordinate = self.mapView.convert(touchPoint, toCoordinateFrom: self.mapView)
        currentAnnotation.coordinate = mapCoordinate
        currentCoordinates = mapCoordinate
        self.mapView.addAnnotation(currentAnnotation)
        
        self.removePinButton.isHidden = false
        self.sendCurrentLocationButton.setTitle(NSLocalizedString("Send Pin Location", comment: ""), for: .normal)
    }

    @IBAction func removePinTapped(_ sender: UIButton) {
        self.mapView.removeAnnotation(currentAnnotation)
        self.removePinButton.isHidden = true
        self.sendCurrentLocationButton.setTitle(NSLocalizedString("Send Current Location", comment: ""), for: .normal)
    }
    
    @IBAction func sendCurrentLocationTapped(_ sender: Any) {
        if let room = self.chat as? DBRoom {
            sendLocationToGroup(room: room)
            return
        }
        guard let chat = self.chat as? DBChat else { return }
        
        if let location = self.currentCoordinates {
            let text = location.makeGeoURL()
            MessageEventHandler.sendMessage(chat: chat, body: text, url: nil, correctedMessageOriginId: nil)
        }
        else if let location = self.userLocation {
            let text = location.makeGeoURL()
            MessageEventHandler.sendMessage(chat: chat, body: text, url: nil, correctedMessageOriginId: nil)
        }
        
        self.navigationController?.popViewController(animated: true)
    }
    
    func sendLocationToGroup(room: DBRoom) {
        guard room.state == .joined, let account = self.account, let jid = self.jid else { return }
        let canEncrypt = (room.supportedFeatures?.contains("muc_nonanonymous") ?? false) && (room.supportedFeatures?.contains("muc_membersonly") ?? false)
        let encryption: ChatEncryption = room.options.encryption ?? (canEncrypt ? (ChatEncryption(rawValue: Settings.messageEncryption.string() ?? "") ?? .none) : .none)
        guard encryption == .none || canEncrypt else {
            if encryption == .omemo && !canEncrypt {
                let alert = UIAlertController(title: NSLocalizedString("Warning", comment: ""), message: NSLocalizedString("This room is not capable of sending encrypted messages. Please change encryption settings to be able to send messages", comment: ""), preferredStyle: .alert);
                alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default, handler: nil));
                self.present(alert, animated: true, completion: nil);
            }
            return;
        }
        
        var msg = ""
        if let location = self.currentCoordinates { msg = location.makeGeoURL() }
        else if let location = self.userLocation { msg = location.makeGeoURL() }
        let message = room.createMessage(msg)
        
        guard let client = XmppService.instance.getClient(for: account) else { return }
        if encryption == .omemo, let omemoModule: OMEMOModule = client.modulesManager.getModule(OMEMOModule.ID) {
            guard let members = room.members else { return }
            omemoModule.encode(message: message, for: members.map({ $0.bareJid }), completionHandler: { result in
                switch result {
                case .failure(_):
                    print("could not encrypt message for", room.jid);
                case .successMessage(let message, let fingerprint):
                    client.context.writer?.write(message);
                    DBChatHistoryStore.instance.appendItem(for: account, with: jid, state: .outgoing, authorNickname: room.nickname, authorJid: nil, recipientNickname: nil, participantId: nil, type: .message, timestamp: Date(), stanzaId: message.id, serverMsgId: nil, remoteMsgId: nil, data: msg, encryption: .decrypted, encryptionFingerprint: fingerprint, linkPreviewAction: .auto, completionHandler: nil)
                    self.navigationController?.popViewController(animated: true)
                }
            })
        } else {
            client.context.writer?.write(message);
            DBChatHistoryStore.instance.appendItem(for: account, with: jid, state: .outgoing, authorNickname: room.nickname, authorJid: nil, recipientNickname: nil, participantId: nil, type: .message, timestamp: Date(), stanzaId: message.id, serverMsgId: nil, remoteMsgId: nil, data: msg, encryption: .none, encryptionFingerprint: nil, linkPreviewAction: .auto, completionHandler: nil)
            self.navigationController?.popViewController(animated: true)
        }
    }
    
    @IBAction func cancelTapped(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }
    
    func showCurrentLocationPin() {
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
            didCenterToUserLocation = true
        }
    }
}
