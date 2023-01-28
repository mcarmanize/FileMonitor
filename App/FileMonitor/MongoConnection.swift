//
//  MongoConnection.swift
//  FileMonitor
//
//  Created by Matthew Carman on 1/14/23.
//  Copyright © 2023 Patrick Wardle. All rights reserved.
//

import Foundation
import Darwin
import MongoSwift
import NIOPosix
import CLibMongoC
import Proc


@objcMembers class MongoConnection: NSObject {
    let elg: MultiThreadedEventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 4)
    var connectionString: String
    var jobIdentifier: String
    var jobIdentifierBSON: BSONObjectID
    var client: MongoClient
    var esfriend: MongoDatabase
    var esfriendGrid: OpaquePointer
    var runLogs: MongoDatabase
    
    init(initWithConnectionString connectionString: String, jobIdentifier: String) {
        self.connectionString = connectionString
        self.jobIdentifier = jobIdentifier
        do {
            try self.jobIdentifierBSON = BSONObjectID(self.jobIdentifier)
            self.client = try MongoClient(self.connectionString, using: elg)
            self.esfriend = self.client.db("esfriend")
            let clientPointer: UnsafeMutablePointer<MongoClient> = UnsafeMutablePointer(&self.client)
            self.esfriendGrid = mongoc_client_get_database(OpaquePointer(clientPointer), "esfriend_grid")
            self.runLogs = self.client.db("run_logs")
        } catch {
            print(error.localizedDescription)
            exit(1)
        }
    }
    
    func insertFileWithPath(_ filePath: URL) -> NSString {
        // this is broken
        let file_ptr = UnsafeMutablePointer(mutating: filePath.absoluteString)
        let connection_string_ptr = UnsafeMutablePointer(mutating: connectionString.description)
        let file_id = upload_file(file_ptr, connection_string_ptr)
        let fileIdentifier = NSString(utf8String: file_id)
        return fileIdentifier
    }
    
    func insertEvent(withFileIdentifier fileIdentifier: NSString, eventDescription: NSString) {
        do {
            let eslogCollection = self.runLogs.collection(jobIdentifier+"eslog")
            var newEventDescription = eventDescription.substring(to: eventDescription.length - 1)
            newEventDescription.append(contentsOf: ",\"file_id\":\"\(fileIdentifier)\"}")
            
            let eventBson = try BSONDocument(fromJSON: (newEventDescription as String))
            _ = eslogCollection.insertOne(eventBson)
            

        } catch {
            print(error.localizedDescription)
        }
    }
    
    func insertEvent(_ eventDescription: NSString) {
        do {
            let eslogCollection = self.runLogs.collection(jobIdentifier+"eslog")
            let eventBson = try BSONDocument(fromJSON: (eventDescription as String))
            _ = eslogCollection.insertOne(eventBson)
        } catch {
            print(error.localizedDescription)
        }
    }

    
    func cleanup() {
        try? self.client.syncClose()
        cleanupMongoSwift()
        try? self.elg.syncShutdownGracefully()
    }
}

