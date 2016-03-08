//
//  QRCodeReaderVC.m
//  verificacion
//
//  Created by Daniel Rodriguez on 11/27/14.
//  Copyright (c) 2014 Daniel Rodriguez. All rights reserved.
//

#import "QRCodeReaderVC.h"
#define CFDI_ELEMENTS_NUMBERS 1

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
   /*NSString *sSOAPMessage = @"<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
                            "<SOAP-ENV:Envelope xmlns:SOAP-ENV=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:ns1=\"http://tempuri.org/\">"
                              "<SOAP-ENV:Body>"
                                "<ns1:Consulta>"
                                  "<ns1:expresionImpresa>"
                                    "<![CDATA[%RE&%RR&%TT&%ID]]>"
                                  "</ns1:expresionImpresa>"
                                "</ns1:Consulta>"
                              "</SOAP-ENV:Body>"
                            "</SOAP-ENV:Envelope>";*/


NSString *sSOAPMessage = @"<?xml version=\"1.0\" encoding=\"UTF-8\"?><S:Envelope xmlns:S=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:SOAP-ENV=\"http://schemas.xmlsoap.org/soap/envelope/\"><SOAP-ENV:Header/><S:Body><ns2:checkTag xmlns:ns2=\"http://ws.autofagasta.com/\"><tagInfo>%RE</tagInfo></ns2:checkTag></S:Body></S:Envelope>";

