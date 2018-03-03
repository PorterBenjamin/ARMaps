//
//  ARNavViewController.swift
//  ARMaps
//
//  Created by Ben Porter on 1/29/18.
//  Copyright © 2018 Ben Porter. All rights reserved.
//

import UIKit
import SceneKit
//import ARKit
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
        
        sceneLocationView.showAxesNode = false
        sceneLocationView.locationDelegate = self
        
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
        
        
        
        let coordinate = CLLocationCoordinate2D(latitude: (mapDestination?.placemark.coordinate.latitude)!, longitude: (mapDestination?.placemark.coordinate.longitude)!)
        let location = CLLocation(coordinate: coordinate, altitude: 300)
        let circleNode = createConeNode(color: UIColor.ARMaps.appleBlue, location: location)
  
        sceneLocationView.addLocationNodeWithConfirmedLocation(locationNode: circleNode)

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
                
                //Displays current location mark
                
                let coordinate = CLLocationCoordinate2D(latitude: step.polyline.coordinate.latitude, longitude: step.polyline.coordinate.longitude)
                let location = CLLocation(coordinate: coordinate, altitude: 150)
                
                let circleNode = self.createSphereNode(color: UIColor.ARMaps.appleBlue, location: location)
                
                self.sceneLocationView.addLocationNodeWithConfirmedLocation(locationNode: circleNode)
                
                
            }
        }
        
        //Speech synth
        let initialMessage = "In \(self.steps[0].distance) meters, \(self.steps[0].instructions) then in \(self.steps[1].distance) meters, \(self.steps[1].instructions)."
        self.lblDirections.text = initialMessage
        
        let speechUtterance = AVSpeechUtterance(string: initialMessage)
        speechUtterance.voice = self.voice
        self.speak.speak(speechUtterance)
        
        locationManager.allowsBackgroundLocationUpdates = true
        
        self.stepCounter += 1
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Create a session configuration
//        let configuration = ARWorldTrackingConfiguration()
        // Run the view's session
//        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
//        sceneView.session.pause()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        sceneLocationView.frame = view.bounds
       
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
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
    
    
    func createConeNode(color: UIColor, location: CLLocation) -> LocationNode {
        let coneNode = LocationNode(location: location)
        let geometry = SCNCone(topRadius: 50, bottomRadius: 0, height: 200)
        geometry.firstMaterial?.diffuse.contents = color
        coneNode.geometry = geometry
        return coneNode
    }
    
    func createSphereNode(color: UIColor, location: CLLocation) -> LocationNode {
        let sphereNode = LocationNode(location: location)
        let geometry = SCNSphere(radius: 15)
        geometry.firstMaterial?.diffuse.contents = color
        sphereNode.geometry = geometry
        
        return sphereNode
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
            renderer.alpha = 0
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
    func locationManager(_ manager: CLLocationManager, didUpdateHeading heading: CLHeading) {
        currentHeading = heading.magneticHeading
        if stepCounter < steps.count {
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
