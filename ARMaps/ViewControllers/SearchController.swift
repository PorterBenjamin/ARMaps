//
//  SearchController.swift
//  ARMaps
//
//  Created by Ben Porter on 1/9/18.
//  Copyright © 2018 Ben Porter. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import AVFoundation

protocol HandleMapSearch {
    func dropPinZoomIn(placemark:MKPlacemark, mapItem:MKMapItem)
    func closeSearch()
}

class SearchController: UIViewController {

    @IBOutlet weak var directionsView: UIView!
    @IBOutlet weak var directionsLabel: UILabel!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var buttonFocus: UIButton!
    @IBOutlet weak var buttonStartNavigation: UIButton!
    
    @IBOutlet weak var buttonStop: UIButton!
    @IBOutlet weak var lblPlace: UILabel!
    @IBOutlet weak var lblAddress: UILabel!
    
    @IBOutlet weak var startNavCover: UIView!
    @IBOutlet weak var startNavView: UIView!
    @IBOutlet weak var StartNavViewConstraint: NSLayoutConstraint!
    
    let locationManager = CLLocationManager()
    var currentCoordinate: CLLocationCoordinate2D!
    
    var steps = [MKRouteStep]()
    let voice = AVSpeechSynthesisVoice(language: "en-AU")
    let speak = AVSpeechSynthesizer()
    var mapDestination:MKMapItem? = nil
    
    var stepCounter = 0
    
    //Search controller
    var resultSearchController:UISearchController? = nil
    
    var selectedPin:MKPlacemark? = nil
    

    override func viewDidLoad() {
        super.viewDidLoad()
        
        directionsView.isHidden = true
        directionsView.layer.cornerRadius = 10
        directionsView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        directionsView.layer.shadowColor = UIColor.black.cgColor
        directionsView.layer.shadowOffset = CGSize(width: 0.0, height: 3.0)
        directionsView.layer.shadowOpacity = 0.4
        directionsView.layer.shadowRadius = 1.0
        directionsView.layer.masksToBounds = false

        buttonStop.isHidden = true
        buttonStop.layer.cornerRadius = buttonStop.frame.height / 2
        buttonStop.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        buttonStop.layer.shadowColor = UIColor.black.cgColor
        buttonStop.layer.shadowOffset = CGSize(width: 0.0, height: 3.0)
        buttonStop.layer.shadowOpacity = 0.4
        buttonStop.layer.shadowRadius = 1.0
        buttonStop.layer.masksToBounds = false
        
        buttonFocus.layer.cornerRadius = buttonFocus.frame.height / 2
        buttonFocus.layer.shadowColor = UIColor.black.cgColor
        buttonFocus.layer.shadowOffset = CGSize(width: 0.0, height: 3.0)
        buttonFocus.layer.shadowOpacity = 0.4
        buttonFocus.layer.shadowRadius = 1.0
        buttonFocus.layer.masksToBounds = false
        
        StartNavViewConstraint.constant = 0 // 100
        startNavCover.isHidden = true
        startNavView.layer.cornerRadius = 20
        startNavView.layer.masksToBounds = false
        startNavView.layer.shadowOffset = CGSize(width: 1, height: -3)
        startNavView.layer.shadowColor = UIColor.black.cgColor
        startNavView.layer.shadowRadius = 1.0
        startNavView.layer.shadowOpacity = 0.2
        
        buttonStartNavigation.isHidden = true
        buttonStartNavigation.layer.cornerRadius = buttonStartNavigation.frame.height / 2
        buttonStartNavigation.layer.shadowColor = UIColor.black.cgColor
        buttonStartNavigation.layer.shadowOffset = CGSize(width: 0.0, height: 3.0)
        buttonStartNavigation.layer.shadowOpacity = 0.2
        buttonStartNavigation.layer.shadowRadius = 1.0
        buttonStartNavigation.layer.masksToBounds = false
        
        //Search Bar things...
        let locationSearchTable = storyboard!.instantiateViewController(withIdentifier: "LocationSearchTable") as! LocationSearchTable
        resultSearchController = UISearchController(searchResultsController: locationSearchTable)
        resultSearchController?.searchResultsUpdater = locationSearchTable
        locationSearchTable.handleMapSearchDelegate = self
        
        let searchBar = resultSearchController!.searchBar
        searchBar.sizeToFit()
        searchBar.barTintColor = UIColor.white
        searchBar.tintColor = UIColor.white
        
        //Change placeholder so it is different everytime the app is opened
        searchBar.placeholder = "Search for any place"
        navigationItem.titleView = resultSearchController?.searchBar

        resultSearchController?.hidesNavigationBarDuringPresentation = false
        resultSearchController?.dimsBackgroundDuringPresentation = true
        definesPresentationContext = true
        
        
        locationSearchTable.mapView = mapView
        
        //Inital ask:
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        
        // for ios 10 and lower
        locationManager.requestAlwaysAuthorization()
        locationManager.allowsBackgroundLocationUpdates = true
    
        checkLocationPermission()

        // Map
        mapView.delegate = self
        mapView.showsUserLocation = true
//        mapView.userTrackingMode = MKUserTrackingMode(rawValue: 1)!
    }
    
    
    // Is called everytime that the application is opened to check for location permissions that may have changed
    func checkLocationPermission() {
        switch CLLocationManager.authorizationStatus() {
        case .notDetermined:
            // Request when-in-use authorization initially
            locationManager.requestWhenInUseAuthorization()
            
            // for ios 10 and lower
            locationManager.requestAlwaysAuthorization()
            locationManager.allowsBackgroundLocationUpdates = true
            break
            
        case .restricted, .denied:
            
            let actionSheetController: UIAlertController = UIAlertController(title: "Location Services", message: "You have not allowed access to your location, ARMaps needs your location so we can navigate you correctly 😄.", preferredStyle: .alert)
            let cancelAction: UIAlertAction = UIAlertAction(title: "Cancel", style: .cancel) { action -> Void in
                //Just dismiss the action sheet
            }
            
            let okAction: UIAlertAction = UIAlertAction(title: "OK", style: .default) { action -> Void in
                //Takes user to settings
                if let appSettings = URL(string: UIApplicationOpenSettingsURLString) {
                    UIApplication.shared.open(appSettings, options: [:], completionHandler: nil)
                }
            }
            actionSheetController.addAction(okAction)
            actionSheetController.addAction(cancelAction)
            self.present(actionSheetController, animated: true, completion: nil)
            break
    
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.allowsBackgroundLocationUpdates = true
            locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
            locationManager.startUpdatingLocation()
            break
        }
    }
    
    
    @IBAction func ButtonStopAction(_ sender: Any) {
        stopNavigation()
    }
    
