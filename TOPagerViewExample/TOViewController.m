//
//  TOViewController.m
//  TOPagerView
//
//  Created by Timothy OLIVER on 20/11/13.
//  Copyright (c) 2013-2017 Timothy Oliver. All rights reserved.
//

#import "TOViewController.h"
#import "TOPagerView.h"

@interface TOViewController () <TOPagerViewDataSource, TOPagerViewDelegate, UIScrollViewDelegate>
@property (nonatomic, strong) TOPagerView *pagerView;
@end

// --------------------------------------------------------------------------------------------

@implementation TOViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Set the basic vide controller properties
    self.title = @"TOPagerView";
    self.view.backgroundColor = [UIColor blackColor];

    // Add a 'Next' and 'Prev' button to the navigation bar
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Prev" style:UIBarButtonItemStylePlain target:self action:@selector(leftButtonTapped:)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Next" style:UIBarButtonItemStylePlain target:self action:@selector(rightButtonTapped:)];

    // Set up the pager view
    self.pagerView = [[TOPagerView alloc] initWithFrame:self.view.bounds];
    self.pagerView.scrollView.delegate = self; // The internal scroll view delegate is available publicly
    self.pagerView.dataSource  = self;
    self.pagerView.delegate    = self;
    [self.view addSubview:self.pagerView];

    // Create a single view that will be recycled for both the first and last accessory views
    self.pagerView.headerFooterView = [[UIView alloc] init];
    self.pagerView.headerFooterView.backgroundColor = [UIColor redColor];
}

#pragma mark - Pager View Delegate -

- (UILabel *)newAccessoryViewLabelInView:(UIView *)view
{
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 100, 60)];
    label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 100, 60)];
    label.backgroundColor = view.backgroundColor;
    label.font = [UIFont boldSystemFontOfSize:20.0f];
    label.textAlignment = NSTextAlignmentCenter;
    label.tag = 1;
    label.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    label.center = CGPointMake(CGRectGetMidX(view.bounds), CGRectGetMidY(view.bounds));
    [view addSubview:label];
    return label;
}

- (void)pagerView:(TOPagerView *)pageScrollView willInsertFooterView:(UIView *)footerView
{
    UILabel *label = (UILabel *)[footerView viewWithTag:1];
    if (label == nil) {
        label = [self newAccessoryViewLabelInView:footerView];
    }
    
    label.text = @"Footer";
}

- (void)pagerView:(TOPagerView *)pageScrollView willInsertHeaderView:(UIView *)headerView
{
    UILabel *label = (UILabel *)[headerView viewWithTag:1];
    if (label == nil) {
        label = [self newAccessoryViewLabelInView:headerView];
    }
    
    label.text = @"Header";
}

#pragma mark - Pager View Data Source -

- (NSInteger)numberOfPagesInPagerView:(TOPagerView *)pageScrollView
{
    return 8;
}

- (UIView *)pagerView:(TOPagerView *)pageScrollView pageViewForIndex:(NSInteger)pageIndex
{
    UIView *view = [pageScrollView dequeueReusablePageView];
    if (view == nil)
    {
        view = [UIView new];
        view.backgroundColor = [UIColor whiteColor];
        [self newAccessoryViewLabelInView:view];
    }

    UILabel *label = (UILabel *)[view viewWithTag:1];
    label.text = [NSString stringWithFormat:@"%ld", (long)pageIndex];
    return view;
}

#pragma mark - Button Callbacks -

- (void)leftButtonTapped:(id)sender
{
    [self.pagerView turnToPreviousPageAnimated:YES];
}

- (void)rightButtonTapped:(id)sender
{
    [self.pagerView turnToNextPageAnimated:YES];
}

@end
