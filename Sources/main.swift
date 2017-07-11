//
//  Main.swift
//  NotificationServer
//
//  Created by Uğurcan Polat on 1.07.2017.
//
//

import Foundation

import PerfectNotifications
import PerfectLib
import PerfectHTTPServer
import PerfectHTTP

let appId = "com.valensas.pushtest"

let apnsTeamIdentifier = "DX2793HJLK"
let apnsKeyIdentifier = "KQT6GAT6X6"
let apnsPrivateKey = "./AuthKey_\(apnsKeyIdentifier).p8"

let androidFCMSendUrl = "https://fcm.googleapis.com/fcm/send"
let androidServerKey = "AAAA6xdLi5w:APA91bHdVLqqOo4IDvT4Wado-g9GCSkR0Nro4qNCKMJcyD7yc2fNwkfE2McLlJjmUfTBW8XHGEXvWW_SC3h6jUQBZTC3e8KpS5_sLBGYqxm82nb61TkHaNmpSg7l5aLKtul4xyaSPWiv"

NotificationPusher.addConfigurationAPNS(name: appId,
                                        production: false,
                                        keyId: apnsKeyIdentifier,
                                        teamId: apnsTeamIdentifier,
                                        privateKeyPath: apnsPrivateKey)

class NotificationsHandler {
    var androidErrors = [[String:Any]]()
    var iOSErrors = [[String:Any]]()
    
    var numberOfSuccessiOS: Int = 0
    var numberOfFailureiOS: Int = 0
    
    var numberOfSuccessAndroid: Int = 0
    var numberOfFailureAndroid: Int = 0
    
