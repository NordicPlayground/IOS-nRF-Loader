/*
 * Copyright (c) 2015, Nordic Semiconductor
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the
 * documentation and/or other materials provided with the distribution.
 *
 * 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this
 * software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
 * ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
 * USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <Foundation/Foundation.h>
#import "DFUTargetAdapter.h"

typedef enum
{
    INIT,
    DISCOVERING,
    IDLE,
    SEND_NOTIFICATION_REQUEST,
    SEND_START_COMMAND,
    SEND_RECEIVE_COMMAND,
    SEND_FIRMWARE_DATA,
    SEND_VALIDATE_COMMAND,
    SEND_RESET,
    WAIT_RECEIPT,
    FINISHED,
    CANCELED,
} DFUControllerState;


@protocol DFUControllerDelegate <NSObject>
- (void) didChangeState:(DFUControllerState) state;
- (void) didUpdateProgress:(float) progress;
- (void) didFinishTransfer;
- (void) didCancelTransfer;
- (void) didDisconnect:(NSError *) error;
@end

@interface DFUController : NSObject <DFUTargetAdapterDelegate>
@property id<DFUControllerDelegate> delegate;

@property NSString *appName;
@property int appSize;

@property NSString *targetName;

+ (CBUUID *) serviceUUID;

- (DFUController *) initWithDelegate:(id<DFUControllerDelegate>) delegate;
- (NSString *) stringFromState:(DFUControllerState) state;

- (void) setPeripheral:(CBPeripheral *)peripheral;
- (void) setFirmwareURL:(NSURL *) URL;

- (void) didConnect;
- (void) didDisconnect:(NSError *) error;

- (void) startTransfer;
- (void) pauseTransfer;
- (void) cancelTransfer;
@end
