#import <Foundation/Foundation.h>

//
//  CBBlueLightClient.h
//  NightShifter
//
//  Created by Eric Lanini on 6/11/17.
//  Copyright © 2017 Eric Lanini. All rights reserved.
//

#ifndef CBBlueLightClient_h
#define CBBlueLightClient_h

typedef struct {
    int hour;
    int minute;
} Time;

typedef struct {
    Time fromTime;
    Time toTime;
} Schedule;


typedef struct {
    float minCCT;
    float maxCCT;
    float midCCT;
} CCTRange;


typedef struct {
    char active;
    char enabled;
    char sunSchedulePermitted;
    int mode;
    Schedule schedule;
    unsigned long long disableFlags;
} StatusData;

@interface CBBlueLightClient : NSObject

+ (BOOL)supportsBlueLightReduction;

- (BOOL)setEnabled:(BOOL)arg1;
- (BOOL)setStrength:(float)arg1 withPeriod: (float) arg2 commit: (BOOL) arg3;
- (BOOL)setStrength:(float)arg1 commit: (BOOL)arg2;
- (BOOL)setMode:(int)arg1;
- (BOOL)getStrength:(float *)arg1;
- (BOOL)getCCT:(float *)arg1;
- (BOOL)getCCTRange:(CCTRange *) arg1;
- (BOOL)getBlueLightStatus:(StatusData *)arg1;
@end


#endif /* CBBlueLightClient_h */