    func notifyDevices(request: HTTPRequest, response: HTTPResponse) {
        // Empty error variables and numbers to avoid mixing up new errors with earlier error
        androidErrors.removeAll()
        iOSErrors.removeAll()
        numberOfSuccessiOS = 0
        numberOfFailureiOS = 0
        numberOfSuccessAndroid = 0
        numberOfFailureAndroid = 0
        
        var json = [String: Any]()
        
        let data = request.postBodyString!.data(using: .utf8)
        var pushDictionary = [String: Any]()
        
        response.addHeader(.contentType, value: "application/json")
        
        var iOS = [String:Any]()
        var android = [String:Any]()
        
        iOS.updateValue(numberOfSuccessiOS, forKey: "success")
        iOS.updateValue(numberOfFailureiOS, forKey: "fail")
        iOS.updateValue(iOSErrors, forKey: "error")
        
        android.updateValue(numberOfSuccessiOS, forKey: "success")
        android.updateValue(numberOfFailureiOS, forKey: "fail")
        android.updateValue(androidErrors, forKey: "error")
        
        json.updateValue(iOS, forKey: "iOS")
        json.updateValue(android, forKey: "android")
        
        do {
            pushDictionary = try JSONSerialization.jsonObject(with: data!, options: []) as! [String: Any]
        } catch {
            print("Wrong request format.")
            json.updateValue("Wrong request format", forKey: "Error")
            try? response.setBody(json: json).completed()
            return
        }
        
        if pushDictionary.isEmpty {
            print("Empty request body.")
            json.updateValue("Empty request body", forKey: "Error")
            try? response.setBody(json: json).completed()
            return
        }
        
        // If request is a payload use payload functions
        if pushDictionary["aps"] != nil {
            print("Sending notification to iOS device(s).")
            
            var deviceIds = [String]()
            
            // Check the "ids" key value if it is type of [String] or String
            if ((pushDictionary["ids"] as? [String]) != nil) {
                deviceIds = pushDictionary["ids"] as! [String]
            } else {
                deviceIds.append(pushDictionary["ids"] as! String)
            }
            
            // Send payload request
            sendNotificationRequestToAPNS(payload: pushDictionary, deviceIds: deviceIds) {
                iOSResult in
                var iOS = iOSResult
                iOS.updateValue(self.iOSErrors, forKey: "error")
                
                json.updateValue(iOS, forKey: "iOS")
                try? response.setBody(json: json).completed()
            }
            return
        } else if pushDictionary["body"] == nil {
            print("Sending notification to Android device(s).")
            sendNotificationRequestToFCM(payload: request.postBodyString!) {
                androidResult in
                var android = androidResult
                android.updateValue(self.androidErrors, forKey: "error")
                
                json.updateValue(android, forKey: "android")
                try? response.setBody(json: json).completed()
            }
            return
        }
        
        // Check if the "ids" has provided in the request or not
        if pushDictionary["ids"] == nil {
            print("Device ids have not been provided.")
            json.updateValue("Device ids have not been provided", forKey: "Error")
            try? response.setBody(json: json).completed()
            return
        }
        
        var deviceIds = [String]()
        
        // Check the "ids" key value if it is type of [String] or String
        if ((pushDictionary["ids"] as? [String]) != nil) {
            deviceIds = pushDictionary["ids"] as! [String]
        } else {
            deviceIds.append(pushDictionary["ids"] as! String)
        }
        
        var androidIds = [String]() // token length 152
        var iOSIds = [String]() // token length 64
        
        // Put device ids in the right place. If the length is 152, it is an Android id.
        // If the length is 64, it is an iOS id. If it does not fit to both cases, then
        // try them with both iOS and Android requests.
        for id in deviceIds {
            switch id.lengthOfBytes(using: .utf8) {
            case 64:
                iOSIds.append(id)
                break
            case 152:
                androidIds.append(id)
                break
            default:
                iOSIds.append(id)
                androidIds.append(id)
                break
            }
        }
        
        print("Sending notification to all devices.")
        
        // If there are iOS devices, send notification request.
        if iOSIds.count > 0 {
            sendNotificationRequestToAPNS(elements: pushDictionary, deviceIds: iOSIds) {
                iOSResult in
                var iOS = iOSResult
                iOS.updateValue(self.iOSErrors, forKey: "error")
                json.updateValue(iOS, forKey: "iOS")
                
                if androidIds.count > 0 { // Both iOS and Android devices case
                    self.sendNotificationRequestToFCM(elements: pushDictionary, deviceIds: androidIds) {
                        androidResult in
                        var android = androidResult
                        android.updateValue(self.androidErrors, forKey: "error")
                        json.updateValue(android, forKey: "android")
                        try? response.setBody(json: json).completed()
                    }
                } else { // Only iOS devices case
                    try? response.setBody(json: json).completed()
                }
            }
        } else if androidIds.count > 0 { // Only Android devices cases
            sendNotificationRequestToFCM(elements: pushDictionary, deviceIds: androidIds) {
                androidResult in
                var android = androidResult
                android.updateValue(self.androidErrors, forKey: "error")
                json.updateValue(android, forKey: "android")
                try? response.setBody(json: json).completed()
            }
        }
    }
    
    func sendNotificationRequestToAPNS(elements: [String:Any], deviceIds: [String],
                                       completionHandler: @escaping (_ json: [String:Any])->()) {
        var json = [String:Any]()
        var notificationItems = [APNSNotificationItem]()
        
        // Create APNSNotificationItem(s).
        for (key, value) in elements {
            switch key {
            case "title":
                notificationItems.append(APNSNotificationItem.alertTitle(value as! String))
                break
            case "body":
                notificationItems.append(APNSNotificationItem.alertBody(value as! String))
                break
            case "badge":
                notificationItems.append(APNSNotificationItem.badge(value as! Int))
                break
            case "sound":
                notificationItems.append(APNSNotificationItem.sound(value as! String))
                break
            default:
                break
            }
        }
        
        // Send notification
        NotificationPusher(apnsTopic: appId)
            .pushAPNS(configurationName: appId,
                      deviceTokens: deviceIds,
                      notificationItems: notificationItems) {
                        responses in
                        json = self.apnsResponseHandler(responses: responses, deviceIds: deviceIds)
                        completionHandler(json)
        }
    }
    
