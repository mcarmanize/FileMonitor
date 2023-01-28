//
//  mongoGrid.c
//  FileMonitor
//
//  Created by Matthew Carman on 1/27/23.
//  Copyright © 2023 Patrick Wardle. All rights reserved.
//

#include "mongoGrid.h"

int upload_file(char* file_path, char* connection_string, char* file_oid_string) {
    mongoc_client_t *client;
    mongoc_database_t *db;
    mongoc_stream_t *file_stream;
    mongoc_gridfs_bucket_t *bucket;
    bool res;
    bson_value_t file_id;
    bson_error_t error;
    mongoc_init ();

    /* 1. Make a bucket. */
    client = mongoc_client_new (connection_string);
    db = mongoc_client_get_database (client, "esfriend_grid");
    bucket = mongoc_gridfs_bucket_new (db, NULL, NULL, &error);
    if (!bucket) {
      printf ("Error creating gridfs bucket: %s\n", error.message);
      return 0;
    }

    /* 2. Insert a file.  */
    file_stream = mongoc_stream_file_new_for_path (file_path, O_RDONLY, 0);
    res = mongoc_gridfs_bucket_upload_from_stream (
      bucket, file_path, file_stream, NULL, &file_id, &error);
    if (!res) {
      printf ("Error uploading file: %s\n", error.message);
      return 0;
    }
    
    // set the file_oid_string value
    const bson_oid_t file_oid = file_id.value.v_oid;
    bson_oid_to_string(&file_oid, file_oid_string);

    //cleanup
    mongoc_stream_close(file_stream);
    mongoc_stream_destroy(file_stream);
    mongoc_gridfs_bucket_destroy(bucket);
    mongoc_database_destroy(db);
    mongoc_client_destroy(client);
    mongoc_cleanup();
    
    return 1;
}
