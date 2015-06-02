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

#import "DFUController.h"

#define DFUCONTROLLER_MAX_PACKET_SIZE 20
#define DFUCONTROLLER_DESIRED_NOTIFICATION_STEPS 20

@interface DFUController ( )
@property (nonatomic) DFUControllerState state;
@property DFUTargetAdapter *target;

@property NSData *firmwareData;
@property int firmwareDataBytesSent;
@property int notificationPacketInterval;

@property (nonatomic) float progress;

@end

@implementation DFUController
@synthesize state = _state;
@synthesize delegate = _delegate;

+ (CBUUID *) serviceUUID
{
    return [[DFUTargetAdapter class] serviceUUID];
}

- (DFUController *) initWithDelegate:(id<DFUControllerDelegate>) delegate
{
    if (self = [super init])
    {
        _state = INIT;
        _delegate = delegate;
        
        _firmwareDataBytesSent = 0;
        
        _appName = @"-";
        _appSize = 0;
        
        _targetName = @"-";
        
        _progress = 0;

    }
    return self;
}

- (void) setPeripheral:(CBPeripheral *)peripheral
{
    self.targetName = peripheral.name;

    self.target = [[DFUTargetAdapter alloc] initWithDelegate:self];
    self.target.peripheral = peripheral;
}

- (void) setState:(DFUControllerState)newState
{
    @synchronized(self)
    {
        DFUControllerState oldState = _state;
        _state = newState;
        NSLog(@"State changed from %d to %d.", oldState, newState);
        
        if (newState == INIT)
        {
            self.progress = 0;
            self.firmwareDataBytesSent = 0;
        }
        
        [self.delegate didChangeState:newState];
    }
}

- (DFUControllerState) state
{
    return _state;
}

- (NSString *) stringFromState:(DFUControllerState) state
{
    switch (state)
    {
        case INIT:
            return @"Init";
        
        case DISCOVERING:
            return @"Discovering";
            
        case IDLE:
            return @"Ready";
            
        case SEND_NOTIFICATION_REQUEST:
        case SEND_START_COMMAND:
        case SEND_RECEIVE_COMMAND:
        case SEND_FIRMWARE_DATA:
        case WAIT_RECEIPT:
            return @"Uploading";
            
        case SEND_VALIDATE_COMMAND:
        case SEND_RESET:
            return @"Finishing";
            
        case FINISHED:
            return @"Finished";
            
        case CANCELED:
            return @"Canceled";
    }
    return nil;
}

- (void) setFirmwareURL:(NSURL *)firmwareURL
{
    self.firmwareData = [NSData dataWithContentsOfURL:firmwareURL];
    self.notificationPacketInterval = self.firmwareData.length / (DFUCONTROLLER_MAX_PACKET_SIZE * DFUCONTROLLER_DESIRED_NOTIFICATION_STEPS);
    
    self.appName = firmwareURL.path.lastPathComponent;
    self.appSize = self.firmwareData.length;
    
    NSLog(@"Set firmware with size %lu, notificationPacketInterval: %d", (unsigned long)self.firmwareData.length, self.notificationPacketInterval);
}

- (void) setProgress:(float)progress
{
    _progress = progress;
    [self.delegate didUpdateProgress:progress];
}

- (void) sendFirmwareChunk
{
    NSLog(@"sendFirmwareData");
    int currentDataSent = 0;
    
    for (int i = 0; i < self.notificationPacketInterval && self.firmwareDataBytesSent < self.firmwareData.length; i++)
    {
        unsigned long length = (self.firmwareData.length - self.firmwareDataBytesSent) > DFUCONTROLLER_MAX_PACKET_SIZE ? DFUCONTROLLER_MAX_PACKET_SIZE : self.firmwareData.length - self.firmwareDataBytesSent;
        
        NSRange currentRange = NSMakeRange(self.firmwareDataBytesSent, length);
        NSData *currentData = [self.firmwareData subdataWithRange:currentRange];
        
        [self.target sendFirmwareData:currentData];
        
        self.firmwareDataBytesSent += length;
        currentDataSent += length;
    }
    
    [self didWriteDataPacket];
    
    NSLog(@"Sent %d bytes, total %d.", currentDataSent, self.firmwareDataBytesSent);
}

- (void) didConnect
{
    NSLog(@"didConnect");
    if (self.state == INIT)
    {
        self.state = DISCOVERING;
        [self.target startDiscovery];
    }
}

- (void) didDisconnect:(NSError *) error
{
    NSLog(@"didDisconnect");
    
    if (self.state != FINISHED && self.state != CANCELED)
    {
        [self.delegate didDisconnect:error];
    }
    self.state = INIT;
}

- (void) didFinishDiscovery
{
    NSLog(@"didFinishDiscovery");
    if (self.state == DISCOVERING)
    {
        self.state = IDLE;
    }
}

- (void) didReceiveResponse:(DFUTargetResponse) response forCommand:(DFUTargetOpcode) opcode
{
    NSLog(@"didReceiveResponse, %d, in state %d", response, self.state);
    switch (self.state)
    {
        case SEND_START_COMMAND:
            if (response == SUCCESS)
            {
                self.state = SEND_RECEIVE_COMMAND;
                [self.target sendReceiveCommand];
            }
            break;
            
        case SEND_VALIDATE_COMMAND:
            if (response == SUCCESS)
            {
                self.state = SEND_RESET;
                [self.target sendResetAndActivate:YES];
            }
            break;
            
        case WAIT_RECEIPT:
            if (response == SUCCESS && opcode == RECEIVE_FIRMWARE_IMAGE)
            {
                self.progress = 1.0;
                
                self.state = SEND_VALIDATE_COMMAND;
                [self.target sendValidateCommand];
            }
            break;
        
        default:
            break;
    }
}

- (void) didReceiveReceipt
{
    NSLog(@"didReceiveReceipt");
    
    if (self.state == WAIT_RECEIPT)
    {
        self.progress = self.firmwareDataBytesSent / ((float) self.firmwareData.length);
        
        self.state = SEND_FIRMWARE_DATA;
        [self sendFirmwareChunk];
    }
}

- (void) didWriteControlPoint
{
    NSLog(@"didWriteControlPoint, state %d", self.state);
    
    switch (self.state)
    {
        case SEND_NOTIFICATION_REQUEST:
            self.state = SEND_START_COMMAND;
            [self.target sendStartCommand:(int) self.firmwareData.length];
            break;
        
        case SEND_RECEIVE_COMMAND:
            self.state = SEND_FIRMWARE_DATA;
            [self sendFirmwareChunk];
            break;

        case SEND_RESET:
            self.state = FINISHED;
            [self.delegate didFinishTransfer];
            break;
            
        case CANCELED:
            [self.delegate didCancelTransfer];
            break;
            
        default:
            break;
    }
}

- (void) didWriteDataPacket
{
    NSLog(@"didWriteDataPacket");
    
    if (self.state == SEND_FIRMWARE_DATA)
    {
        self.state = WAIT_RECEIPT;
    }
}

- (void) startTransfer
{
    NSLog(@"startTransfer");
    
    if (self.state == IDLE)
    {
        self.state = SEND_NOTIFICATION_REQUEST;
        [self.target sendNotificationRequest:self.notificationPacketInterval];
    }
}

- (void) pauseTransfer
{
    NSLog(@"pauseTransfer");
}

- (void) cancelTransfer
{
    NSLog(@"cancelTransfer");
    
    if (self.state != INIT && self.state != CANCELED && self.state != FINISHED)
    {
        self.state = CANCELED;
        [self.target sendResetAndActivate:NO];
    }
}

@end
