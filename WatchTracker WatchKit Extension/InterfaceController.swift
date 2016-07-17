//
//  InterfaceController.swift
//  WatchTracker WatchKit Extension
//
//  Created by Simon Cook on 17/07/2016.
//  Copyright © 2016 Simon Cook. All rights reserved.
//

import WatchKit
import Foundation
import CoreLocation
import WatchConnectivity


class InterfaceController: WKInterfaceController, WCSessionDelegate, CLLocationManagerDelegate {

    @IBOutlet var mapView: WKInterfaceMap!
    @IBOutlet var mapZoom: WKInterfaceSlider!
    
    // instantiate our location manager
    private let locationManager = CLLocationManager()
    private var session: WCSession?
    private var lastFoundLocation: CLLocation?
    
    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)
        
        self.mapView.removeAllAnnotations()
        
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        locationManager.delegate = self
        
        // Configure interface objects here.
    }

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        
        // start the watchconnectivity session
        startWatchKitSession()
        
        let authorizationStatus = CLLocationManager.authorizationStatus()
        handleLocationServicesAuthorizationStatus(authorizationStatus)
        
        if let lastUpdatedLocation = lastFoundLocation {
            queryWatchTrackerForLocation(lastUpdatedLocation)
        }
    }
    
    func handleLocationServicesAuthorizationStatus(status:CLAuthorizationStatus) {
        switch(status) {
        case .NotDetermined:
            locationManager.requestAlwaysAuthorization()
        case .Restricted, .Denied:
            print("WATCHTRACKER on watch:Locations Disabled\n\nEnable locations for this app via the settings on your iPhone")
        case .AuthorizedAlways, .AuthorizedWhenInUse:
            locationManager.requestLocation()
        }
    }
    
    
    func didLocationDistanceChange(updatedLocation: CLLocation) -> Bool {
        guard let latUpdatedLocation = lastFoundLocation else { return true}
        let distance = latUpdatedLocation.distanceFromLocation(latUpdatedLocation)
        return distance > 400
    }
    
    private func queryWatchTrackerForLocation(location: CLLocation) {
        if didLocationDistanceChange(location) == false {return}
        
        print("WATCHTRACKER on watch:  Current location has changed.")
        lastFoundLocation = location
        
        let coordinate = location.coordinate
        mapView.addAnnotation(coordinate, withPinColor: WKInterfaceMapPinColor.Red)
    }

    // CLLocationManagerDelegate method: invoked when a new
    // location arrives
    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Get our current location that has been determined
        print("Did update Locations: \(locations)")
        guard let mostRecentLocation = locations.last else { return }
        queryWatchTrackerForLocation(mostRecentLocation)
    }
    
    func locationManager(manager: CLLocationManager, didFailWithError error: NSError) {
        if error.code == CLError.LocationUnknown.rawValue { return }
        print("WATCHTRACKER on watch:Failed to get a valid location: \(error)")
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }

    @IBAction func handleMapZoom(value: Float) {
        let degrees  : CLLocationDegrees = CLLocationDegrees(value) / 10
        let span = MKCoordinateSpanMake(degrees, degrees)
        let region = MKCoordinateRegionMake((lastFoundLocation?.coordinate)!, span)
        mapView.setRegion(region)
        print("WATCHTRACKER on watch:Changed zoom level to \(value)")
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
    
    func session(session: WCSession, didReceiveApplicationContext
        applicationContext: [String : AnyObject]) {
        print("WATCHTRACKER on watch: Received application context:(applicationContext)")
        guard let data = applicationContext["lastFoundLocation"] as?
        NSData else { return }
        guard let location =
            NSKeyedUnarchiver.unarchiveObjectWithData(data) as? CLLocation
            else { return }
        queryWatchTrackerForLocation(location)
    }
}
