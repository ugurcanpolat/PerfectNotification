## Request ##

**REQUEST METHOD**

POST

**HEADER**

Content-Type: application/json

**BODY**

***Format of notification requests for both Android and iOS:***

<pre><code>{
    "title": "All Devices",
    "body": "PushNotification",
    "badge": 1,
    "sound": "default",
    "ids": ["FEBBDDA001311B449380D6550509257086448D3D99E2D0C4D5C33548102FB959", "068CFB2F3686365337C74DB6CA7AED240BCB7AC9C3AF3AF47A96CE01F27B1686", "cC54uZgatiM:APA91bFxAY8dc5y6lEWBUvGjLAvyQ6DTGAoGlo7Px1Ue6W4LyP8RL4LKJ7w2_KVL-NIgJsOXyy5uytVsIPsJfZp67u15Rj_V4F-ZBttsrN_vp-Q3JWsUJa65UGMMcw80Xg7pdEKhDXM9"]
}</code></pre>

*Note that you only have to provide "ids", other keys are optional. "badge" key is only acceptable for iOS requests, hence it does not affect Android requests.*

***Format of notification request for iOS with payload:***

<pre><code>{
    "aps" : {
        "alert" : {
            "title": "iOS Payload",
            "body" : "PushNotification"
        },
        "badge" : 3
    },
    "ids" : ["FEBBDDA001311B449380D6550509257086448D3D99E2D0C4D5C33548102FB959", "068CFB2F3686365337C74DB6CA7AED240BCB7AC9C3AF3AF47A96CE01F27B1686"]
}</code></pre>

*Since device IDs are necessary to send requests to APNS, "ids" key must be provided and will be used to send requests. This key is not part of original payload, hence it will not send to APNS server. Other than that, you can send payloads according to Apple's guide for remote notifications, but additionally you must provide "ids" key with device IDs.*

***Format of notification request for Android with payload:***

<pre><code>{ 
    "notification": {
        "title": "Android Payload",
        "body": "PushNotification"
    },
    "registration_ids" : ["cC54uZgatiM:APA91bFxAY8dc5y6lEWBUvGjLAvyQ6DTGAoGlo7Px1Ue6W4LyP8RL4LKJ7w2_KVL-NIgJsOXyy5uytVsIPsJfZp67u15Rj_V4F-ZBttsrN_vp-Q3JWsUJa65UGMMcw80Xg7pdEKhDXM9", "cC98uYgatiM:CBD91bFxAY8dc5y6lEWBUvGjLAvyQ6DTGAoGlo7Px1Ue6W4LyP8RL4LKJ7w2_KVL-NIgJsOXyy5uytVsIPsJfZp67u15Rj_V4F-ZBttsrN_vp-Q3JWsUJa65UGMMcw80Xg7pdEKhABC4"]
}</code></pre>

*Since device IDs is part of the payload for FCM requests, you should use "registration_ids" or "to" key with your payload. Unlike APNS, this keys will be sent to FCM. Since payload provided in the request will be sent directly to the FCM, you can send payloads according to Google's FCM guide for notifications without any restriction.*  

## Response ##

**HEADER**

Content-Type: application/json

**BODY**

*"success" and "fail" keys show number of successful and failed requests, respectively.*

***If there are no errors:***
<pre><code>{
    "iOS": {
        "success": 1
    },
    "android": {
        "success": 1
    }
}</code></pre>

***If there is an error:***

<pre><code>{
    "iOS": {
        "fail": 2,
        "error": [
            {
                "reason": "BadDeviceToken"
            },
            {
                "reason": "BadDeviceToken"
            }
        ],
        "success": 1
    },
    "android": {
        "fail": 2,
        "error": [
            {
                "error": "InvalidRegistration"
            },
            {
                "error": "InvalidRegistration"
            }
        ],
        "success": 1
    }
}</code></pre>

*"error" key of "android" and "iOS" keys contains error informations returned by FCM and APNS, respectively.*
