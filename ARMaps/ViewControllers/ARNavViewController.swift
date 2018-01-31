//
//  ARNavViewController.swift
//  ARMaps
//
//  Created by Ben Porter on 1/29/18.
//  Copyright © 2018 Ben Porter. All rights reserved.
//

import UIKit
import SceneKit
import ARCL
import CoreLocation
import MapKit
import AVFoundation

class ARNavViewController: UIViewController, SceneLocationViewDelegate{
    
    @IBOutlet weak var lblDirections: UILabel!
    @IBOutlet weak var buttonStop: UIButton!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var navView: UIView!
    
    let locationManager = CLLocationManager()
    var currentCoordinate: CLLocationCoordinate2D!
    var currentHeading:Double!
    var selectedPin:MKPlacemark? = nil
    
    var steps = [MKRouteStep]()
    var mapDestination:MKMapItem? = nil
    var sceneLocationView = SceneLocationView()
    var stepCounter = 0
    
    let voice = AVSpeechSynthesisVoice(language: "en-AU")
    let speak = AVSpeechSynthesizer()
    
    let distance: CLLocationDistance = 45
    let pitch: CGFloat = 75
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sceneLocationView.run()
        view.insertSubview(sceneLocationView, at: 0)
        
        mapView.layer.cornerRadius = 20
        mapView.layer.masksToBounds = true
        mapView.layer.opacity = 0.9
        mapView.isPitchEnabled = true
        
        navView.layer.cornerRadius = 20
        navView.layer.masksToBounds = false
        navView.layer.shadowOffset = CGSize(width: 1, height: -3)
        navView.layer.shadowColor = UIColor.black.cgColor
        navView.layer.shadowRadius = 1.0
        navView.layer.shadowOpacity = 0.2
       
        buttonStop.layer.cornerRadius = buttonStop.frame.height / 2
        buttonStop.layer.shadowColor = UIColor.black.cgColor
        buttonStop.layer.shadowOffset = CGSize(width: 0.0, height: 3.0)
        buttonStop.layer.shadowOpacity = 0.4
        buttonStop.layer.shadowRadius = 1.0
        buttonStop.layer.masksToBounds = false
        
        //Set to true to display an arrow which points north.
        //Checkout the comments in the property description and on the readme on this.
        //        sceneLocationView.orientToTrueNorth = false
        
        //        sceneLocationView.locationEstimateMethod = .coreLocationDataOnly
        sceneLocationView.showAxesNode = false
        sceneLocationView.locationDelegate = self
        let pinCoordinate = CLLocationCoordinate2D(latitude: (mapDestination?.placemark.coordinate.latitude)!, longitude: (mapDestination?.placemark.coordinate.longitude)!)
        let pinLocation = CLLocation(coordinate: pinCoordinate, altitude: 150)
        let pinImage = UIImage(named: "Pin")!
        
        let pinLocationNode = LocationAnnotationNode(location: pinLocation, image: pinImage)
        sceneLocationView.addLocationNodeWithConfirmedLocation(locationNode: pinLocationNode)
        
        locationManager.delegate = self
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        if CLLocationManager.locationServicesEnabled() {
            if (CLLocationManager.headingAvailable()) {
                locationManager.headingFilter = 1
                locationManager.startUpdatingHeading()
            }
            locationManager.startUpdatingLocation()
        }
        
        mapView.delegate = self
        mapView.showsUserLocation = true
        
        dropPin()
    }
    
    func dropPin(){
        // clear existing pins
        mapView.removeAnnotations(mapView.annotations)
        let annotation = MKPointAnnotation()
        annotation.coordinate = (selectedPin?.coordinate)!
        annotation.title = selectedPin?.name
        if let address = selectedPin?.thoroughfare,
            let number = selectedPin?.subThoroughfare {
            annotation.subtitle = "\(number) \(address)"
        }

        mapView.addAnnotation(annotation)
        let span = MKCoordinateSpanMake(0.025, 0.025)
        let center = currentCoordinate.middleLocationWith(location: (selectedPin?.coordinate)!)
        let region = MKCoordinateRegionMake(center, span)
        mapView.setRegion(region, animated: true)
        self.getDirections()
    }
    
    func getDirections() {
        
        let sourcePlacemark = MKPlacemark(coordinate: currentCoordinate)
        let sourceMapItem = MKMapItem(placemark: sourcePlacemark)
        
        let directionsRequest = MKDirectionsRequest()
        directionsRequest.source = sourceMapItem
        directionsRequest.destination = mapDestination
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
                let region = CLCircularRegion(center: step.polyline.coordinate,
                                              radius: 2,
                                              identifier: "\(i)")
                self.locationManager.startMonitoring(for: region)
                let circle = MKCircle(center: region.center, radius: region.radius)
                self.mapView.add(circle)
                let location: CLLocation =  CLLocation(latitude: step.polyline.coordinate.latitude, longitude: step.polyline.coordinate.longitude)
                let locationNode = LocationAnnotationNode(location: location, image: #imageLiteral(resourceName: "Pin"))
//                LocationNode
                self.sceneLocationView.addLocationNodeWithConfirmedLocation(locationNode: locationNode)
            }
        }
        
        //Speech synth
        let initialMessage = "In \(self.steps[0].distance) meters, \(self.steps[0].instructions) then in \(self.steps[1].distance) meters, \(self.steps[1].instructions)."
        self.lblDirections.text = initialMessage
        
        let coord = CLLocationCoordinate2D(latitude: self.steps[0].polyline.coordinate.latitude,
                                           longitude: self.steps[0].polyline.coordinate.longitude)
        
        let coord1 = CLLocation(latitude: self.steps[1].polyline.coordinate.latitude,
                                longitude: self.steps[1].polyline.coordinate.longitude)
        
        let coord2 = CLLocation(latitude: self.steps[1].polyline.coordinate.latitude,
                                           longitude: self.steps[1].polyline.coordinate.longitude)
