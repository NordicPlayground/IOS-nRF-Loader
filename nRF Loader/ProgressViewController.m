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

#import "ProgressViewController.h"

#import "AppInfoCell.h"
#import "DeviceInformationCell.h"

@interface ProgressViewController ()
@property (weak, nonatomic) IBOutlet UILabel *appNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *appSizeLabel;
@property (weak, nonatomic) IBOutlet UILabel *targetNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *targetStatusLabel;
@property (weak, nonatomic) IBOutlet UILabel *progressLabel;
@property (weak, nonatomic) IBOutlet UIButton *uploadButton;

@property BOOL isTransferring;
@end

@implementation ProgressViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void) viewWillAppear:(BOOL)animated
{
    self.dfuController.delegate = self;
    
    self.appNameLabel.text = self.dfuController.appName;
    self.appSizeLabel.text = [NSString stringWithFormat:@"%d bytes", self.dfuController.appSize];
    
    self.targetNameLabel.text = self.dfuController.targetName;
    self.targetStatusLabel.text = @"-";
    
    self.uploadButton.enabled = NO;
}

- (void) viewWillDisappear:(BOOL)animated
{
    [self.dfuController cancelTransfer];
    self.isTransferring = NO;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)uploadButtonPressed:(id)sender
{
    if (!self.isTransferring)
    {
        self.isTransferring = YES;
        [self.dfuController startTransfer];
        [self.uploadButton setTitle:@"Cancel" forState:UIControlStateNormal];
    }
    else
    {
        self.isTransferring = NO;
        [self.dfuController cancelTransfer];
        [self.uploadButton setTitle:@"Upload" forState:UIControlStateNormal];
    }
}

- (void) didUpdateProgress:(float) progress
{
    self.progressLabel.text = [NSString stringWithFormat:@"%.0f %%", progress*100];
    [self.progressView setProgress:progress animated:YES];
}

- (void) didFinishTransfer
{
    NSString *message = [NSString stringWithFormat:@"The upload completed successfully, %@ has been reset and now runs %@.", self.dfuController.targetName, self.dfuController.appName];
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Finished upload!" message:message delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
    [alert show];

    [self.navigationController popToRootViewControllerAnimated:YES];
}

- (void) didCancelTransfer
{
    NSString *message = [NSString stringWithFormat:@"The upload was cancelled. %@ has been reset, and runs its original application.", self.dfuController.targetName];
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Canceled upload" message:message delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
    [alert show];
    
    [self.navigationController popViewControllerAnimated:YES];
}

- (void) didDisconnect:(NSError *)error
{
    NSString *message = [NSString stringWithFormat:@"The connection was lost, with error description: %@", error.description];
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Connection lost" message:message delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
    [alert show];
    
    [self.navigationController popViewControllerAnimated:YES];
}

- (void) didChangeState:(DFUControllerState)state
{
    if (state == IDLE)
    {
        self.uploadButton.enabled = YES;
    }
    self.targetStatusLabel.text = [self.dfuController stringFromState:state];
}
@end
