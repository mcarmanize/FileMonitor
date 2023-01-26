//
//  main.m
//  FileMonitor
//
//  Created by Patrick Wardle on 10/17/19.
//  Copyright © 2020 Patrick Wardle. All rights reserved.
//

#import "main.h"
#import "FileMonitor.h"
#import "FileMonitor-Swift.h"

int main(int argc, const char * argv[]) {
    
    //return var
    int status = -1;
    
    @autoreleasepool {
        
        //args
        NSArray* arguments = nil;
        
        //grab args
        arguments = [[NSProcessInfo processInfo] arguments];
        
        //run via user (app)?
        // display error popup
        if(1 == getppid())
        {
            //launch app normally
            status = NSApplicationMain(argc, argv);
            
            //bail
            goto bail;
        }
        
        //handle '-h' or '-help'
        if( (YES == [arguments containsObject:@"-h"]) ||
            (YES == [arguments containsObject:@"-help"]) )
        {
            //print usage
            usage();
            
            //done
            goto bail;
        }
        
        //process (other) args
        if(YES != processArgs(arguments))
        {
            //print usage
            usage();
            
            //done
            goto bail;
        }
        
        //go!
        if(YES != monitor())
        {
            //bail
            goto bail;
        }
    
        //run loop
        // as don't want to exit
        [[NSRunLoop currentRunLoop] run];
        
    } //pool
    
bail:
        
    return status;
}

//print usage
void usage()
{
    //name
    NSString* name = nil;
    
    //version
    NSString* version = nil;
    
    //extract name
    name = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"];
    
    //extract version
    version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];

    //usage
    printf("\n%s (v%s) usage:\n", name.UTF8String, version.UTF8String);
    printf(" -h or -help      display this usage info\n");
    printf(" -pretty          JSON output is 'pretty-printed'\n");
    printf(" -skipApple       ignore Apple (platform) processes \n");
    printf(" -filter <name>   show events matching file or process name\n\n");
    //usage added for database connections
    printf(" -noPrint         this mode disables terminal output and instead requires\n");
    printf("                  a connection string (-mongo) and job identifier (-jobid)\n");
    printf("                  a connection string (-mongo) and job identifier (-jobid)\n");
    printf(" -mongo <connection string>\n");
    printf("    mongo database connection string \"mongodb://192.168.1.2:27017\"\n\n");
    printf(" -jobid <job identifier>\n");
    printf("    this will be used to create a collection name within the run_logs database\n\n");
    
    return;
}

//process user-specifed args
BOOL processArgs(NSArray* arguments)
{
    //flag
    BOOL validArgs = YES;
    
    //index
    NSUInteger index = 0;
    
    //init 'skipApple' flag
    skipApple = [arguments containsObject:@"-skipApple"];
    
    //init 'prettyPrint' flag
    prettyPrint = [arguments containsObject:@"-pretty"];
    
    //init 'noPrint' flag, if YES then we will use mongo database connection
    noPrint = [arguments containsObject:@"-noPrint"];
    
    //extract value for 'filterBy'
    index = [arguments indexOfObject:@"-filter"];
    if(NSNotFound != index)
    {
        //inc
        index++;
        
        //sanity check
        // make sure name comes after
        if(index >= arguments.count)
        {
            //invalid
            validArgs = NO;
            
            //bail
            goto bail;
        }
        
        //grab filter name
        filterBy = [arguments objectAtIndex:index];
    }
    
    //extract value for 'mongo'
    index = [arguments indexOfObject:@"-mongo"];
    if(NSNotFound != index)
    {
        //inc
        index++;
        
        //sanity check
        // make sure name comes after
        if(index >= arguments.count)
        {
            //invalid
            validArgs = NO;
            
            //bail
            goto bail;
        }
        
        //grab filter name
        connectionString = [arguments objectAtIndex:index];
    }
    
    //extract value for 'jobid'
    index = [arguments indexOfObject:@"-jobid"];
    if(NSNotFound != index)
    {
        //inc
        index++;
        
        //sanity check
        // make sure name comes after
        if(index >= arguments.count)
        {
            //invalid
            validArgs = NO;
            
            //bail
            goto bail;
        }
        
        //grab filter name
        jobIdentifier = [arguments objectAtIndex:index];
    }

bail:
    
    return validArgs;
}

