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

#import "AppSelectionViewController.h"
#import "TargetSelectionViewController.h"

#import "AppInfoCell.h"

@interface AppSelectionViewController ()
@property NSArray *binaries;
@end

@implementation AppSelectionViewController
@synthesize dfuController = _dfuController;

- (void)viewDidLoad
{
    [super viewDidLoad];
	
    NSError *e;
    NSData *jsonData = [NSData dataWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"binary_list" withExtension:@"json"]];
    NSDictionary *d = [NSJSONSerialization JSONObjectWithData:jsonData options:kNilOptions error:&e];
    self.binaries = [d objectForKey:@"binaries"];

    self.binariesTableView.delegate = self;
    self.binariesTableView.dataSource = self;
}

- (void) viewWillAppear:(BOOL)animated
{
    [self.binariesTableView deselectRowAtIndexPath:self.binariesTableView.indexPathForSelectedRow animated:NO];
    
    self.dfuController = [[DFUController alloc] init];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"showTargetSelection"])
    {
        NSDictionary *binary = [self.binaries objectAtIndex:self.binariesTableView.indexPathForSelectedRow.row];
        
        NSURL *firmwareURL = [[NSBundle mainBundle] URLForResource:[binary objectForKey:@"filename"] withExtension:[binary objectForKey:@"extension"]];
        [self.dfuController setFirmwareURL:firmwareURL];
        
        TargetSelectionViewController *vc = (TargetSelectionViewController *) segue.destinationViewController;
        [vc setDfuController:self.dfuController];
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.binaries.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    AppInfoCell *cell = [tableView dequeueReusableCellWithIdentifier:@"AppInfoCell"];
    
    NSDictionary *binary = [self.binaries objectAtIndex:indexPath.row];
    cell.nameLabel.text = [binary objectForKey:@"title"];
    cell.sizeLabel.text = [NSString stringWithFormat:@"%@ bytes", [binary objectForKey:@"size"]];
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 90.0;
}
@end
