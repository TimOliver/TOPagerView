//
//  TOViewController.m
//  TOPagerView
//
//  Created by Timothy OLIVER on 20/11/13.
//  Copyright (c) 2013 Timothy Oliver. All rights reserved.
//

#import "TOViewController.h"
#import "TOPagerView.h"

@interface TOViewController () <TOPagerViewDataSource, TOPagerViewDelegate, UIScrollViewDelegate>

@property (nonatomic, strong) TOPagerView *pagerView;

- (void)leftButtonTapped:(id)sender;
- (void)rightButtonTapped:(id)sender;

@end

@implementation TOViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = @"TOPagerView";

    if ([self respondsToSelector:@selector(setAutomaticallyAdjustsScrollViewInsets:)])
        self.automaticallyAdjustsScrollViewInsets = NO;
	
    self.view.backgroundColor = [UIColor blackColor];

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Prev" style:UIBarButtonItemStylePlain target:self action:@selector(leftButtonTapped:)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Next" style:UIBarButtonItemStylePlain target:self action:@selector(rightButtonTapped:)];
    
    self.pagerView = [[TOPagerView alloc] initWithFrame:self.view.bounds];
    self.pagerView.scrollView.delegate = self;
    self.pagerView.dataSource  = self;
    self.pagerView.delegate    = self;
    self.pagerView.headerFooterView = [UIView new];
    self.pagerView.headerFooterView.backgroundColor = [UIColor redColor];
    
    [self.view addSubview:self.pagerView];
}

- (void)pagerView:(TOPagerView *)pageScrollView willInsertFooterView:(UIView *)footerView
{
    UILabel *label = (UILabel *)[footerView viewWithTag:1];
    if (label == nil)
    {
        label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 100, 60)];
        label.backgroundColor = [UIColor redColor];
        label.font = [UIFont boldSystemFontOfSize:20.0f];
        label.textAlignment = NSTextAlignmentCenter;
        label.tag = 1;
        label.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        label.center = CGPointMake(CGRectGetMidX(footerView.bounds), CGRectGetMidY(footerView.bounds));
        [footerView addSubview:label];
    }
    
    [label setText:@"Footer"];
}

- (void)pagerView:(TOPagerView *)pageScrollView willInsertHeaderView:(UIView *)headerView
{
    UILabel *label = (UILabel *)[headerView viewWithTag:1];
    if (label == nil)
    {
        label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 100, 60)];
        label.backgroundColor = [UIColor redColor];
        label.font = [UIFont boldSystemFontOfSize:20.0f];
        label.textAlignment = NSTextAlignmentCenter;
        label.tag = 1;
        label.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        label.center = CGPointMake(CGRectGetMidX(headerView.bounds), CGRectGetMidY(headerView.bounds));
        [headerView addSubview:label];
    }
    
    [label setText:@"Header"];
}


- (NSInteger)numberOfPagesInPagerView:(TOPagerView *)pageScrollView
{
    return 5;
}

- (UIView *)pagerView:(TOPagerView *)pageScrollView pageViewForIndex:(NSInteger)pageIndex
{
    UIView *view = [pageScrollView dequeueReusablePageView];
    if (view == nil)
    {
        view = [UIView new];
        view.backgroundColor = [UIColor whiteColor];
        
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 100, 60)];
        label.backgroundColor = [UIColor whiteColor];
        label.font = [UIFont boldSystemFontOfSize:20.0f];
        label.textAlignment = NSTextAlignmentCenter;
        label.tag = 1;
        label.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        label.center = CGPointMake(CGRectGetMidX(view.bounds), CGRectGetMidY(view.bounds));
        [view addSubview:label];
    }
        
    [(UILabel *)[view viewWithTag:1] setText:[NSString stringWithFormat:@"%ld", (long)pageIndex]];
    return view;
}

- (void)leftButtonTapped:(id)sender
{
    [self.pagerView turnToPreviousPageAnimated:YES];
}

- (void)rightButtonTapped:(id)sender
{
    [self.pagerView turnToNextPageAnimated:YES];
}

@end