NSString *serverIp = @"http://192.168.100.14:8080";

  NSMutableArray *cfdiData;
  bool validCDFI = true;
  bool userStoppedVerification = true;
  NSMutableString *resultValue;

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    cfdiData = [[NSMutableArray alloc] initWithCapacity:CFDI_ELEMENTS_NUMBERS];
    
    // Initially make the captureSession object nil.
    _captureSession = nil;
    
    // Set the initial value of the flag to NO.
    _isReading = NO;
    

    
    self.externalView.layer.cornerRadius = self.externalView.frame.size.width / 16;
    self.externalView.clipsToBounds = YES;
    
    
    
    self.externalView.layer.borderWidth = 3.0f;
    self.externalView.layer.borderColor = [UIColor colorWithRed:(51/255.0) green:(153/255.0) blue:(255/255.0) alpha:1].CGColor;
    
    
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
            [self.lblStatus setText:@"Escaneando Codigo"];
             self.lblStatus.textColor = [UIColor colorWithRed:(51/255.0) green:(153/255.0) blue:(255/255.0) alpha:1];
        }
    }
    else{
        // In this case the app is currently reading a QR code and it should stop doing so.
        [self stopReading];
        // The bar button item's title should change again.
        [_bbitemStart setTitle:@"Scanear!"];
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


-(void)stopReading
{
    // Stop video capture and make the capture session object nil.
    [_captureSession stopRunning];
    _captureSession = nil;
    
    // Remove the video preview layer from the viewPreview view's layer.
    [_videoPreviewLayer removeFromSuperlayer];
    
    
    if (![cfdiData count] == 0)
    {
        if (validCDFI)
        {
           // NSURL *sRequestURL = [NSURL URLWithString:@"https://consultaqr.facturaelectronica.sat.gob.mx/ConsultaCFDIService.svc?singleWsdl"];
            
            NSString *fullWSAddress = [serverIp stringByAppendingString:@"/ProjectXWeb/ProjectXWS?wsdl"];
            
            NSURL *sRequestURL = [NSURL URLWithString:fullWSAddress];
           // NSLog(@"String: %@", cfdiData);
            
            NSMutableURLRequest *myRequest = [NSMutableURLRequest requestWithURL:sRequestURL];
           // NSLog(@"r: %@", [cfdiData objectAtIndex:0]);
            sSOAPMessage = [sSOAPMessage stringByReplacingOccurrencesOfString:@"%RE" withString:[cfdiData objectAtIndex:0]];
            //sSOAPMessage = [sSOAPMessage stringByReplacingOccurrencesOfString:@"%RR" withString:[cfdiData objectAtIndex:1]];
            //sSOAPMessage = [sSOAPMessage stringByReplacingOccurrencesOfString:@"%TT" withString:[cfdiData objectAtIndex:2]];
            //sSOAPMessage = [sSOAPMessage stringByReplacingOccurrencesOfString:@"%ID" withString:[cfdiData objectAtIndex:3]];
            
            
            NSLog(@"String: %@", sSOAPMessage);
            
            NSString *sMessageLength = [NSString stringWithFormat:@"%d", [sSOAPMessage length]];
            NSString *soapAction = [serverIp stringByAppendingString:@"/ProjectXWeb/CheckTag/checkTagRequest"];
            
            [myRequest addValue: @"text/xml; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
           // [myRequest addValue: @"http://tempuri.org/IConsultaCFDIService/Consulta" forHTTPHeaderField:@"SOAPAction"];
            
            [myRequest addValue: soapAction forHTTPHeaderField:@"SOAPAction"];
            [myRequest addValue: sMessageLength forHTTPHeaderField:@"Content-Length"];
            [myRequest setHTTPMethod:@"POST"];
            [myRequest setHTTPBody: [sSOAPMessage dataUsingEncoding:NSUTF8StringEncoding]];
            
            
            
            NSURLConnection *theConnection = [[NSURLConnection alloc] initWithRequest:myRequest delegate:self];
            
           // NSLog(@"String: %@", myRequest);

            
            sSOAPMessage = [sSOAPMessage stringByReplacingOccurrencesOfString:[cfdiData objectAtIndex:0] withString: @"%RE"];
            NSLog(@"WOW: %@", sSOAPMessage);
            
            if (theConnection)
            {
                self.webResponseData = [NSMutableData data];
            }
            else
            {
                NSLog(@"Some error occurred in Connection");
                [self.lblStatus setText:@"Tenemos problemas validando esta factura, por favor intenta más tarde."];
                self.lblStatus.textColor = [UIColor redColor];
            }
        }
        else
        {
            NSLog(@"This doesn't seems to be a bill");
            [self.lblStatus setText:@"Esto no parece ser una factura."];
            self.lblStatus.textColor = [UIColor redColor];
        }
    }
    else
    {
        if (userStoppedVerification) {
            [self.lblStatus setText:@""];
            self.lblStatus.textColor = [UIColor blueColor];
        } else {
            [self.lblStatus setText:@"Esto no parece ser una factura."];
            self.lblStatus.textColor = [UIColor redColor];
        }
    }
    
    userStoppedVerification = true;
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
        userStoppedVerification = false;
        
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
            
            NSLog(@"The content of array is: %@", myString);
            NSLog(@"The content of array is%@", myWords);
            
            NSString* Identifier = [[[UIDevice currentDevice] identifierForVendor] UUIDString]; // IOS 6+
            NSLog(@"output is : %@", Identifier);
            
            //NSArray *cfdiElements = [NSArray arrayWithObjects:@"?re=",@"rr=",@"tt=", @"id=",nil];
            
            //int i = 0;
            validCDFI = true;
           /* for (id cfdiElement in cfdiElements)
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
            }*/
             cfdiData = [[NSMutableArray alloc] initWithCapacity:CFDI_ELEMENTS_NUMBERS];
            [cfdiData addObject:myString];
  NSLog(@"a is : %@", cfdiData);
            
            validCDFI = true;
            [_bbitemStart performSelectorOnMainThread:@selector(setTitle:) withObject:@"Verificar!" waitUntilDone:YES];
            //[_lblStatus performSelectorOnMainThread:@selector(setText:) withObject:@"Contactando al servidor, por favor espera." waitUntilDone:YES];
            [_lblStatus performSelectorOnMainThread:@selector(setText:) withObject:myString waitUntilDone:YES];
            [_lblStatus performSelectorOnMainThread:@selector(setTextColor:) withObject:[UIColor blueColor] waitUntilDone:YES];

            [self performSelectorOnMainThread:@selector(stopReading) withObject:nil waitUntilDone:NO];
            
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
    
    [self.lblStatus setText:@"Hay algun problema con tu conexión a internet o con el servidor de la SHCP, intenta más tarde"];
    self.lblStatus.textColor = [UIColor redColor];
    
    [connection cancel];
    connection = nil;
}

-(void)connectionDidFinishLoading:(NSURLConnection *)connection {
    NSLog(@"Received Bytes from server: %d", [self.webResponseData length]);
    NSString *myXMLResponse = [[NSString alloc] initWithBytes: [self.webResponseData bytes] length:[self.webResponseData length] encoding:NSUTF8StringEncoding];
    NSLog(@"%@", myXMLResponse);
    
    NSData *data = [myXMLResponse dataUsingEncoding:NSUTF8StringEncoding];
    
    NSXMLParser *xmlstr = [[NSXMLParser alloc] initWithData:data] ;
    xmlstr.delegate = self;
    [xmlstr parse];
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
    resultValue = [[NSMutableString alloc] init];
    
    [resultValue appendString:string];
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
    
    NSLog(@"Found an element named: %@ with a value of: %@", elementName, resultValue);
    
    
    if ([elementName isEqualToString:@"return"]){
        [self.lblStatus setText:resultValue];
        self.lblStatus.textColor = [UIColor greenColor];

    }
    
    
    
    /*if ([elementName isEqualToString:@"a:CodigoEstatus"]){
        //[resultValue appendString:[NSString stringWithFormat:@"%@ La factura es: ", resultValue]];
    } else if ([elementName isEqualToString:@"a:Estado"]){
        //[resultValue appendString:[NSString stringWithFormat:@"%@ La factura es: ", resultValue]];
        // [_lblStatus setText:[NSString stringWithFormat:@"La factura es: %@ ", resultValue]];
        
        if (validCDFI) {
            NSString *msg = [NSString stringWithFormat:@"Emisor: %@ \nReceptor: %@ \nMonto: %@ \nLa factura es: %@",
                           [cfdiData objectAtIndex:0],[cfdiData objectAtIndex:1],[cfdiData objectAtIndex:2], resultValue];
            
            msg = [msg stringByReplacingOccurrencesOfString:@"?re=" withString:@""];
            msg = [msg stringByReplacingOccurrencesOfString:@"rr=" withString:@""];
            msg = [msg stringByReplacingOccurrencesOfString:@"tt=" withString:@""];
            
            [self.lblStatus setText:msg];
            self.lblStatus.textColor = [UIColor greenColor];
        } /*else {
            [self.lblStatus setText:[NSString stringWithFormat:@"La factura es: %@ ", resultValue]];
            self.lblStatus.textColor = [UIColor redColor];
        }
           
    }*/
}


@end
