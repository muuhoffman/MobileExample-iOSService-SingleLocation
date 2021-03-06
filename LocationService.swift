//
//  LocationService.swift
//  PredixMobileReferenceApp
//
//  Created by Henderson, Jonathan (GE Global Research) on 2/3/16.
//  Copyright © 2016 GE. All rights reserved.
//

import Foundation

import PredixMobileSDK
import CoreLocation


enum Paths: String {
    case single
    case address
    case continuous
}

@objc class LocationService: NSObject, ServiceProtocol {
    
    // the path of our service
    static var serviceIdentifier: String { get { return "location" } }
    
    
    // meat of the service -- where requests to this service come in
    static func performRequest(request: NSURLRequest, response: NSHTTPURLResponse, responseReturn: responseReturnBlock, dataReturn: dataReturnBlock, requestComplete: requestCompleteBlock){
        
        
        // First let's examine the request. In this example, we're going to expect only a GET request, and the URL path should only contain "singlelocation"
        
        // we'll use a guard statement here just to verify the request object is valid. The HTTPMethod and URL properties of a NSURLRequest
        // are optional, and we need to ensure we're dealing with a request that contains them.
        guard let url = request.URL, path = url.path, method = request.HTTPMethod else
        {
            /* ****************************
            if the request does not contain a URL or a HTTPMethod, then we return a error. We'll also return an error if the URL
            does not contain a path. In a normal interaction this would never happen, but we need to be defensive and expect anything.
            
            we'll use one of the respondWithErrorStatus methods to return an error condition to the caller, in this case,
            a status code of 400 (Bad Request).
            
            Note that the respondWithErrorStatus methods all take the response object, the reponseReturn block and the requestComplete
            block. This is because the respondWithErrorStatus constructs an appropriate NSHTTPURLResponse object, and calls
            the reponseReturn and requestComplete blocks for you. Once a respondWithErrorStatus method is called, the performRequest
            method should not continue processing and should always return.
            **************************** */
            self.respondWithErrorStatus(.BadRequest, response, responseReturn, requestComplete)
            return
        }
        
        /* ****************************
        Path in this case should match the serviceIdentifier, or "location". We know the serviceIdentifier is all
        lower case, so we ensure the path is too before comparing.
        
        We use the serviceIdentifier property here rather than the string "location" as a general best practice of
        avoiding hard-coded strings in multiple places.
        
        In addition, we expect the query string to be nil, as no query parameters are expected in this call.
        
        In your own services you may want to be more lenient, simply ignoring extra path or parameters.
        **************************** */
        print("path: \(path)")
        
        switch path.lowercaseString {
        case "/location/single":
            LocationService.performRequestSingle(method, url: url, response: response, responseReturn: responseReturn, dataReturn: dataReturn, requestComplete: requestComplete)
        case "/location/address":
            LocationService.performRequestAddress(method, url: url, response: response, responseReturn: responseReturn, dataReturn: dataReturn, requestComplete: requestComplete)
        case "/location/distance":
            LocationService.performRequestDistance(method, url: url, response: response, responseReturn: responseReturn, dataReturn: dataReturn, requestComplete: requestComplete)
        default:
            self.respondWithErrorStatus(.BadRequest, response, responseReturn, requestComplete)
            return
        }
    }
    
