//
//  ViewController.swift
//  WatchTracker
//
//  Created by Simon Cook on 17/07/2016.
//  Copyright © 2016 Simon Cook. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import WatchConnectivity

class ViewController: UIViewController, MKMapViewDelegate, WCSessionDelegate, CLLocationManagerDelegate {

    var mapView: MKMapView!
    var locationManager: CLLocationManager!
    var session: WCSession?
    var lastFoundLocation: CLLocation?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        // start a watchconnectivity session
        startWatchKitSession();
        
        locationManager = CLLocationManager()
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        locationManager.delegate = self
        
        switch UIDevice.currentDevice().systemVersion.compare("9.0.0", options: NSStringCompareOptions.NumericSearch) {
            case .OrderedSame, .OrderedDescending:
                locationManager.requestWhenInUseAuthorization()
                locationManager.allowsBackgroundLocationUpdates = true
            case .OrderedAscending:
                locationManager.requestLocation()
        }
        // set up the map view
        mapView = MKMapView(frame: view.bounds)
        mapView.delegate = self
        mapView.showsUserLocation = true
        mapView.zoomEnabled = true
        
        // remove any current anotations
        addRemoveAnnotations(false)
        
        // add the map view
        view.addSubview(mapView)
        
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        locationManager.startUpdatingLocation()
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        locationManager.stopUpdatingLocation()
    }
    
    // *****************************************************
    // MKMapViewDelegate
    // *****************************************************
    
    // Method is called when the user's location gets updated
    func mapView(mapView: MKMapView, didUpdateUserLocation userLocation: MKUserLocation) {
        var region = MKCoordinateRegion()
        
        // Centre to the user's current location
        region.center = userLocation.coordinate
        region.span = MKCoordinateSpanMake(0.1, 0.1)
        mapView.setRegion(region, animated:true)
    }

    // Method is called to check if our location has changed
    // since last time.
    private func didLocationDistanceChange(updatedLocation: CLLocation) -> Bool {
        guard let lastQueriedLocation = lastFoundLocation else {
            return true
        }
        let distance =
            lastQueriedLocation.distanceFromLocation(updatedLocation)
        return distance > 400
    }
    
    // Method is called to check if our location has changed
    // since last time.
    private func updateWatchTrackerLocation(location: CLLocation) {
        
        // Check to see if our distance has changed
        if didLocationDistanceChange(location) == false { return }
        
        // Store our current location for next time round.
        print("WATCHTRACKER on iPhone: iPhone: Current location has been changed.")
        self.lastFoundLocation = location
        
        // Get our Coordinate for the location
        let coordinate = location.coordinate
        
        // Add the Pin Marker at each location
        addRemoveAnnotations(true, coordinate: coordinate)
        locationManager.allowDeferredLocationUpdatesUntilTraveled(400,
                                                                  timeout:60)
    }
    
    // *****************************************************
    // CLLocationManagerDelegate
    // *****************************************************
    func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        switch status
        {
        case .AuthorizedAlways:
            manager.requestAlwaysAuthorization()
        case .AuthorizedWhenInUse:
            manager.requestLocation()
        case .NotDetermined:
            manager.requestWhenInUseAuthorization()
        case .Restricted, .Denied:
            let title = "Location Services Disabled"
            let message = "Enable locations for this app via the Settings app on your iPhone."
            let alertController = UIAlertController(title: title,
                                                    message: message, preferredStyle: .Alert)
            
            // Set up the action for our Cancel Button
            let cancelAction = UIAlertAction(title: "Cancel", style:
                .Cancel, handler: nil)
            alertController.addAction(cancelAction)
            presentViewController(alertController, animated: true,
                                  completion: nil)
        }
    }
    
    // Method is called when updates will no longer be deferred.
    func locationManager(manager: CLLocationManager,
                         didFinishDeferredUpdatesWithError error: NSError?) {
        if error?.code == CLError.DeferredFailed.rawValue { return }
        print("WATCHTRACKER on iPhone: didFinishDeferredUpdatesWithError: \(error)")
    }
    
    // Method is called when we have received an updated user location
    func locationManager(manager: CLLocationManager,
                         didUpdateLocations locations: [CLLocation]) {
        guard let mostRecentLocation = locations.last else { return }
        updateSessionLocationDetails(mostRecentLocation)
        updateWatchTrackerLocation(mostRecentLocation)
    }
    
    // Method is called whenever we have encountered an issue with
    // getting location information
    func locationManager(manager: CLLocationManager, didFailWithError
        error: NSError) {
        if error.code == CLError.LocationUnknown.rawValue { return }
        print("WATCHTRACKER on iPhone: Failed to get a valid location: \(error)")
    }
    
    // Method to add/remove annotations from the MapView
    func addRemoveAnnotations(isAdding: Bool, coordinate: CLLocationCoordinate2D? = nil) {
        if isAdding == false
        {
            // Get an array of all annotations currently present on
            // the map and remove them.
            let allAnnotations = self.mapView.annotations
            if allAnnotations.count > 0 {
                self.mapView.removeAnnotations(allAnnotations)
            }
        }
        else {
            // Add the Pin marker at each location
            let annotation = MKPointAnnotation()
            annotation.coordinate = coordinate!
            self.mapView.addAnnotation(annotation)
        }
    }
    
    // *****************************************************
    // WCSessionDelegate
    // *****************************************************
    private func startWatchKitSession() {
        if (WCSession.isSupported()) {
            session = WCSession.defaultSession()
            session?.delegate = self
            session?.activateSession()
        }
    }

    func updateSessionLocationDetails(location: CLLocation) {
        guard let session = session else { return }
        print("WATCHTRACKER on iPhone: Set application context: (applicationContext)")
        let data = NSKeyedArchiver.archivedDataWithRootObject(location)
        let context = ["lastFoundLocation": data]
        do {
            try session.updateApplicationContext(context)
        } catch {
            print("WATCHTRACKER on iPhone: Update application context failed.")
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