    func sendNotificationRequestToAPNS(payload: [String:Any], deviceIds: [String],
                                       completionHandler: @escaping (_ json: [String:Any])->()) {
        var json = [String:Any]()
        var notificationItems = [APNSNotificationItem]()
        var aps = [String:Any]()
        var alert = [String:Any]()
        
        if let apsTry = payload["aps"] as? [String: Any] {
            aps = apsTry
            if let alertTry = apsTry["alert"] as? [String:Any] {
                alert = alertTry
            } else if let alertTry = apsTry["alert"] as? String {
                alert["body"] = alertTry
            }
        }
        
        // Create APNSNotificationItem(s) of "aps" key
        for (key, value) in aps {
            switch key {
            case "badge":
                notificationItems.append(APNSNotificationItem.badge(value as! Int))
                break
            case "sound":
                notificationItems.append(APNSNotificationItem.sound(value as! String))
                break
            case "category":
                notificationItems.append(APNSNotificationItem.category(value as! String))
                break
            case "thread-id":
                notificationItems.append(APNSNotificationItem.threadId(value as! String))
                break
            case "content-available":
                notificationItems.append(APNSNotificationItem.contentAvailable)
                break
            default:
                break
            }
        }
        
        // Create APNSNotificationItem(s) of "alert" key of the "aps" key
        for (key, value) in alert {
            switch key {
            case "body":
                notificationItems.append(APNSNotificationItem.alertBody(value as! String))
                break
            case "title":
                notificationItems.append(APNSNotificationItem.alertTitle(value as! String))
                break
            case "action-loc-key":
                notificationItems.append(APNSNotificationItem.alertActionLoc(value as! String))
                break
            case "launch-image":
                notificationItems.append(APNSNotificationItem.alertLaunchImage(value as! String))
                break
            case "title-loc-key":
                if let args = alert["title-loc-args"] as? [String] {
                    notificationItems.append(APNSNotificationItem.alertTitleLoc(value as! String, args))
                }
                break
            case "loc-key":
                if let args = alert["loc-args"] as? [String] {
                    notificationItems.append(APNSNotificationItem.alertLoc(value as! String, args))
                }
                break
            case "loc-args":
                break
            case "title-loc-args":
                break
            default:
                notificationItems.append(APNSNotificationItem.customPayload(key, value))
                break
            }
        }
        
        // Create if there are any custon keys and values.
        for (key, value) in payload {
            switch key {
            case "aps":
                break
            case "ids":
                break
            default:
                notificationItems.append(APNSNotificationItem.customPayload(key, value))
                break
            }
        }
        
        // Send notification with the created items
        NotificationPusher(apnsTopic: appId)
            .pushAPNS(configurationName: appId,
                      deviceTokens: deviceIds,
                      notificationItems: notificationItems) {responses in
                        json = self.apnsResponseHandler(responses: responses, deviceIds: deviceIds)
                        completionHandler(json)
        }
    }
    
