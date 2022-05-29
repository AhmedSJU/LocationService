import Foundation
import CoreLocation
import Combine

public class LocationService: NSObject {
    private let locationManager = CLLocationManager()
    
    typealias AuthorizationRequest = Result<Void, LocationError>
    typealias LocationRequest = Result<CLLocation, LocationError>
    
    private var authorizationRequests: [(AuthorizationRequest) -> Void] = []
    private var locationRequests: [(LocationRequest) -> Void] = []
    
    var objectWillChange = PassthroughSubject<Void, Never>()
    var degrees: Double = .zero {
        didSet {
            objectWillChange.send()
        }
    }
    
    public override init() {
        super.init()
        locationManager.delegate = self
        if CLLocationManager.headingAvailable() {
            locationManager.startUpdatingHeading()
        }
    }

    public func requestWhenUseAuthorization() -> Future<Void, LocationError> {
        guard locationManager.authorizationStatus == .notDetermined else {
            return Future { $0(.success(())) }
        }
        let future = Future<Void, LocationError> { completion in
            self.authorizationRequests.append(completion)
        }
        locationManager.requestWhenInUseAuthorization()
        return future
    }
    
    public func requestLocation() -> Future<CLLocation, LocationError> {
        guard locationManager.authorizationStatus == .authorizedWhenInUse
                || locationManager.authorizationStatus == .authorizedAlways else {
                    return Future { $0(.failure(.unauthorized))}
                }
        let future = Future<CLLocation, LocationError> { completion in
            self.locationRequests.append(completion)
        }
        locationManager.requestLocation()
        return future
    }
    
    private func handleLocationRequestResult(_ result: LocationRequest) {
        while locationRequests.count > 0 {
            let request = locationRequests.removeFirst()
            request(result)
        }
    }
}

extension LocationService: CLLocationManagerDelegate {
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let locationError: LocationError
        if let error = error as? CLError, error.code == .denied {
            locationError = .unauthorized
        }
        else {
            locationError = .unableToDetermineLocation
        }
        handleLocationRequestResult(.failure(locationError))
    }
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            handleLocationRequestResult(.success(location))
        }
    }
    
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        while authorizationRequests.count > 0 {
            let request = authorizationRequests.removeFirst()
            request(.success(()))
        }
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        self.degrees = 1 * newHeading.magneticHeading
    }
}
