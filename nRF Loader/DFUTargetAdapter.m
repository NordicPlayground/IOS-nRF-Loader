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

#import "DFUTargetAdapter.h"

typedef struct __attribute__((packed))
{
    uint8_t opcode;
    union
    {
        uint16_t n_packets;
        struct __attribute__((packed))
        {
            uint8_t   original;
            uint8_t   response;
        };
        uint32_t n_bytes;
    };
} dfu_control_point_data_t;

@interface DFUTargetAdapter ()
@property CBCharacteristic *controlPointCharacteristic;
@property CBCharacteristic *packetCharacteristic;

@property id<DFUTargetAdapterDelegate> delegate;
@end

@implementation DFUTargetAdapter
@synthesize peripheral = _peripheral;
@synthesize controlPointCharacteristic = _controlPointCharacteristic;
@synthesize packetCharacteristic = _packetCharacteristic;

+ (CBUUID *) serviceUUID
{
    return [CBUUID UUIDWithString:@"00001530-1212-EFDE-1523-785FEABCD123"];
}

+ (CBUUID *) controlPointCharacteristicUUID
{
    return [CBUUID UUIDWithString:@"00001531-1212-EFDE-1523-785FEABCD123"];
}

+ (CBUUID *) packetCharacteristicUUID
{
    return [CBUUID UUIDWithString:@"00001532-1212-EFDE-1523-785FEABCD123"];
}

- (DFUTargetAdapter *) initWithDelegate:(id<DFUTargetAdapterDelegate>)delegate
{
    if (self = [super init])
    {
        _delegate = delegate;
    }
    return self;
}

- (void) setPeripheral:(CBPeripheral *)peripheral
{
    _peripheral = peripheral;
    _peripheral.delegate = self;
}

- (void) startDiscovery
{
    [self.peripheral discoverServices:@[[self.class serviceUUID]]];
}

- (void) sendNotificationRequest:(int) interval
{
    NSLog(@"sendNotificationRequest");
    dfu_control_point_data_t data;
    data.opcode = REQUEST_RECEIPT;
    data.n_packets = interval;
    
    NSData *commandData = [NSData dataWithBytes:&data length:3];
    [self.peripheral writeValue:commandData forCharacteristic:self.controlPointCharacteristic type:CBCharacteristicWriteWithResponse];
}

- (void) sendStartCommand:(int) firmwareLength
{
    NSLog(@"sendStartCommand");
    dfu_control_point_data_t data;
    data.opcode = START_DFU;
    
    NSData *commandData = [NSData dataWithBytes:&data length:1];
    [self.peripheral writeValue:commandData forCharacteristic:self.controlPointCharacteristic type:CBCharacteristicWriteWithResponse];
    
    NSData *sizeData = [NSData dataWithBytes:&firmwareLength length:sizeof(firmwareLength)];
    [self.peripheral writeValue:sizeData forCharacteristic:self.packetCharacteristic type:CBCharacteristicWriteWithoutResponse];
}

- (void) sendReceiveCommand
{
    NSLog(@"sendReceiveCommand");
    dfu_control_point_data_t data;
    data.opcode = RECEIVE_FIRMWARE_IMAGE;
    
    NSData *commandData = [NSData dataWithBytes:&data length:1];
    [self.peripheral writeValue:commandData forCharacteristic:self.controlPointCharacteristic type:CBCharacteristicWriteWithResponse];
}

- (void) sendFirmwareData:(NSData *) data
{
    [self.peripheral writeValue:data forCharacteristic:self.packetCharacteristic type:CBCharacteristicWriteWithoutResponse];
}

- (void) sendValidateCommand
{
    NSLog(@"sendValidateCommand");
    dfu_control_point_data_t data;
    data.opcode = VALIDATE_FIRMWARE;
    
    NSData *commandData = [NSData dataWithBytes:&data length:1];
    [self.peripheral writeValue:commandData forCharacteristic:self.controlPointCharacteristic type:CBCharacteristicWriteWithResponse];
}

- (void) sendResetAndActivate:(BOOL)activate
{
    if (!self.controlPointCharacteristic)
    {
        return;
    }
    
    NSLog(@"sendResetAndActivate %d", activate);
    dfu_control_point_data_t data;
    
    if (activate)
    {
        data.opcode = ACTIVATE_RESET;
    }
    else
    {
        data.opcode = RESET;
    }
    
    NSData *commandData = [NSData dataWithBytes:&data length:1];
    [self.peripheral writeValue:commandData forCharacteristic:self.controlPointCharacteristic type:CBCharacteristicWriteWithResponse];
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if (error)
    {
        NSLog(@"didDiscoverServices failed: %@", error);
        return;
    }
    
    NSLog(@"didDiscoverServices succeeded.");
    
    for (CBService *s in peripheral.services)
    {
        if ([s.UUID isEqual:[self.class serviceUUID]])
        {
            NSLog(@"Discover characteristics...");
            [self.peripheral discoverCharacteristics:@[[self.class controlPointCharacteristicUUID], [self.class packetCharacteristicUUID]] forService:s];
        }
    }
}

- (void) peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    if (error)
    {
        NSLog(@"didDiscoverCharacteristics failed: %@", error);
        return;
    }
    
    NSLog(@"didDiscoverCharacteristics succeeded.");
    
    for (CBCharacteristic *c in service.characteristics)
    {
        if ([c.UUID isEqual:[self.class controlPointCharacteristicUUID]])
        {
            NSLog(@"Found control point characteristic.");
            self.controlPointCharacteristic = c;
            
            [self.peripheral setNotifyValue:YES forCharacteristic:self.controlPointCharacteristic];
        }
        else if ([c.UUID isEqual:[self.class packetCharacteristicUUID]])
        {
            NSLog(@"Found packet characteristic.");
            self.packetCharacteristic = c;
        }
    }
    
    if (self.packetCharacteristic && self.controlPointCharacteristic)
    {
        [self.delegate didFinishDiscovery];
    }
}

- (void) peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{

    NSLog(@"Did update value for characteristic %@. Value: %@.", characteristic, characteristic.value);
    if ([characteristic.UUID isEqual:[self.class controlPointCharacteristicUUID]])
    {
        dfu_control_point_data_t *packet = (dfu_control_point_data_t *) characteristic.value.bytes;
        if (packet->opcode == RESPONSE_CODE)
        {
            [self.delegate didReceiveResponse:packet->response forCommand:packet->original];
        }
        if (packet->opcode == RECEIPT)
        {
            [self.delegate didReceiveReceipt];
        }
    }
}

- (void) peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (characteristic == self.controlPointCharacteristic)
    {
        [self.delegate didWriteControlPoint];
    }
}
@end