//        let m = c.locationWithBearing(h, distance: distance)
        let heading = getBearingBetweenTwoPoints1(point1: coord1, point2: coord2)
//        let camera = MKMapCamera(lookingAtCenter: coord,
//                                 fromDistance: distance,
//                                 pitch: pitch,
//                                 heading: currentHeading)
//
//
//        mapView.camera = camera
        
        let speechUtterance = AVSpeechUtterance(string: initialMessage)
        speechUtterance.voice = self.voice
        self.speak.speak(speechUtterance)
        
        locationManager.allowsBackgroundLocationUpdates = true
        
        self.stepCounter += 1
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        sceneLocationView.run()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneLocationView.pause()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        sceneLocationView.frame = view.bounds
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    
    func degreesToRadians(degrees: Double) -> Double { return degrees * .pi / 180.0 }
    func radiansToDegrees(radians: Double) -> Double { return radians * 180.0 / .pi }
    
    func getBearingBetweenTwoPoints1(point1 : CLLocation, point2 : CLLocation) -> Double {
        
        let lat1 = degreesToRadians(degrees: point1.coordinate.latitude)
        let lon1 = degreesToRadians(degrees: point1.coordinate.longitude)
        
        let lat2 = degreesToRadians(degrees: point2.coordinate.latitude)
        let lon2 = degreesToRadians(degrees: point2.coordinate.longitude)
        
        let dLon = lon2 - lon1
        
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let radiansBearing = atan2(y, x)
        
        return radiansToDegrees(radians: radiansBearing)
    }
    
    @IBAction func buttonStopAction(_ sender: Any) {
        stepCounter = 0
        steps = [MKRouteStep]()
        self.speak.stopSpeaking(at: .immediate)
        let allAnnotations = self.mapView.annotations
        self.mapView.removeAnnotations(allAnnotations)
        let allOverlays = self.mapView.overlays
        self.mapView.removeOverlays(allOverlays)

        self.dismiss(animated: true, completion: nil)
    }
    

    //MARK: SceneLocationViewDelegate
    func sceneLocationViewDidAddSceneLocationEstimate(sceneLocationView: SceneLocationView, position: SCNVector3, location: CLLocation) {
    }
    
    func sceneLocationViewDidRemoveSceneLocationEstimate(sceneLocationView: SceneLocationView, position: SCNVector3, location: CLLocation) {
    }
    
    func sceneLocationViewDidConfirmLocationOfNode(sceneLocationView: SceneLocationView, node: LocationNode) {
    }
    
    func sceneLocationViewDidSetupSceneNode(sceneLocationView: SceneLocationView, sceneNode: SCNNode) {
        
    }
    
    func sceneLocationViewDidUpdateLocationAndScaleOfLocationNode(sceneLocationView: SceneLocationView, locationNode: LocationNode) {
        
    }
}




// MARK: - Map View Delegate
extension ARNavViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if overlay is MKPolyline {
            let renderer = CustomPolyline(overlay: overlay)
            renderer.strokeColor = UIColor.ARMaps.appleBlue
            renderer.lineWidth = 25
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


// MARK: - Location Manager Delegate
extension ARNavViewController: CLLocationManagerDelegate {
    
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
            let message = "\(currentStep.distance) meters, \(currentStep.instructions)"
            lblDirections.text = message
            let speechUtterance = AVSpeechUtterance(string: message)
            speechUtterance.voice = self.voice
            self.speak.speak(speechUtterance)
            let coord = CLLocationCoordinate2D(latitude: currentStep.polyline.coordinate.latitude,
                                              longitude: currentStep.polyline.coordinate.longitude)
            let camera = MKMapCamera(lookingAtCenter: coord,
                                 fromDistance: distance,
                                 pitch: pitch,
                                 heading: currentHeading)
            
            mapView.camera = camera
            
        } else {
            let message = "Arrived at destination"
            lblDirections.text = message
            let speechUtterance = AVSpeechUtterance(string: message)
            speechUtterance.voice = self.voice
            self.speak.speak(speechUtterance)
            
            stepCounter = 0
            locationManager.monitoredRegions.forEach({ self.locationManager.stopMonitoring(for: $0) })
            
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading heading: CLHeading) {
        currentHeading = heading.magneticHeading
        let currentStep = steps[stepCounter-1]
        let coord = CLLocationCoordinate2D(latitude: currentStep.polyline.coordinate.latitude,
                                           longitude: currentStep.polyline.coordinate.longitude)
        let camera = MKMapCamera(lookingAtCenter: coord,
                                 fromDistance: distance,
                                 pitch: pitch,
                                 heading: currentHeading)
        
        mapView.camera = camera

    }
}

extension CLLocationCoordinate2D {
    // MARK: CLLocationCoordinate2D+MidPoint
    func middleLocationWith(location:CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        
        let lon1 = longitude * .pi / 180
        let lon2 = location.longitude * .pi / 180
        let lat1 = latitude * .pi / 180
        let lat2 = location.latitude * .pi / 180
        let dLon = lon2 - lon1
        let x = cos(lat2) * cos(dLon)
        let y = cos(lat2) * sin(dLon)
        
        let lat3 = atan2( sin(lat1) + sin(lat2), sqrt((cos(lat1) + x) * (cos(lat1) + x) + y * y) )
        let lon3 = lon1 + atan2(y, cos(lat1) + x)
        
        let center:CLLocationCoordinate2D = CLLocationCoordinate2DMake(lat3 * 180 / .pi, lon3 * 180 / .pi)
        return center
    }
}
