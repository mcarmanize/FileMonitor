//
//  utilities.h
//  FileMonitor
//
//  Created by Patrick Wardle on 9/1/19.
//  Copyright © 2020 Objective-See. All rights reserved.
//

#ifndef utilities_h
#define utilities_h

#import <Foundation/Foundation.h>
#import <EndpointSecurity/EndpointSecurity.h>

//convert es_string_token_t to string
NSString* convertStringToken(es_string_token_t* stringToken);

//return pointer to char array with path
char* pid_path(pid_t pid);

//modify buffer from argument - not working
int pid_path2(pid_t pid, char (*buffer)[]);

#endif /* utilities_h */
