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

let notificationsTestId = "com.valensas.pushtest"

let apnsTeamIdentifier = "DX2793HJLK"
let apnsKeyIdentifier = "KQT6GAT6X6"
let apnsPrivateKey = "./AuthKey_\(apnsKeyIdentifier).p8"

let androidFCMSendUrl = "https://fcm.googleapis.com/fcm/send"
let androidServerKey = "AAAA6xdLi5w:APA91bHdVLqqOo4IDvT4Wado-g9GCSkR0Nro4qNCKMJcyD7yc2fNwkfE2McLlJjmUfTBW8XHGEXvWW_SC3h6jUQBZTC3e8KpS5_sLBGYqxm82nb61TkHaNmpSg7l5aLKtul4xyaSPWiv"

NotificationPusher.addConfigurationAPNS(name: notificationsTestId,
                                        production: false,
                                        keyId: apnsKeyIdentifier,
                                        teamId: apnsTeamIdentifier,
                                        privateKeyPath: apnsPrivateKey)

class NotificationsHandler {
    var deviceIds = [String]()
    
    func receiveDeviceId(request: HTTPRequest, response: HTTPResponse) {
        guard let deviceId = request.urlVariables["deviceid"] else {
            response.status = .badRequest
            return response.completed()
        }
        print("Adding device id:\(deviceId)")
        if !deviceIds.contains(deviceId) {
            deviceIds.append(deviceId)
        }
        try? response.setBody(json: [:]).completed()
    }
    
    func listDeviceIds(request: HTTPRequest, response: HTTPResponse) {
        try? response.setBody(json: ["deviceIds":self.deviceIds]).completed()
    }
    
    func notifyDevices(request: HTTPRequest, response: HTTPResponse) {
        print("Sending notification to all devices.")
        
        let data = request.postBodyString!.data(using: .utf8)
        var pushDictionary = [String: Any]()
        
        do {
            pushDictionary = try JSONSerialization.jsonObject(with: data!, options: []) as! [String: Any]
        } catch {
            print("Empty request body.")
            response.completed()
            return
        }
        
        let deviceIds: [String] = pushDictionary["ids"] as! [String]
        
        sendNotificationRequestToAPNS(deviceIds: deviceIds, title: pushDictionary["title"] as! String, body: pushDictionary["body"] as! String)
        response.completed()
    }
    
    func notifyAndroidDevices(request: HTTPRequest, response: HTTPResponse) {
        print("Sending notification to Android devices.")
        
        let data = request.postBodyString!.data(using: .utf8)
        var pushDictionary = [String: Any]()
        
        do {
            pushDictionary = try JSONSerialization.jsonObject(with: data!, options: []) as! [String: Any]
        } catch {
            print("Empty request body.")
            response.completed()
            return
        }
        
        let deviceIds: [String] = pushDictionary["to"] as! [String]
        
        sendNotificationRequestToFCM(deviceIds: deviceIds, title: pushDictionary["title"] as! String, body: pushDictionary["body"] as! String)
        response.completed()
    }
    
    func sendNotificationRequestToFCM(deviceIds: [String], title: String, body: String) {
        var FCMRequest = URLRequest(url: URL(string: androidFCMSendUrl)!)
        FCMRequest.httpMethod = "POST"
        FCMRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        FCMRequest.setValue("key=\(androidServerKey)", forHTTPHeaderField: "Authorization")
        
        var bodyOfRequest = "{ \"notification\": {\n\t\"title\": \"\(title)\",\n"
        bodyOfRequest += "\t\"body\": \"\(body)\"\n  },\n"
        
        bodyOfRequest += "  \"registration_ids\": ["
        
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
                return
            }
            
            if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 200 {
                return
            }
            
            var responseJSON = [String:Any]()
            
            do {
                responseJSON = try JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]
            } catch {
                print("Empty response from FCM.")
                return
            }
            
            let numberOfFails: Int = responseJSON["failure"] as! Int
            
            if numberOfFails > 0 {
                print("Sending notification has failed for \(numberOfFails) device(s).")
            }
        }
        // Resume the task since it is in the suspended state when it is created
        task.resume()
    }
    
    func sendNotificationRequestToAPNS(deviceIds: [String], title: String, body: String) {
        NotificationPusher(apnsTopic: notificationsTestId)
            .pushAPNS(configurationName: notificationsTestId,
                      deviceTokens: deviceIds,
                      notificationItems: [
                        .alertBody(body),
                        .alertTitle(title),
                        .badge(1),
                        .sound("default")]) {
                            responses in
                            for response in responses {
                                if response.status.code == 200 {
                                    print("Notification has been sent")
                                    for id in deviceIds {
                                        logToMySQL(id: id, status: "successful")
                                    }
                                    
                                } else {
                                    print("Error: Response status is \(response.status.code)")
                                    
                                    for id in deviceIds {
                                        logToMySQL(id: id, status: "error")
                                    }
                                }
                            }
        }
    }
}

var handler = NotificationsHandler()

let routes = [
    Route(method: .post, uri: "/add/{deviceid}", handler: handler.receiveDeviceId),
    Route(method: .get, uri: "/notify", handler: handler.notifyDevices),
    Route(method: .post, uri: "/notify", handler: handler.notifyDevices),
    Route(method: .post, uri: "/notifyAndroid", handler: handler.notifyAndroidDevices),
    Route(method: .get, uri: "/list", handler: handler.listDeviceIds)
]

do {
    // Launch the HTTP server
    try HTTPServer.launch(name: "localhost", port: 8181, routes: routes)
} catch {
    print("Unknown error thrown: \(error)")
}