    func stopNavigation() {
        // Hide all stuff
        self.buttonStop.isHidden = true
        self.directionsView.isHidden = true
        self.startNavCover.isHidden = true
        //reset stuff
        stepCounter = 0
        steps = [MKRouteStep]()
        self.speak.stopSpeaking(at: .immediate)
        let allAnnotations = self.mapView.annotations
        self.mapView.removeAnnotations(allAnnotations)
        let allOverlays = self.mapView.overlays
        self.mapView.removeOverlays(allOverlays)
        focusOnUser()
        
    }
    
    @IBAction func buttonStartNavigationAction(_ sender: Any) {
        
        if let arVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "ARNavViewController") as? ARNavViewController {
                arVC.mapDestination = self.mapDestination
                arVC.steps = self.steps

            self.present(arVC, animated: true, completion: nil)
        }
        //Animations to get view ready
//        self.buttonStop.isHidden = false
//        UIView.animate(withDuration: 1.0, delay: 0, usingSpringWithDamping: 0.3, initialSpringVelocity: 6.0,
//                       options: .allowUserInteraction, animations: { [weak self] in
//                        self!.buttonStop.transform = .identity
//                        self!.directionsView.transform = .identity
//            }, completion: nil)
//
//        self.StartNavViewConstraint.constant = 0 //100
//        self.startNavCover.isHidden = true
//
//        self.directionsView.isHidden = false
//
//        UIView.animate(withDuration: 0.5) {
//            self.directionsView.isHidden = false
//            self.buttonStartNavigation.isHidden = true
//            self.view.layoutIfNeeded()
//        }
//
//        //Speech synth
//        let initialMessage = "In \(self.steps[0].distance) meters, \(self.steps[0].instructions) then in \(self.steps[1].distance) meters, \(self.steps[1].instructions)."
//        self.directionsLabel.text = initialMessage
//
//        let speechUtterance = AVSpeechUtterance(string: initialMessage)
//        speechUtterance.voice = self.voice
//        self.speak.speak(speechUtterance)
//
//        locationManager.allowsBackgroundLocationUpdates = true
//
//        self.stepCounter += 1
    }
    
    @IBAction func buttonFocusAction(_ sender: Any) {
        focusOnUser()
    }
    
    func focusOnUser() {
        let span = MKCoordinateSpanMake(0.02, 0.02)
        let region = MKCoordinateRegion(center: mapView.userLocation.coordinate, span: span)
        mapView.setCenter(mapView.userLocation.coordinate, animated: true)
        mapView.setRegion(region, animated: true)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
   
    func getDirections(to destination: MKMapItem) {
        
        self.lblPlace.text = destination.name
        if let address = destination.placemark.thoroughfare,
            let number = destination.placemark.subThoroughfare {
            self.lblAddress.text = "\(number) \(address)"
        }

        let sourcePlacemark = MKPlacemark(coordinate: currentCoordinate)
        let sourceMapItem = MKMapItem(placemark: sourcePlacemark)

        let directionsRequest = MKDirectionsRequest()
        directionsRequest.source = sourceMapItem
        directionsRequest.destination = destination
        directionsRequest.transportType = .walking

        let directions = MKDirections(request: directionsRequest)
        directions.calculate { (response, _) in
            guard let response = response else { return }
            guard let primaryRoute = response.routes.first else { return }

            self.mapView.add(primaryRoute.polyline)

            self.locationManager.monitoredRegions.forEach({ self.locationManager.stopMonitoring(for: $0) })

            self.steps = primaryRoute.steps
            for i in 0 ..< primaryRoute.steps.count {
                let step = primaryRoute.steps[i]
//                print(step.instructions)
//                print(step.distance)
                let region = CLCircularRegion(center: step.polyline.coordinate,
                                              radius: 5,
                                              identifier: "\(i)")
                self.locationManager.startMonitoring(for: region)
                let circle = MKCircle(center: region.center, radius: region.radius)
                self.mapView.add(circle)
            }
        }
    }
}



