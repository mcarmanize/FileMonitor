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
            var clientPointer: UnsafeMutablePointer<MongoClient> = UnsafeMutablePointer(&self.client)
            self.esfriendGrid = mongoc_client_get_database(OpaquePointer(clientPointer), "esfriend_grid")
            self.runLogs = self.client.db("run_logs")
        } catch {
            print(error.localizedDescription)
            exit(1)
        }
    }
    
    func insertFileWithPath(_ filePath: URL) -> bson_value_t {
        var fileIdentifier: bson_value_t = bson_value_t()
        var error: bson_error_t = bson_error_t()
        let fileStream = mongoc_stream_file_new_for_path(filePath.absoluteString, O_RDONLY, 0)
        let result = mongoc_gridfs_bucket_upload_from_stream(self.esfriendGrid, filePath.lastPathComponent, fileStream, nil, &fileIdentifier, &error)
        if !result {
            print("Error uploading \(filePath.absoluteString)\n\nError:\n\(error.message)")
        }
        mongoc_stream_close(fileStream)
        mongoc_stream_destroy(fileStream)
        return fileIdentifier
    }
    
    func insertEvent(withFileIdentifier fileIdentifier: bson_value_t, eventDescription: NSString) {
        do {
            let eslogCollection = self.runLogs.collection(jobIdentifier+"eslog")
            let filesCollection = self.runLogs.collection(jobIdentifier+"files")
            
            var fileDict = [String:Any]()
            fileDict["file_id"] = fileIdentifier
            fileDict["upload_success"] = true
            let eventData = eventDescription.data(using: NSUTF8StringEncoding)!
            let eventJson = try JSONSerialization.jsonObject(with: eventData)
            if var eventDictionary = eventJson as? [String: Any] {
                if let file = eventDictionary["file"] as? [String:Any] {
                    if let destination = file["destination"] as? String {
                        fileDict["file_path"] = destination
                    }
                    if let process = file["process"] as? [String:Any] {
                        if let path = process["path"] as? String {
                            fileDict["process_path"] = path
                            eventDictionary["process_path"] = path
                        }
                        if let ppid = process["ppid"] as? pid_t {
                            let pcommand = Proc.pidPath(ppid)
                            fileDict["pcommand"] = pcommand
                            eventDictionary["pcommand"] = pcommand
                        }
                        if let rpid = process["rpid"] as? pid_t {
                            let rcommand = Proc.pidPath(rpid)
                            fileDict["rcommand"] = rcommand
                            eventDictionary["rcommand"] = rcommand
                        }
                    }
                }
                let fileJson = try JSONSerialization.data(withJSONObject: fileDict)
                let fileBson = try BSONDocument(fromJSON: fileJson)
                let eventJson = try JSONSerialization.data(withJSONObject: eventDictionary)
                let eventBson = try BSONDocument(fromJSON: eventJson)
                filesCollection.insertOne(fileBson)
                eslogCollection.insertOne(eventBson)
            }
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func insertEvent(_ eventDescription: NSString) {
        do {
            let eslogCollection = self.runLogs.collection(jobIdentifier+"eslog")
            let filesCollection = self.runLogs.collection(jobIdentifier+"files")
            
            let eventData = eventDescription.data(using: NSUTF8StringEncoding)!
            let eventJson = try JSONSerialization.jsonObject(with: eventData)
            if var eventDictionary = eventJson as? [String: Any] {
                if let file = eventDictionary["file"] as? [String:Any] {
                    if let process = file["process"] as? [String:Any] {
                        if let path = process["path"] as? String {
                            eventDictionary["process_path"] = path
                        }
                        if let ppid = process["ppid"] as? pid_t {
                            let pcommand = Proc.pidPath(ppid)
                            eventDictionary["pcommand"] = pcommand
                        }
                        if let rpid = process["rpid"] as? pid_t {
                            let rcommand = Proc.pidPath(rpid)
                            eventDictionary["rcommand"] = rcommand
                        }
                    }
                }
                let eventJson = try JSONSerialization.data(withJSONObject: eventDictionary)
                let eventBson = try BSONDocument(fromJSON: eventJson)
                let eventInsertResult = eslogCollection.insertOne(eventBson)
            }
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
