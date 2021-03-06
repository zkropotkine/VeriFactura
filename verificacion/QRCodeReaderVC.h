//
//  QRCodeReaderVC.h
//  verificacion
//
//  Created by Daniel Rodriguez on 11/27/14.
//  Copyright (c) 2014 Daniel Rodriguez. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface QRCodeReaderVC : UIViewController <AVCaptureMetadataOutputObjectsDelegate, NSXMLParserDelegate>

@property (weak, nonatomic) IBOutlet UIView *viewPreview;
@property (weak, nonatomic) IBOutlet UILabel *lblStatus;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *bbitemStart;
@property(nonatomic, strong)NSMutableData *webResponseData;

- (IBAction)startStopReading:(id)sender;

@end