//monitor
BOOL monitor()
{
    //events of interest
    // note: also pass in process exec/exit to capture args
    es_event_type_t events[] = {ES_EVENT_TYPE_NOTIFY_CREATE, ES_EVENT_TYPE_NOTIFY_OPEN, ES_EVENT_TYPE_NOTIFY_WRITE, ES_EVENT_TYPE_NOTIFY_CLOSE, ES_EVENT_TYPE_NOTIFY_RENAME, ES_EVENT_TYPE_NOTIFY_LINK, ES_EVENT_TYPE_NOTIFY_UNLINK, ES_EVENT_TYPE_NOTIFY_EXEC, ES_EVENT_TYPE_NOTIFY_EXIT};

    //init database
    MongoConnection* mongo = [[MongoConnection alloc] initWithInitWithConnectionString:connectionString jobIdentifier:jobIdentifier];
    
    //init monitor
    FileMonitor* fileMon = [[FileMonitor alloc] init];
    
    //define block
    // automatically invoked upon file events
    FileCallbackBlock block = ^(File* file)
    {
        //do thingz
        // e.g. file.event has event (create, delete, etc.)
        // for now, we just print out the event and file & process object
        
        //ingore apple?
        if( (YES == skipApple) &&
            (YES == file.process.isPlatformBinary.boolValue))
        {
            //ignore
            return;
        }
        
        //filter
        // and no match? skip
        if(0 != filterBy.length)
        {
            //check file paths & process
            if( (YES != [file.sourcePath hasSuffix:filterBy]) &&
                (YES != [file.destinationPath hasSuffix:filterBy]) &&
                (YES != [file.process.path hasSuffix:filterBy]) )
            {
                //ignore
                return;
            }
        }
            
        if(YES != noPrint)
        {
            //pretty print?
            if(YES == prettyPrint)
            {
                //make me pretty!
                printf("%s\n", prettifyJSON(file.description).UTF8String);
            }
            else
            {
                //output
                printf("%s\n", file.description.UTF8String);
            }
        } else {
            if (ES_EVENT_TYPE_NOTIFY_CLOSE == file.event && file.modified)
            {
                bson_value_t fileIdentifier = [mongo insertFileWithPath:[NSURL URLWithString:file.destinationPath]];
                [mongo insertEventWithFileIdentifier:fileIdentifier eventDescription:file.description];
            }
            else
            {
                [mongo insertEvent:file.description];
            }
        }
        
    };
        
    //start monitoring
    // pass in events, count, and callback block for events
    return [fileMon start:events count:sizeof(events)/sizeof(events[0]) csOption:csStatic callback:block];
}

//prettify JSON
NSString* prettifyJSON(NSString* output)
{
    //data
    NSData* data = nil;
    
    //error
    NSError* error = nil;
    
    //object
    id object = nil;
    
    //pretty data
    NSData* prettyData = nil;
    
    //pretty string
    NSString* prettyString = nil;
    
    //covert to data
    data = [output dataUsingEncoding:NSUTF8StringEncoding];
   
    //convert to JSON
    // wrap since we are serializing JSON
    @try
    {
        //serialize
        object = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if(nil == object)
        {
            //bail
            goto bail;
        }
        
        //covert to pretty data
        prettyData = [NSJSONSerialization dataWithJSONObject:object options:NSJSONWritingPrettyPrinted error:&error];
        if(nil == prettyData)
        {
            //bail
            goto bail;
        }
    }
    //ignore exceptions (here)
    @catch(NSException *exception)
    {
        //bail
        goto bail;
    }
    
    //convert to string
    // note, we manually unescape forward slashes
    prettyString = [[[NSString alloc] initWithData:prettyData encoding:NSUTF8StringEncoding] stringByReplacingOccurrencesOfString:@"\\/" withString:@"/"];
   
bail:
    
    //error?
    if(nil == prettyString)
    {
        //init error
        prettyString = @"{\"error\" : \"failed to convert output to JSON\"}";
    }
    
    return prettyString;
}
