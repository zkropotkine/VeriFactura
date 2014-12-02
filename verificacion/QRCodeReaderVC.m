//
//  QRCodeReaderVC.m
//  verificacion
//
//  Created by Daniel Rodriguez on 11/27/14.
//  Copyright (c) 2014 Daniel Rodriguez. All rights reserved.
//

#import "QRCodeReaderVC.h"
#define CFDI_ELEMENTS_NUMBERS 4

@interface QRCodeReaderVC ()
@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *videoPreviewLayer;
@property (nonatomic, strong) AVAudioPlayer *audioPlayer;
@property (nonatomic) BOOL isReading;

-(BOOL)startReading;
-(void)stopReading;
-(void)loadBeepSound;
@end

@implementation QRCodeReaderVC
   NSString *sSOAPMessage = @"<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
                            "<SOAP-ENV:Envelope xmlns:SOAP-ENV=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:ns1=\"http://tempuri.org/\">"
                              "<SOAP-ENV:Body>"
                                "<ns1:Consulta>"
                                  "<ns1:expresionImpresa>"
                                    "<![CDATA[%RE&%RR&%TT&%ID]]>"
                                  "</ns1:expresionImpresa>"
                                "</ns1:Consulta>"
                              "</SOAP-ENV:Body>"
                            "</SOAP-ENV:Envelope>";

  NSMutableArray *cfdiData;
  bool validCDFI = true;
  NSMutableString *resultValue;

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    cfdiData = [[NSMutableArray alloc] initWithCapacity:CFDI_ELEMENTS_NUMBERS];
    
    // Initially make the captureSession object nil.
    _captureSession = nil;
    
    // Set the initial value of the flag to NO.
    _isReading = NO;
    
    // Begin loading the sound effect so to have it ready for playback when it's needed.
    [self loadBeepSound];
    
    [self startStopReading:nil];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - IBAction method implementation

- (IBAction)startStopReading:(id)sender {
    if (!_isReading) {
        // This is the case where the app should read a QR code when the start button is tapped.
        if ([self startReading]) {
            // If the startReading methods returns YES and the capture session is successfully
            // running, then change the start button title and the status message.
            [_bbitemStart setTitle:@"Parar"];
            [self.lblStatus setText:@"Escaneando CFDI"];
             self.lblStatus.textColor = [UIColor blueColor];
        }
    }
    else{
        // In this case the app is currently reading a QR code and it should stop doing so.
        [self stopReading];
        // The bar button item's title should change again.
        [_bbitemStart setTitle:@"Verificar!"];
    }
    
    // Set to the flag the exact opposite value of the one that currently has.
    _isReading = !_isReading;
}


#pragma mark - Private method implementation

- (BOOL)startReading {
    NSError *error;
    
    // Get an instance of the AVCaptureDevice class to initialize a device object and provide the video
    // as the media type parameter.
    AVCaptureDevice *captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    // Get an instance of the AVCaptureDeviceInput class using the previous device object.
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice error:&error];
    
    if (!input) {
        // If any error occurs, simply log the description of it and don't continue any more.
        NSLog(@"%@", [error localizedDescription]);
        return NO;
    }
    
    // Initialize the captureSession object.
    _captureSession = [[AVCaptureSession alloc] init];
    // Set the input device on the capture session.
    [_captureSession addInput:input];
    
    
    // Initialize a AVCaptureMetadataOutput object and set it as the output device to the capture session.
    AVCaptureMetadataOutput *captureMetadataOutput = [[AVCaptureMetadataOutput alloc] init];
    [_captureSession addOutput:captureMetadataOutput];
    
    // Create a new serial dispatch queue.
    dispatch_queue_t dispatchQueue;
    dispatchQueue = dispatch_queue_create("myQueue", NULL);
    [captureMetadataOutput setMetadataObjectsDelegate:self queue:dispatchQueue];
    [captureMetadataOutput setMetadataObjectTypes:[NSArray arrayWithObject:AVMetadataObjectTypeQRCode]];
    
    // Initialize the video preview layer and add it as a sublayer to the viewPreview view's layer.
    _videoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_captureSession];
    [_videoPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    [_videoPreviewLayer setFrame:_viewPreview.layer.bounds];
    [_viewPreview.layer addSublayer:_videoPreviewLayer];
    
    
    // Start video capture.
    [_captureSession startRunning];
    
    return YES;
}


