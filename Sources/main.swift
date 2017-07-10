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
    func notifyDevices(request: HTTPRequest, response: HTTPResponse) {
        var json = [String: Any]()
        
        let data = request.postBodyString!.data(using: .utf8)
        var pushDictionary = [String: Any]()
        
        do {
            pushDictionary = try JSONSerialization.jsonObject(with: data!, options: []) as! [String: Any]
        } catch {
            print("Empty request body.")
            response.setBody(string: "Empty request body").completed()
            return
        }
        
        response.addHeader(.contentType, value: "application/json")
        
        // If request is a payload use payload functions
        if pushDictionary["aps"] != nil {
            print("Sending notification to iOS device(s).")
            
            var deviceIds = [String]()
            
            if ((pushDictionary["ids"] as? [String]) != nil) {
                deviceIds = pushDictionary["ids"] as! [String]
            } else {
                deviceIds.append(pushDictionary["ids"] as! String)
            }
            
            sendNotificationRequestToAPNS(payload: pushDictionary, deviceIds: deviceIds) {
                iOSResult in
                json.updateValue(iOSResult, forKey: "iOS")
                try? response.setBody(json: json).completed()
            }
            return
        } else if pushDictionary["body"] == nil {
            print("Sending notification to Android device(s).")
            sendNotificationRequestToFCM(payload: request.postBodyString!) {
                androidResult in
                json.updateValue(androidResult, forKey: "Android")
                try? response.setBody(json: json).completed()
            }
            return
        }
        
        if pushDictionary["ids"] == nil {
            print("Device ids have not been provided.")
            response.setBody(string: "Device ids have not been provided.").completed()
            return
        }
        
        var deviceIds = [String]()
        
        if ((pushDictionary["ids"] as? [String]) != nil) {
            deviceIds = pushDictionary["ids"] as! [String]
        } else {
            deviceIds.append(pushDictionary["ids"] as! String)
        }
        
        var androidIds = [String]() // token length 152
        var iOSIds = [String]() // token length 64
        
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
        
        if iOSIds.count > 0 {
            sendNotificationRequestToAPNS(elements: pushDictionary, deviceIds: iOSIds) {
                iOSResult in
                json.updateValue(iOSResult, forKey: "iOS")
                
                if androidIds.count > 0 {
                    self.sendNotificationRequestToFCM(elements: pushDictionary, deviceIds: androidIds) {
                        androidResult in
                        json.updateValue(androidResult, forKey: "Android")
                        try? response.setBody(json: json).completed()
                    }
                } else {
                    try? response.setBody(json: json).completed()
                }
            }
        } else if androidIds.count > 0 {
            sendNotificationRequestToFCM(elements: pushDictionary, deviceIds: androidIds) {
                androidResult in
                json.updateValue(androidResult, forKey: "Android")
                try? response.setBody(json: json).completed()
            }
        }
    }
    
    func sendNotificationRequestToAPNS(elements: [String:Any], deviceIds: [String],
                                       completionHandler: @escaping (_ json: [String:Any])->()) {
        var json = [String:Any]()
        var notificationItems = [APNSNotificationItem]()
        
        var numberOfSuccess: Int = 0
        var numberOfFailure: Int = 0
        
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
        
        NotificationPusher(apnsTopic: appId)
            .pushAPNS(configurationName: appId,
                      deviceTokens: deviceIds,
                      notificationItems: notificationItems) {
                        responses in
                        for response in responses {
                            if response.status.code == 200 {
                                numberOfSuccess += 1
                                for id in deviceIds {
                                    logToMySQL(id: id, status: "successful")
                                }
                                
                            } else {
                                print("Error: Response status is \(response.status.code)")
                                numberOfFailure += 1
                                for id in deviceIds {
                                    logToMySQL(id: id, status: "error")
                                }
                            }
                        }
                        
                        if numberOfSuccess > 0 {
                            print("Notification has been sent to \(numberOfSuccess) iOS device(s).")
                            json.updateValue(numberOfSuccess, forKey: "success")
                        }
                        
                        if numberOfFailure > 0 {
                            print("Sending notification has failed for \(numberOfFailure) iOS device(s).")
                            json.updateValue(numberOfFailure, forKey: "fail")
                        }
                        completionHandler(json)
        }
    }
    
    func sendNotificationRequestToAPNS(payload: [String:Any], deviceIds: [String], completionHandler: @escaping (_ json: [String:Any])->()) {
        var json = [String:Any]()
        var notificationItems = [APNSNotificationItem]()
        var aps = [String:Any]()
        var alert = [String:Any]()
        
        var numberOfSuccess: Int = 0
        var numberOfFailure: Int = 0
        
        if let apsTry = payload["aps"] as? [String: Any] {
            aps = apsTry
            if let alertTry = apsTry["alert"] as? [String:Any] {
                alert = alertTry
            } else if let alertTry = apsTry["alert"] as? String {
                alert["body"] = alertTry
            }
        }
        
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
            default:
                notificationItems.append(APNSNotificationItem.customPayload(key, value))
                break
            }
        }
        
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
        
        NotificationPusher(apnsTopic: appId)
            .pushAPNS(configurationName: appId,
                      deviceTokens: deviceIds,
                      notificationItems: notificationItems) {responses in
                        for response in responses {
                            if response.status.code == 200 {
                                numberOfSuccess += 1
                                for id in deviceIds {
                                    logToMySQL(id: id, status: "successful")
                                }
                                
                            } else {
                                print("Error: Response status is \(response.status.code)")
                                numberOfFailure += 1
                                for id in deviceIds {
                                    logToMySQL(id: id, status: "error")
                                }
                            }
                        }
                        
                        if numberOfSuccess > 0 {
                            print("Notification has been sent to \(numberOfSuccess) iOS device(s).")
                            json.updateValue(numberOfSuccess, forKey: "success")
                        }
                        
                        if numberOfFailure > 0 {
                            print("Sending notification has failed for \(numberOfFailure) iOS device(s).")
                            json.updateValue(numberOfFailure, forKey: "fail")
                        }
                        completionHandler(json)
        }
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
        
        bodyOfRequest += "},\n  \"registration_ids\": ["
        
        for c in 0..<(deviceIds.count) {
            if c < deviceIds.count - 1 {
                bodyOfRequest += "\"\(deviceIds[c])\","
            } else {
                bodyOfRequest += "\"\(deviceIds[c])\"]\n}"
            }
        }
        
        FCMRequest.httpBody = bodyOfRequest.data(using: .utf8)
        
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
            
            do {
                responseJSON = try JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]
            } catch {
                print("Empty response from FCM.")
                json.updateValue("Empty response from FCM", forKey: "error")
                completionHandler(json)
                return
            }
            
            let numberOfFails: Int = responseJSON["failure"] as! Int
            let numberOfSuccess: Int = responseJSON["success"] as! Int
            
            if numberOfSuccess > 0 {
                print("Notification has been sent to \(numberOfSuccess) Android device(s).")
                json.updateValue(numberOfSuccess, forKey: "success")
            }
            
            if numberOfFails > 0 {
                print("Sending notification has failed for \(numberOfFails) Android device(s).")
                json.updateValue(numberOfFails, forKey: "fail")
            }
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
        
        FCMRequest.httpBody = payload.data(using: .utf8)
        
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
            
            do {
                responseJSON = try JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]
            } catch {
                print("Empty response from FCM.")
                json.updateValue("Empty response from FCM", forKey: "error")
                completionHandler(json)
                return
            }
            
            let numberOfFails: Int = responseJSON["failure"] as! Int
            let numberOfSuccess: Int = responseJSON["success"] as! Int
            
            if numberOfSuccess > 0 {
                print("Notification has been sent to \(numberOfSuccess) Android device(s).")
                json.updateValue(numberOfSuccess, forKey: "success")
            }
            
            if numberOfFails > 0 {
                print("Sending notification has failed for \(numberOfFails) Android device(s).")
                json.updateValue(numberOfFails, forKey: "fail")
            }
            completionHandler(json)
        }
        // Resume the task since it is in the suspended state when it is created
        task.resume()
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
