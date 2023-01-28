//
//  mongoGrid.h
//  FileMonitor
//
//  Created by Matthew Carman on 1/27/23.
//  Copyright © 2023 Patrick Wardle. All rights reserved.
//

#ifndef mongoGrid_h
#define mongoGrid_h

#include <stdio.h>
#include <stdlib.h>
#include <CLibMongoC.h>

//upload file_path to "esfriend_grid" database, using connection string
int upload_file(char* file_path, char* connection_string, char* file_oid_string);

#endif /* mongoGrid_h */