-(void)stopReading{
    // Stop video capture and make the capture session object nil.
    [_captureSession stopRunning];
    _captureSession = nil;
    
    // Remove the video preview layer from the viewPreview view's layer.
    [_videoPreviewLayer removeFromSuperlayer];
    
    
    if (validCDFI)
    {
        NSURL *sRequestURL = [NSURL URLWithString:@"https://consultaqr.facturaelectronica.sat.gob.mx/ConsultaCFDIService.svc?singleWsdl"];
        NSMutableURLRequest *myRequest = [NSMutableURLRequest requestWithURL:sRequestURL];
        
        sSOAPMessage = [sSOAPMessage stringByReplacingOccurrencesOfString:@"%RE" withString:[cfdiData objectAtIndex:0]];
        sSOAPMessage = [sSOAPMessage stringByReplacingOccurrencesOfString:@"%RR" withString:[cfdiData objectAtIndex:1]];
        sSOAPMessage = [sSOAPMessage stringByReplacingOccurrencesOfString:@"%TT" withString:[cfdiData objectAtIndex:2]];
        sSOAPMessage = [sSOAPMessage stringByReplacingOccurrencesOfString:@"%ID" withString:[cfdiData objectAtIndex:3]];
        
        
        NSLog(@"String: %@", sSOAPMessage);
        
        NSString *sMessageLength = [NSString stringWithFormat:@"%d", [sSOAPMessage length]];
        
        [myRequest addValue: @"text/xml; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
        [myRequest addValue: @"http://tempuri.org/IConsultaCFDIService/Consulta" forHTTPHeaderField:@"SOAPAction"];
        [myRequest addValue: sMessageLength forHTTPHeaderField:@"Content-Length"];
        [myRequest setHTTPMethod:@"POST"];
        [myRequest setHTTPBody: [sSOAPMessage dataUsingEncoding:NSUTF8StringEncoding]];
        
        NSURLConnection *theConnection = [[NSURLConnection alloc] initWithRequest:myRequest delegate:self];
        
        if( theConnection ) {
            self.webResponseData = [NSMutableData data];

            
            //[_lblStatus setText:@"Factura Valida"];
        }else {
            NSLog(@"Some error occurred in Connection");
            [self.lblStatus setText:@"Tenemos problemas validando esta factura, por favor intenta más tarde."];
            self.lblStatus.textColor = [UIColor redColor];
        }
    } else {
        NSLog(@"Some error occurred in Connection");
        [self.lblStatus setText:@"Esto no parece ser una factura."];
        self.lblStatus.textColor = [UIColor redColor];
    }
}


-(void)loadBeepSound{
    // Get the path to the beep.mp3 file and convert it to a NSURL object.
    NSString *beepFilePath = [[NSBundle mainBundle] pathForResource:@"beep" ofType:@"mp3"];
    NSURL *beepURL = [NSURL URLWithString:beepFilePath];
    
    NSError *error;
    
    // Initialize the audio player object using the NSURL object previously set.
    _audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:beepURL error:&error];
    if (error) {
        // If the audio player cannot be initialized then log a message.
        NSLog(@"Could not play beep file.");
        NSLog(@"%@", [error localizedDescription]);
    }
    else{
        // If the audio player was successfully initialized then load it in memory.
        [_audioPlayer prepareToPlay];
    }
}


#pragma mark - AVCaptureMetadataOutputObjectsDelegate method implementation

