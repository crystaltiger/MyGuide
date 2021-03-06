//
//  DetailsMapViewController.m
//  MyGuide
//
//  Created by Kamil Lelonek on 4/8/14.
//  Copyright (c) 2014 - Open Source (Apache 2.0 license). All rights reserved.
//

#import "DetailsMapViewController.h"
#import "Settings.h"
#import "GraphDrawer.h"
#import "AFParsedData.h"
#import "AFWay.h"

@interface DetailsMapViewController ()

@property (nonatomic) CLLocationCoordinate2D destinationCoordinates;
@property (nonatomic) Settings    *sharedSettings;
@property (nonatomic) GraphDrawer *graphDrawer;

@property BOOL fitToPath;
@property BOOL showDirections;
@property BOOL drawPath;

@end

@implementation DetailsMapViewController

double const ZOOM_LEVEL = 15;

- (instancetype)initWithCoder: (NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        _sharedSettings = [Settings sharedSettingsData];
        _graphDrawer    = [GraphDrawer sharedInstance];
    }
    return self;
}

- (void) viewDidLoad
{
    [super viewDidLoad];
    self.fitToPath = YES;
    [self configureToolbar];
}

- (void) viewWillAppear: (BOOL) animated {
    [self setupMapView];
    [self drawTargetPoint];
    [self drawCoordinatesOnMap];
    self.mapView.mapType = MKMapTypeHybrid;
}
- (void)configureToolbar
{
    UIColor *tintColor = [UIColor colorWithRed:1.0f green:0.584f blue:0.0f alpha:1.0f];
    
    MKUserTrackingBarButtonItem *trackingButton = [[MKUserTrackingBarButtonItem alloc] initWithMapView:self.mapView];
    trackingButton.customView.backgroundColor   = [UIColor clearColor];
    trackingButton.customView.tintColor         = tintColor;
    
    UIBarButtonItem *flexibleSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    
    UIBarButtonItem *mapTypebButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"mapType"] style:UIBarButtonItemStylePlain target:self action:@selector(changeMapType)];
    mapTypebButton.tintColor        = tintColor;
    
    [self.mapToolbar setBackgroundImage:[UIImage imageNamed:@"buttonBackgroundImage"] forToolbarPosition:UIBarPositionAny barMetrics:UIBarMetricsDefault];
    self.mapToolbar.items = @[trackingButton, flexibleSpace, mapTypebButton];
}
- (void)changeMapType
{
    if(self.mapView.mapType == MKMapTypeStandard){
        self.mapView.mapType = MKMapTypeHybrid;
    }
    else{
        self.mapView.mapType = MKMapTypeStandard;
    }
}
- (void) drawCoordinatesOnMap
{
    if (self.showDirections) {
        [self drawDirectionsToLocation];
        [self setMapRegion];
    }
    else if (self.drawPath) {
        [self drawPathToAnimal];
    }
    else {
        [self zoomOnLocation: self.destinationCoordinates];
    }
}

- (void) setupMapView
{
    [self.mapView setShowsUserLocation: YES];
    [self.mapView setMapType: MKMapTypeStandard];
    self.mapView.delegate = self;
}

- (void)      mapView: (MKMapView *)      mapView
didUpdateUserLocation: (MKUserLocation *) userLocation
{
    [self drawCoordinatesOnMap];
    if (self.fitToPath) [self setMapRegion];
}

- (void) zoomOnLocation: (CLLocationCoordinate2D) coordinates
{
    MKCoordinateSpan span = MKCoordinateSpanMake(180 / pow(2, ZOOM_LEVEL) * self.mapView.frame.size.height / 256, 0);
    [self.mapView setRegion: MKCoordinateRegionMake(coordinates, span) animated: YES];
}

- (void) drawTargetPoint
{
    [self.mapView removeAnnotations: self.mapView.annotations];
    self.destinationCoordinates         = CLLocationCoordinate2DMake(self.latitude, self.longitude);
    MKPointAnnotation *annotationPoint  = [MKPointAnnotation new];
    annotationPoint.title               = self.nameToDisplay;
    annotationPoint.coordinate          = self.destinationCoordinates;
    [self.mapView addAnnotation: annotationPoint];
}

- (void) showZOO
{
    self.showDirections = YES;
    self.nameToDisplay  = @"ZOO";
    self.latitude  = self.sharedSettings.zooCenter.latitude;
    self.longitude = self.sharedSettings.zooCenter.longitude;
}

