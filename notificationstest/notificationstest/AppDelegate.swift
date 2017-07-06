//
//  AppDelegate.swift
//  NotificationsTestApp
//
//  Created by Uğurcan Polat on 1.07.2017.
//
//

import UIKit
import UserNotifications

let host = "172.16.42.139"
let port = 8181
let apiAdd = "/add/" // + deviceID
let apiList = "/list"
let apiNotify = "/notify"

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

	static var myself: AppDelegate?
	
	var window: UIWindow?
	var deviceToken: Data?
	var urlTask: URLSessionDataTask?
	
	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
		AppDelegate.myself = self
		
		let center = UNUserNotificationCenter.current()

		center.requestAuthorization(options: [.alert, .sound, .badge]) {
			granted, error in
			print("Requested permission for notifications: \(granted)")
			UIApplication.shared.registerForRemoteNotifications()
			center.delegate = self
		}
        
//        // Use Firebase library to configure APIs
//        FirebaseApp.configure()
		return true
	}
	
	func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
//        let token = Messaging.messaging().fcmToken
//        print("FCM token: \(token ?? "")")
        
		self.deviceToken = deviceToken
		sendAddDevice {
		}
	}
	
	func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Swift.Void) {
		completionHandler(.alert)
	}
	
	func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Swift.Void) {
		completionHandler()
	}
	
	// call the server endpoint which registers this device by its unique id
	func sendAddDevice(completion: @escaping () -> ()) {
		guard let deviceToken = deviceToken else {
			return
		}
		let hex = deviceToken.hexString
		let urlString = "http://\(host):\(port)\(apiAdd)\(hex)"
		guard let url = URL(string: urlString) else {
			return
		}
		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		request.httpBody = nil
		urlTask = URLSession.shared.dataTask(with: request) {
			response, data, error in
			guard nil == error else {
				print("Error registering device id: \(String(describing: error))")
				DispatchQueue.main.async {
					let alert = UIAlertController(title: "Error", message: "Error registering device id: \(error?.localizedDescription ?? "no msg")", preferredStyle: .alert)
					alert.addAction(UIAlertAction(title: "Bye!", style: .default, handler: { _ in }))
					self.window?.rootViewController?.present(alert, animated: true)
				}
				return
			}
			completion()
		}
		urlTask?.resume()
	}
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        if(UIApplication.shared.applicationIconBadgeNumber != 0){
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
    }
}

// utility
extension UInt8 {
	var hexString: String {
		var s = ""
		let b = self >> 4
		s.append(String(UnicodeScalar(b > 9 ? b - 10 + 65 : b + 48)))
		let b2 = self & 0x0F
		s.append(String(UnicodeScalar(b2 > 9 ? b2 - 10 + 65 : b2 + 48)))
		return s
	}
}


extension Data {
	var hexString: String {
		guard count > 0 else {
			return ""
		}
		let deviceIdLen = count
		let deviceIdBytes = self.withUnsafeBytes {
			ptr in
			return UnsafeBufferPointer<UInt8>(start: ptr, count: self.count)
		}
		var hexStr = ""
		for n in 0..<deviceIdLen {
			let b = deviceIdBytes[n]
			hexStr.append(b.hexString)
		}
		return hexStr
	}
}