-(void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection {
    
    // Check if the metadataObjects array is not nil and it contains at least one object.
    if (metadataObjects != nil && [metadataObjects count] > 0) {
        // Get the metadata object.
        AVMetadataMachineReadableCodeObject *metadataObj = [metadataObjects objectAtIndex:0];
        if ([[metadataObj type] isEqualToString:AVMetadataObjectTypeQRCode]) {
            // If the found metadata is equal to the QR code metadata then update the status label's text,
            // stop reading and change the bar button item's title and the flag's value.
            // Everything is done on the main thread.
            //[_lblStatus performSelectorOnMainThread:@selector(setText:) withObject:[metadataObj stringValue] waitUntilDone:NO];
            
            NSString *myString = [metadataObj stringValue];
            
            NSArray *myWords = [myString componentsSeparatedByCharactersInSet:
                                [NSCharacterSet characterSetWithCharactersInString:@"&"]
                                ];
            
           // NSLog(@"The content of array is: %@", myString);
            //NSLog(@"The content of array is%@", myWords);
            
            NSArray *cfdiElements = [NSArray arrayWithObjects:@"?re=",@"rr=",@"tt=", @"id=",nil];
            
            int i = 0;
            validCDFI = true;
            for (id cfdiElement in cfdiElements)
            {
                id myWord = [myWords objectAtIndex:i];
                
                if ([myWord hasPrefix:cfdiElement]) {
                    validCDFI = validCDFI & true;
                    
                    [cfdiData addObject:myWord];
                } else {
                    validCDFI = validCDFI & false;
                    break;
                }
                
                i++;
            }
            
            [self performSelectorOnMainThread:@selector(stopReading) withObject:nil waitUntilDone:NO];
            [_bbitemStart performSelectorOnMainThread:@selector(setTitle:) withObject:@"Verificar!" waitUntilDone:NO];
            
            _isReading = NO;
            
            // If the audio player is not nil, then play the sound effect.
            if (_audioPlayer) {
                [_audioPlayer play];
            }
        }
    }
}

-(void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    [self.webResponseData  setLength:0];
}

-(void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self.webResponseData  appendData:data];
}

-(void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    NSLog(@"Some error in your Connection. Please try again.");
}

-(void)connectionDidFinishLoading:(NSURLConnection *)connection {
    NSLog(@"Received Bytes from server: %d", [self.webResponseData length]);
    NSString *myXMLResponse = [[NSString alloc] initWithBytes: [self.webResponseData bytes] length:[self.webResponseData length] encoding:NSUTF8StringEncoding];
    NSLog(@"%@",myXMLResponse);
    
    NSData *data = [myXMLResponse dataUsingEncoding:NSUTF8StringEncoding];
    
    NSXMLParser *xmlstr = [[NSXMLParser alloc] initWithData:data] ;
    xmlstr.delegate = self;
    [xmlstr parse];
}

/*
- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI  qualifiedName:(NSString *)qualifiedName attributes:(NSDictionary *)attributeDict {
    //NSLog(@"ENCONTRO E, %@",elementName );
    //NSLog(@"ENCONTRO X, %@",attributeDict );
}*/

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
    //if(resultValue == nil)
        
        resultValue = [[NSMutableString
                    alloc] init];
    
    [resultValue appendString:string];
     //NSLog(@"ENCONTRO I, %@", string);
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
    
    
    NSLog(@"Found an element named: %@ with a value of: %@", elementName, resultValue);
     //NSLog(@"ENCONTRO <E, %@",elementName);
    
    if ([elementName isEqualToString:@"a:CodigoEstatus"]){
        //[resultValue appendString:[NSString stringWithFormat:@"%@ La factura es: ", resultValue]];
    } else if ([elementName isEqualToString:@"a:Estado"]){
        //[resultValue appendString:[NSString stringWithFormat:@"%@ La factura es: ", resultValue]];
        // [_lblStatus setText:[NSString stringWithFormat:@"La factura es: %@ ", resultValue]];
        
        [self.lblStatus setText:[NSString stringWithFormat:@"La factura es: %@ ", resultValue]];
        self.lblStatus.textColor = [UIColor greenColor];
    }
    
}


@end
