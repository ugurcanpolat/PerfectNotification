//
//  mysqlHandler.swift
//  NotificationServer
//
//  Created by Uğurcan Polat on 4.07.2017.
//
//

import Foundation

import PerfectLib
import MySQL
import PerfectHTTP

let host = "127.0.0.1"
let port = 32771

let user = "root"
let password = "123456"

let dbName = "test"

let dataMysql = MySQL()

public func logToMySQL(requestTime: String, id: String, status: String) {
    // need to make sure something is available.
    guard dataMysql.connect(host: host, user: user, password: password, port: UInt32(port)) else {
        Log.info(message: "Failure connecting to data server \(host)")
        return
    }
    
    defer {
        dataMysql.close()  // defer ensures we close our db connection at the end of this request
    }

    guard dataMysql.selectDatabase(named: dbName) else {
        Log.info(message: "Failure: \(dataMysql.errorCode()) \(dataMysql.errorMessage())")
        return
    }
    
    if dataMysql.query(statement: "CREATE TABLE logs(time TIMESTAMP, id CHAR(255), status CHAR(10));") {
        print("Table created in the database.")
    }

    if dataMysql.query(statement: "INSERT INTO logs(time, id, status) VALUES('\(requestTime)', '\(id)', '\(status)');") {
        print("Record inserted to the database.")
    }
}