    func apnsResponseHandler(responses: [NotificationResponse], deviceIds: [String]) -> [String:Any] {
        var json = [String:Any]()
        var reason = ""
        // Check responses of all requests
        for response in responses {
            if response.status.code == 200 { // Success
                numberOfSuccessiOS += 1
                if deviceIds.count == 1 { // Only one device
                    logToMySQL(id: deviceIds[0], status: String(describing: response.status.code), description: "Sent")
                }
                
            } else { // Fail
                numberOfFailureiOS += 1
                reason = response.jsonObjectBody["reason"] as! String
                iOSErrors.append(["message":reason])
                if deviceIds.count == 1 { // Only one device
                    logToMySQL(id: deviceIds[0], status: String(describing: response.status.code), description: reason)
                }
            }
        }
        
        if deviceIds.count > 1 { // More than one device
            if numberOfSuccessiOS == deviceIds.count { // All success
                logToMySQL(id: "MultipleToken-iOS", status: "200", description: "Sent")
            } else if numberOfFailureiOS == deviceIds.count { // All fail
                logToMySQL(id: "MultipleToken-iOS", status: "400", description: reason)
            } else { // Some fail some success
                logToMySQL(id: "MultipleToken-iOS", status: "400", description: "Sent except some devices")
            }
        }
        
        if numberOfSuccessiOS > 0 {
            print("Notification has been sent to \(numberOfSuccessiOS) iOS device(s).")
        }
        
        if numberOfFailureiOS > 0 {
            print("Sending notification has failed for \(numberOfFailureiOS) iOS device(s).")
        }
        
        json.updateValue(numberOfSuccessiOS, forKey: "success")
        json.updateValue(numberOfFailureiOS, forKey: "fail")
        return json
    }
    