// MARK: - Location Manager Delegate
extension SearchController: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        manager.stopUpdatingLocation()
        guard let currentLocation = locations.first else { return }
        currentCoordinate = currentLocation.coordinate
        mapView.userTrackingMode = .follow
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
                print("ENTERED")
                stepCounter += 1
                if stepCounter < steps.count {
                    let currentStep = steps[stepCounter]
                    let message = "In \(currentStep.distance) meters, \(currentStep.instructions)"
                    directionsLabel.text = message
                    let speechUtterance = AVSpeechUtterance(string: message)
                    speechUtterance.voice = self.voice
                    self.speak.speak(speechUtterance)
                    
                } else {
                    let message = "Arrived at destination"
                    directionsLabel.text = message
                    let speechUtterance = AVSpeechUtterance(string: message)
                    speechUtterance.voice = self.voice
                    self.speak.speak(speechUtterance)
                    
                    stepCounter = 0
                    locationManager.monitoredRegions.forEach({ self.locationManager.stopMonitoring(for: $0) })
        
                }
            }
}

extension SearchController: HandleMapSearch {
    func closeSearch(){
        resultSearchController?.searchBar.text = ""
        resultSearchController?.searchBar.resignFirstResponder()
    }
    func dropPinZoomIn(placemark:MKPlacemark, mapItem:MKMapItem){
        // cache the pin
        selectedPin = placemark
        // clear existing pins
        mapView.removeAnnotations(mapView.annotations)
        let annotation = MKPointAnnotation()
        annotation.coordinate = placemark.coordinate
        annotation.title = placemark.name
        if let address = placemark.thoroughfare,
            let number = placemark.subThoroughfare {
            annotation.subtitle = "\(number) \(address)"
        }
        
        mapView.addAnnotation(annotation)
        let span = MKCoordinateSpanMake(0.05, 0.05)
        let region = MKCoordinateRegionMake(placemark.coordinate, span)
        mapView.setRegion(region, animated: true)
        
        // Set mapItem global
        mapDestination = mapItem
        self.getDirections(to: mapItem)
        
        self.StartNavViewConstraint.constant = 100
        startNavCover.isHidden = false
        self.buttonStartNavigation.isHidden = false
        UIView.animate(withDuration: 0.5) {
            self.view.layoutIfNeeded()
        }
        }
}

extension UIColor {
    convenience init(hex: String) {
        let scanner = Scanner(string: hex)
        scanner.scanLocation = 0
        
        var rgbValue: UInt64 = 0
        
        scanner.scanHexInt64(&rgbValue)
        
        let r = (rgbValue & 0xff0000) >> 16
        let g = (rgbValue & 0xff00) >> 8
        let b = rgbValue & 0xff
        
        self.init(
            red: CGFloat(r) / 0xff,
            green: CGFloat(g) / 0xff,
            blue: CGFloat(b) / 0xff, alpha: 1
        )
    }
}


// MARK: - Map View Delegate
extension SearchController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if overlay is MKPolyline {
            let renderer = MKPolylineRenderer(overlay: overlay)
            renderer.strokeColor = UIColor.ARMaps.appleBlue
            renderer.lineWidth = 6
            return renderer
        }
        if overlay is MKCircle {
            let renderer = MKCircleRenderer(overlay: overlay)
            renderer.strokeColor = UIColor.ARMaps.appleBlue
            renderer.fillColor = UIColor.ARMaps.appleBlue
            renderer.alpha = 0.25
            return renderer
        }
        return MKOverlayRenderer()
    }
}

extension UIColor {
    struct ARMaps {
        static let appleBlue = UIColor(hex: "007aff")
    }
}