    static func performRequestSingle(method: String, url: NSURL, response: NSHTTPURLResponse, responseReturn: responseReturnBlock, dataReturn: dataReturnBlock, requestComplete: requestCompleteBlock){
        
        guard url.query == nil else
        {
            // In this case, if the request URL is anything other than "http://pmapi/location/single" we're returning a 400 status code.
            self.respondWithErrorStatus(.BadRequest, response, responseReturn, requestComplete)
            return
        }
        
        // now that we know our path is what we expect, we'll check the HTTP method. If it's anything other than "GET"
        // we'll return a standard HTTP status used in that case.
        guard method == "GET" else
        {
            // According to the HTTP specification, a status code 405 (Method not allowed) must include an Allow header containing a list of valid methods.
            // this  demonstrates one way to accomplish this.
            let headers = ["Allow" : "GET"]
            
            // This respondWithErrorStatus overload allows additional headers to be passed that will be added to the response.
            self.respondWithErrorStatus(HTTPStatusCode.MethodNotAllowed, response, responseReturn, requestComplete, headers)
 
            return
        }
        
        
        var responseData = [String: AnyObject]()
        SingleLocationManager.fetchSingleLocation { (locationType) -> Void in
            switch locationType {
            case .Success(let location):
                responseData["status"] = "success"
                responseData["latitude"] = "\(location.coordinate.latitude)"
                responseData["longitude"] = "\(location.coordinate.longitude)"
            case .Error(let errorType):
                switch errorType {
                case .Error(let message):
                    responseData["status"] = "error"
                    responseData["message"] = message
                }
            }
            
            
            // NSJSONSerialization.dataWithJSONObject can throw, so we'll do this in a do/try/catch statement.
            do
            {
                let data = try NSJSONSerialization.dataWithJSONObject(responseData, options: NSJSONWritingOptions(rawValue: 0))
                
                
                // Now our JSON data object contains a serialized JSON dictionary ready for consumption by the caller.
                
                // Our service call is complete, now we call our blocks, in order.
                
                // the default response object is always pre-set with a 200 (OK) response code, so can be directly used when there are no problems.
                responseReturn(response)
                
                // we return the JSON object
                dataReturn(data)
                
                // An inform the caller the service call is complete
                requestComplete()
                
                // We don't need this return here, since we don't have any other code below, but in a more complex service call you may.
                // After requestComplete is called, you should always ensure no other code is executed in the method.
                return
            }
            catch let error
            {
                // Log the error
                PGSDKLogger.error("\(#function): JSON Serialization error: \(error)")
                
                // And return a 500 (Internal Server Error) status code reponse.
                self.respondWithErrorStatus(.InternalServerError, response, responseReturn, requestComplete)
                return
            }
        }
        
        
    }
    
    
    static func performRequestAddress(method: String, url: NSURL, response: NSHTTPURLResponse, responseReturn: responseReturnBlock, dataReturn: dataReturnBlock, requestComplete: requestCompleteBlock) {
        
        
        
        guard method == "GET" else
        {
            // According to the HTTP specification, a status code 405 (Method not allowed) must include an Allow header containing a list of valid methods.
            // this  demonstrates one way to accomplish this.
            let headers = ["Allow" : "GET"]
            
            // This respondWithErrorStatus overload allows additional headers to be passed that will be added to the response.
            self.respondWithErrorStatus(HTTPStatusCode.MethodNotAllowed, response, responseReturn, requestComplete, headers)
            
            return
        }
        
        guard let urlComponents = NSURLComponents(URL:url, resolvingAgainstBaseURL: false), queryItems = urlComponents.queryItems where queryItems.count == 2 else
        {
            self.respondWithErrorStatus(.BadRequest, description: "Expected exactly 2 query parameters: 'latitude' and 'longitude'", dataReturn: dataReturn, response: response, responseReturn: responseReturn, requestComplete: requestComplete)
            return
        }
        
        guard let latitudeIndex = queryItems.indexOf({ (queryItem) -> Bool in
            queryItem.name == "latitude"
        }),
        latitudeString = queryItems[latitudeIndex].value,
        latitude = Double(latitudeString)
        else {
            self.respondWithErrorStatus(.BadRequest, description: "Parameter 'latitude' of type Double not found in query", dataReturn: dataReturn, response: response, responseReturn: responseReturn, requestComplete: requestComplete)
            return
        }
        
        guard let longitudeIndex = queryItems.indexOf({ (queryItem) -> Bool in
            queryItem.name == "longitude"
        }),
        longitudeString = queryItems[longitudeIndex].value,
        longitude = Double(longitudeString)
        else {
            self.respondWithErrorStatus(.BadRequest, description: "Parameter 'longitude' of type Double not found in query", dataReturn: dataReturn, response: response, responseReturn: responseReturn, requestComplete: requestComplete)
            return
        }
        
        var responseData = [String: String]()
        GetReverseGeocode.getAddressPropertiesForLocationCoordinates(latitude, longitude: longitude) { (addressType) -> () in
            switch addressType {
            case .Success(let address):
                responseData = address
                responseData["status"] = "success"
            case .Error(let message):
                responseData["status"] = "error"
                responseData["message"] = message
            }
            
            
            // NSJSONSerialization.dataWithJSONObject can throw, so we'll do this in a do/try/catch statement.
            do
            {
                let data = try NSJSONSerialization.dataWithJSONObject(responseData, options: NSJSONWritingOptions(rawValue: 0))
                
                
                // Now our JSON data object contains a serialized JSON dictionary ready for consumption by the caller.
                
                // Our service call is complete, now we call our blocks, in order.
                
                // the default response object is always pre-set with a 200 (OK) response code, so can be directly used when there are no problems.
                responseReturn(response)
                
                // we return the JSON object
                dataReturn(data)
                
                // An inform the caller the service call is complete
                requestComplete()
                
                // We don't need this return here, since we don't have any other code below, but in a more complex service call you may.
                // After requestComplete is called, you should always ensure no other code is executed in the method.
                return
            }
            catch let error
            {
                // Log the error
                PGSDKLogger.error("\(#function): JSON Serialization error: \(error)")
                
                // And return a 500 (Internal Server Error) status code reponse.
                self.respondWithErrorStatus(.InternalServerError, response, responseReturn, requestComplete)
                return
            }
            
        }
    }
    