    func sendNotificationRequestToFCM(elements: [String:Any], deviceIds: [String],
                                      completionHandler: @escaping (_ json: [String:Any])->()) {
        var json = [String:Any]()
        var title: String?
        var body: String?
        var sound: String?
        
        for (key, value) in elements {
            switch key {
            case "title":
                title = value as? String
                break
            case "body":
                body = value as? String
                break
            case "sound":
                sound = value as? String
                break
            default:
                break
            }
        }
        
        var FCMRequest = URLRequest(url: URL(string: androidFCMSendUrl)!)
        FCMRequest.httpMethod = "POST"
        FCMRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        FCMRequest.setValue("key=\(androidServerKey)", forHTTPHeaderField: "Authorization")
        
        // Insert keys if they are provided.
        var bodyOfRequest = "{ \"notification\": {\n"
        if title != nil {
            bodyOfRequest += "\t\"title\": \"\(title ?? "")\",\n"
        }
        if body != nil {
            bodyOfRequest += "\t\"body\": \"\(body ?? "")\", \n"
        }
        if sound != nil {
            bodyOfRequest += "\t\"sound\": \"\(sound ?? "")\", \n"
        }
        
        // Insert registration_ids one by one
        bodyOfRequest += "},\n  \"registration_ids\": ["
        
        for c in 0..<(deviceIds.count) {
            if c < deviceIds.count - 1 {
                bodyOfRequest += "\"\(deviceIds[c])\","
            } else {
                bodyOfRequest += "\"\(deviceIds[c])\"]\n}"
            }
        }
        
        // Set HTTP request body
        FCMRequest.httpBody = bodyOfRequest.data(using: .utf8)
        
        // Send request
        let task = URLSession.shared.dataTask(with: FCMRequest) { (data, response, error) in
            guard let data = data, error == nil else {
                // Check for fundamental networking errors
                print("Sending request error for Android devices.")
                json.updateValue("Networking error", forKey: "error")
                completionHandler(json)
                return
            }
            
            if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 200 {
                json.updateValue("Error from FCM server: \(httpStatus.statusCode)", forKey: "error")
                completionHandler(json)
                return
            }
            
            var responseJSON = [String:Any]()
            
            // Response from FCM is in the JSON format
            do {
                responseJSON = try JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]
            } catch {
                print("Empty response from FCM.")
                json.updateValue("Empty response from FCM", forKey: "error")
                completionHandler(json)
                return
            }
            
            json = self.fcmResponseHandler(responseJSON: responseJSON, deviceIds: deviceIds)
            completionHandler(json)
        }
        // Resume the task since it is in the suspended state when it is created
        task.resume()
    }
    
    func sendNotificationRequestToFCM(payload: String, completionHandler: @escaping (_ json: [String:Any])->()) {
        var json = [String:Any]()
        
        var FCMRequest = URLRequest(url: URL(string: androidFCMSendUrl)!)
        FCMRequest.httpMethod = "POST"
        FCMRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        FCMRequest.setValue("key=\(androidServerKey)", forHTTPHeaderField: "Authorization")
        
        // Set the given payload directly as body of the request.
        FCMRequest.httpBody = payload.data(using: .utf8)
        
        // Send request
        let task = URLSession.shared.dataTask(with: FCMRequest) { (data, response, error) in
            guard let data = data, error == nil else {
                // Check for fundamental networking errors
                print("Sending request error for Android devices.")
                json.updateValue("Networking error", forKey: "error")
                completionHandler(json)
                return
            }
            
            if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 200 {
                print("Error from FCM server: \(httpStatus.statusCode)")
                json.updateValue("Error from FCM server: \(httpStatus.statusCode)", forKey: "error")
                completionHandler(json)
                return
            }
            
            var responseJSON = [String:Any]()
            
            // Response from FCM is in the JSON format
            do {
                responseJSON = try JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]
            } catch {
                print("Empty response from FCM.")
                json.updateValue("Empty response from FCM", forKey: "error")
                completionHandler(json)
                return
            }
            
            json = self.fcmResponseHandler(responseJSON: responseJSON, deviceIds: ["AndroidPayload"])
            completionHandler(json)
        }
        // Resume the task since it is in the suspended state when it is created
        task.resume()
    }
    
    func fcmResponseHandler(responseJSON: [String:Any], deviceIds: [String]) -> [String:Any]{
        var json = [String:Any]()
        
        let numberOfFails: Int = responseJSON["failure"] as! Int
        let numberOfSuccess: Int = responseJSON["success"] as! Int
        
        numberOfFailureAndroid = numberOfFails
        numberOfSuccessAndroid = numberOfSuccess
        
        let deviceCount = numberOfFails + numberOfSuccess
        
        if deviceCount == 1 { // Only one device
            if numberOfSuccess == 1 { // Success
                logToMySQL(id: deviceIds[0], status: "200", description: "Sent")
            } else if numberOfFails == 1 { // Fail
                let results = responseJSON["results"] as! [[String:Any]]
                for result in results {
                    if result["error"] != nil { // If error reason is provided, log it.
                        logToMySQL(id: deviceIds[0], status: "400", description: result["error"] as! String)
                        break
                    }
                }
            }
        } else if deviceCount > 1 { // More than one device
            if numberOfSuccess == deviceCount { // All success
                logToMySQL(id: "MultipleToken-Android", status: "200", description: "Sent")
            } else if numberOfFails == deviceCount { // All fail
                let results = responseJSON["results"] as! [[String:Any]]
                for result in results {
                    if result["error"] != nil { // If error reason is provided, log it.
                        logToMySQL(id: "MultipleToken-Android", status: "400", description: result["error"] as! String)
                        break
                    }
                }
            } else { // Some fail some success
                let results = responseJSON["results"] as! [[String:Any]]
                for result in results {
                    if result["error"] != nil { // If error reason is provided, log it.
                        logToMySQL(id: "MultipleToken-Android", status: "400", description: "Sent except some devices")
                        break
                    }
                }
            }
        }
        
        if numberOfSuccess > 0 {
            print("Notification has been sent to \(numberOfSuccess) Android device(s).")
        }
        
        if numberOfFails > 0 {
            let results = responseJSON["results"] as! [[String:Any]]
            for result in results {
                if result["error"] != nil {
                    androidErrors.append(["message":result["error"]!])
                }
            }
            print("Sending notification has failed for \(numberOfFails) Android device(s).")
        }
        json.updateValue(numberOfSuccess, forKey: "success")
        json.updateValue(numberOfFails, forKey: "fail")
        return json
    }
}

var handler = NotificationsHandler()

let routes = [
    Route(method: .post, uri: "/notify", handler: handler.notifyDevices),
]

do {
    // Launch the HTTP server
    try HTTPServer.launch(name: "localhost", port: 8181, routes: routes)
} catch {
    print("Unknown error thrown: \(error)")
}
