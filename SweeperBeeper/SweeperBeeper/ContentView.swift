//
//  ContentView.swift
//  SweeperBeeper
//
//  Created by Quinn C on 1/29/25.
//

import SwiftUI
import CoreLocation
import CoreLocationUI
import Combine
import Contacts

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private var locationManager: CLLocationManager
    @Published var currentLocation: CLLocation?
    @Published var roadName: String?
    @Published var number: String?
    @Published var postal: CNPostalAddress?
    @Published var locationPermissionDenied = false
    
    override init() {
        locationManager = CLLocationManager()
        super.init()
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
    }
    
    func requestWhenInUse(){
        locationManager.requestWhenInUseAuthorization()
    }
    
    // Request location when the button is clicked
    func requestLocation() {
        locationManager.requestLocation()
    }
    
    // CLLocationManagerDelegate methods
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            self.currentLocation = location
            reverseGeocode(location)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Failed to get location: \(error.localizedDescription)")
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .denied || status == .restricted {
            locationPermissionDenied = true
        }
    }
    
    private func reverseGeocode(_ location: CLLocation) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let error = error {
                print("Geocoding error: \(error.localizedDescription)")
                return
            }
            
            if let placemark = placemarks?.first {
//                print(placemark.thoroughfare)
                if let road = placemark.thoroughfare, let number = placemark.subThoroughfare, let postal = placemark.postalAddress {
                    self.roadName = road
                    self.number = number
                    self.postal = postal
                } else {
                    self.roadName = "No road name found"
                }
            }
        }
    }
}

import SwiftUI

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    
    var body: some View {
        VStack {
            Image(systemName: "car")
                .imageScale(.large)
            Button(action: {
                locationManager.requestLocation()
            }) {
                Text("Park me")
                    .frame(width: /*@START_MENU_TOKEN@*/100/*@END_MENU_TOKEN@*/)
                    .fontWeight(.heavy)
                    .padding()
                    .background(.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            VStack {
                if let location = locationManager.currentLocation {
                    Text("Latitude: \(location.coordinate.latitude)")
                        .padding()
                    Text("Longitude: \(location.coordinate.longitude)")
                        .padding()
                    Text("\(location.timestamp)")
                        .padding()
                    if let postal = locationManager.postal {
                        
                        Text("\(postal.street)\n\(postal.city), \(postal.state) \(postal.postalCode)\n\(postal.country)")
                            .frame(width: 200)
                            .padding()
                    }
                }
            }
        }
        .onAppear {
            if CLLocationManager.locationServicesEnabled() {
                locationManager.requestWhenInUse()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

//struct ContentView: View {
//    private var location = Location()
//    var body: some View {
//        VStack {
//            Image(systemName: "car")
//                .imageScale(.large)
//                .foregroundStyle(.tint)
//            Button("Park Me") {
//                try await location.requestPermission(.whenInUse) // obtain the permissions
//                let userLocation = try await location.requestLocation() // get the location
//            }
//            .padding()
//            .background(.orange)
//            .foregroundColor(.white)
//            .cornerRadius(10)
//            
//        }
//        .onAppear(){
//        }
//        .padding()
//    }
//}
//
//#Preview {
//    ContentView()
//}
