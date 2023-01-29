//
//  utilities.m
//  FileMonitor
//
//  Created by Patrick Wardle on 9/1/19.
//  Copyright © 2020 Objective-See. All rights reserved.
//

#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <libproc.h>
#import "utilities.h"

//convert es_string_token_t to string
NSString* convertStringToken(es_string_token_t* stringToken)
{
    //string
    NSString* string = nil;
    
    //sanity check(s)
    if( (NULL == stringToken) ||
        (NULL == stringToken->data) ||
        (stringToken->length <= 0) )
    {
        //bail
        goto bail;
    }
        
    //convert to data, then to string
    string = [[NSString alloc] initWithBytes:stringToken->data length:stringToken->length encoding:NSUTF8StringEncoding];
    
bail:
    
    return string;
}

//return pointer to char array with path
char* pid_path(pid_t pid)
{
    int ret;
    static char pathbuf[PROC_PIDPATHINFO_MAXSIZE];

    ret = proc_pidpath(pid, pathbuf, sizeof(pathbuf));
    if ( ret <= 0 )
    {
//        fprintf(stderr, "PID %d: proc_pidpath ();\n", pid);
//        fprintf(stderr, "    %s\n", strerror(errno));
        return 0;
    }
//    else
//    {
//        printf("proc %d: %s\n", pid, pathbuf);
//    }

    return pathbuf;
}


// this doesn't work for some reason
int pid_path2(pid_t pid, char (*buffer)[])
{
    int ret;

    ret = proc_pidpath(pid, buffer, PROC_PIDPATHINFO_MAXSIZE);
    if ( ret <= 0 )
    {
        fprintf(stderr, "PID %d: proc_pidpath ();\n", pid);
        fprintf(stderr, "    %s\n", strerror(errno));
        return 0;
    }
//    else
//    {
//        printf("proc %d: %s\n", pid, buffer);
//    }

    return 1;
}