- (void) drawPathToAnimal {
    self.drawPath = YES;
    CLLocation *destinationLocation = [[CLLocation alloc] initWithLatitude:self.destinationCoordinates.latitude longitude:self.destinationCoordinates.longitude];
    CLLocation *userLocation = self.mapView.userLocation.location;
    MKPolyline *path = [self.graphDrawer findShortestPathBetweenLocation: userLocation andLocation: destinationLocation];
    if(path) {
        [self.mapView removeOverlays:self.mapView.overlays];
        [self.mapView addOverlay: path];
        [self showPaths];
    }
}
- (void)showPaths
{
    for(AFWay *way in [[AFParsedData sharedParsedData] waysArray]) [self drawPath:way.nodesArray];
}
- (void)drawPath:(NSArray *)nodesArray
{
    CLLocationCoordinate2D coordinatesArray[[nodesArray count]];
    NSUInteger i = 0;
    for(AFNode* node in nodesArray){
        CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(node.latitude, node.longitude);
        coordinatesArray[i++] = coordinate;
    }
    
    MKPolyline *path = [MKPolyline polylineWithCoordinates:coordinatesArray count:[nodesArray count]];
    path.title = @"regularPath";
    [self.mapView addOverlay:path];
}

- (MKAnnotationView *)mapView:(MKMapView *)mapview viewForAnnotation:(id <MKAnnotation>)annotation
{
    if ([annotation isKindOfClass:[MKUserLocation class]]) return nil;
    
    static NSString *AnnotationIdentifier = @"ZOO";
    MKAnnotationView *annotationView = [self.mapView dequeueReusableAnnotationViewWithIdentifier:AnnotationIdentifier];
    
    if(annotationView) return annotationView;
    else
    {
        MKAnnotationView *annotationView = [[MKAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:AnnotationIdentifier];
        annotationView.image = [UIImage imageNamed:@"pinOrange"];
        return annotationView;
    }
    return nil;
}

# pragma mark - Rendering directions

- (void) drawDirectionsToLocation
{
    MKMapItem *sourceMapItem = [MKMapItem mapItemForCurrentLocation];
    [sourceMapItem setName: NSLocalizedString(@"yourLocation", nil)];
    
    MKPlacemark *destination      = [[MKPlacemark alloc] initWithCoordinate: self.destinationCoordinates addressDictionary: nil];
    MKMapItem *destinationMapItem = [[MKMapItem alloc] initWithPlacemark: destination];
    [destinationMapItem setName: self.nameToDisplay];
    
    MKDirectionsRequest *request = [MKDirectionsRequest new];
    [request setSource: sourceMapItem];
    [request setDestination: destinationMapItem];
    
    MKDirections *direction = [[MKDirections alloc] initWithRequest: request];
    [direction calculateDirectionsWithCompletionHandler: ^(MKDirectionsResponse *response, NSError *error) {
        if (error) {
            NSLog(@"There was an error getting your directions.");
            NSLog(@"%@", error.userInfo[@"NSLocalizedFailureReason"]);
            NSLog(@"%@", error.userInfo[@"NSLocalizedDescription"]);
            [self zoomOnLocation: self.destinationCoordinates];
            return;
        }
        
        MKRoute *route = [response.routes firstObject];
        NSArray *steps = [route steps];
        [self.mapView removeOverlay: self.mapView.overlays.lastObject];
        [self.mapView addOverlay: [route polyline]];
        
        NSLog(@"Total Distance (in Meters) : %.0f", route.distance);
        NSLog(@"Total Steps : %lu",(unsigned long)[steps count]);
        
        [steps enumerateObjectsUsingBlock: ^(id obj, NSUInteger idx, BOOL *stop) {
            NSLog(@"Route Instruction : %@",[obj instructions]);
            NSLog(@"Route Distance : %.0f",   [obj distance]);
        }];
    }];
}

- (MKOverlayRenderer *) mapView:(MKMapView *)mapView
             rendererForOverlay:(id<MKOverlay>)overlay
{
    MKPolylineRenderer *renderer = [[MKPolylineRenderer alloc] initWithPolyline: overlay];
    MKPolyline *path = overlay;
    if([path.title isEqualToString:@"regularPath"]){
        renderer.strokeColor = [UIColor brownColor];
        renderer.lineCap     = kCGLineCapRound;
        renderer.lineJoin    = kCGLineJoinRound;
        renderer.lineWidth   = 3;
        renderer.alpha       = 0.7;
    }
    else{
        renderer.strokeColor = [UIColor orangeColor];
        renderer.lineCap     = kCGLineCapRound;
        renderer.lineJoin    = kCGLineJoinRound;
        renderer.lineWidth   = 4.0;
    }
    return  renderer;
}

- (void) setMapRegion
{
    MKPointAnnotation *annotationUser         = [MKPointAnnotation new];
    annotationUser.coordinate                 = self.destinationCoordinates;
    MKPointAnnotation *annotationDestination  = [MKPointAnnotation new];
    annotationDestination.coordinate          = self.mapView.userLocation.coordinate;
    
    if (self.mapView.userLocation.coordinate.latitude  == 0 &&
        self.mapView.userLocation.coordinate.longitude == 0)
    {
        [self zoomOnLocation: self.destinationCoordinates];
    }
    else
    {
        NSArray *annotations = @[annotationUser, annotationDestination];
        [self.mapView showAnnotations: annotations animated: YES];
        [self.mapView removeAnnotations: annotations];
        self.fitToPath = NO;
    }
}

@end