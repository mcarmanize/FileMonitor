//
//  mongoGrid.c
//  FileMonitor
//
//  Created by Matthew Carman on 1/27/23.
//  Copyright © 2023 Patrick Wardle. All rights reserved.
//

#include "mongoGrid.h"

char* upload_file(char* file_path, char* connection_string) {
    mongoc_client_t *client;
    mongoc_database_t *db;
    mongoc_stream_t *file_stream;
    mongoc_gridfs_bucket_t *bucket;
    mongoc_cursor_t *cursor;
    bson_t filter;
    bool res;
    bson_value_t file_id;
    bson_error_t error;
    const bson_t *doc;
    char *str;
    mongoc_init ();
    
    char* ret_error = "error";


    /* 1. Make a bucket. */
    client = mongoc_client_new (connection_string);
    db = mongoc_client_get_database (client, "esfriend_grid");
    bucket = mongoc_gridfs_bucket_new (db, NULL, NULL, &error);
    if (!bucket) {
      printf ("Error creating gridfs bucket: %s\n", error.message);
      return ret_error;
    }

    /* 2. Insert a file.  */
    file_stream = mongoc_stream_file_new_for_path (file_path, O_RDONLY, 0);
    res = mongoc_gridfs_bucket_upload_from_stream (
      bucket, file_path, file_stream, NULL, &file_id, &error);
    if (!res) {
      printf ("Error uploading file: %s\n", error.message);
      return ret_error;
    }

    mongoc_stream_close (file_stream);
    mongoc_stream_destroy (file_stream);
    
    const size_t file_id_len = sizeof(bson_value_t);
    char file_id_string[file_id_len + 1];
    void* file_id_ptr = &file_id;
    
    memcpy(file_id_string, file_id_ptr, file_id_len);
    
    return file_id_string;
}