    static func performRequestDistance(method: String, url: NSURL, response: NSHTTPURLResponse, responseReturn: responseReturnBlock, dataReturn: dataReturnBlock, requestComplete: requestCompleteBlock) {
        
        guard method == "GET" else
        {
            // According to the HTTP specification, a status code 405 (Method not allowed) must include an Allow header containing a list of valid methods.
            // this  demonstrates one way to accomplish this.
            let headers = ["Allow" : "GET"]
            
            // This respondWithErrorStatus overload allows additional headers to be passed that will be added to the response.
            self.respondWithErrorStatus(HTTPStatusCode.MethodNotAllowed, response, responseReturn, requestComplete, headers)
            
            return
        }
        
        // Ensure exactly 2 query parameters
        guard let urlComponents = NSURLComponents(URL:url, resolvingAgainstBaseURL: false), queryItems = urlComponents.queryItems where queryItems.count == 2 else
        {
            self.respondWithErrorStatus(.BadRequest, description: "Expected exactly 2 query parameters: 'latitude' and 'longitude'", dataReturn: dataReturn, response: response, responseReturn: responseReturn, requestComplete: requestComplete)
            return
        }
        
        // Ensure latitude is a query parameter with a double value
        guard let latitudeIndex = queryItems.indexOf({ (queryItem) -> Bool in
            queryItem.name == "latitude"
        }),
            latitudeString = queryItems[latitudeIndex].value,
            latitude = Double(latitudeString)
            else {
                self.respondWithErrorStatus(.BadRequest, description: "Parameter 'latitude' of type Double not found in query", dataReturn: dataReturn, response: response, responseReturn: responseReturn, requestComplete: requestComplete)
                return
        }
        
        // Ensure longitude is a query parameter with a double value
        guard let longitudeIndex = queryItems.indexOf({ (queryItem) -> Bool in
            queryItem.name == "longitude"
        }),
            longitudeString = queryItems[longitudeIndex].value,
            longitude = Double(longitudeString)
            else {
                self.respondWithErrorStatus(.BadRequest, description: "Parameter 'longitude' of type Double not found in query", dataReturn: dataReturn, response: response, responseReturn: responseReturn, requestComplete: requestComplete)
                return
        }
        
        // Construct a CLLocation object
        let destination = CLLocation(latitude: latitude, longitude: longitude)
        
        var responseData = [String: AnyObject]()
        // Get the location
        SingleLocationManager.getDistanceToCoordinate(destination) { (distanceType) in
            switch distanceType {
            case let .Success(location, distance):
                responseData["status"] = "success"
                responseData["latitude"] = "\(location.coordinate.latitude)"
                responseData["longitude"] = "\(location.coordinate.longitude)"
                responseData["distance"] = "\(distance)"
            case .Error(let errorType):
                switch errorType {
                case .Error(let message):
                    responseData["status"] = "error"
                    responseData["message"] = message
                }
            }
        
            // NSJSONSerialization.dataWithJSONObject can throw, so we'll do this in a do/try/catch statement.
            do
            {
                let data = try NSJSONSerialization.dataWithJSONObject(responseData, options: NSJSONWritingOptions(rawValue: 0))
                
                
                // Now our JSON data object contains a serialized JSON dictionary ready for consumption by the caller.
                
                // Our service call is complete, now we call our blocks, in order.
                
                // the default response object is always pre-set with a 200 (OK) response code, so can be directly used when there are no problems.
                responseReturn(response)
                
                // we return the JSON object
                dataReturn(data)
                
                // An inform the caller the service call is complete
                requestComplete()
                
                // We don't need this return here, since we don't have any other code below, but in a more complex service call you may.
                // After requestComplete is called, you should always ensure no other code is executed in the method.
                return
            }
            catch let error
            {
                // Log the error
                PGSDKLogger.error("\(#function): JSON Serialization error: \(error)")
                
                // And return a 500 (Internal Server Error) status code reponse.
                self.respondWithErrorStatus(.InternalServerError, response, responseReturn, requestComplete)
                return
            }
        }
    }
}



    /* ****************************
    The methods "registered" and "unregistered" are optional in the ServiceProtocol protocol. They are called when your service
    is registered/unregistered in the ServiceRouter. The ServiceRouter controls which services are available in the system.
    When a service is registered it is then capable of receiving requests. When it is unregistered it will no longer receive requests.
    While services themselves are stateless, there may be times when they utilize non-stateless components, or need to prepare
    something in the system environment prior to being used. These methods allow for that type of interaction.
    For this example service we will not use them.
    **************************** */
    //static func registered(){}
    //static func unregistered(){}

