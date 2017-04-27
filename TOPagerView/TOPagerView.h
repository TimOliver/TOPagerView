//
//  TOPagerView.h
//
//  Copyright 2013-2017 Timothy Oliver. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
//  OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR
//  IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#import <UIKit/UIKit.h>

@class TOPagerView;

//-------------------------------------------------------------------
/** An enumeration of directions in which the scroll view may display pages. */
typedef enum {
    TOPagerViewDirectionLeftToRight = 0, /** Pages ascend from the left, to the right */
    TOPagerViewDirectionRightToLeft  = 1 /** Pages ascend from the right, to the left */
} TOPagerViewDirection;

//-------------------------------------------------------------------

/** Optional protocol that page views may implement. */
@protocol TOPagerViewPageProtocol <NSObject>

@optional

/**
 A unique string value that can be used to differentiate 
 separate view subclasses managed and displayed by the pager view.
 */
+ (NSString *)pageIdentifier;

/**
 Called just before the page object is 
 dequeued for re-use by the data source
 */
- (void)prepareForReuse;

@end

//-------------------------------------------------------------------

@protocol TOPagerViewDataSource <NSObject>

@required

/** Asks for the number of pages that will be displayed in the scroll view */
- (NSInteger)numberOfPagesInPagerView:(TOPagerView *)pageScrollView;

/** Asks for a page view object to insert at the appropriate index */
- (UIView *)pagerView:(TOPagerView *)pagerView pageViewForIndex:(NSInteger)pageIndex;

@end

//-------------------------------------------------------------------

@protocol TOPagerViewDelegate <NSObject>

@optional

/** Informs the delegate that the header view is about to be inserted into the scroll view */
- (void)pagerView:(TOPagerView *)pagerView willInsertHeaderView:(UIView *)headerView;

/** Informs the delegate that the footer view is about to be inserted into the scroll view */
- (void)pagerView:(TOPagerView *)pagerView willInsertFooterView:(UIView *)footerView;

/** Informs the delegate when the page scroll view is about to jump to another page */
- (void)pagerView:(TOPagerView *)pagerView willJumpToPageAtIndex:(NSInteger)pageIndex;

@end

//-------------------------------------------------------------------

@interface TOPagerView : UIView
    
/** Direct access to the scroll view object inside this view (read-only). */
@property (nonatomic, strong, readonly) UIScrollView *scrollView;

/** Data source object to supply page information to the scroll view */
@property (nonatomic, weak) id <TOPagerViewDataSource> dataSource;

/** Delegate object in which page scroll view events are sent. */
@property (nonatomic, weak) id <TOPagerViewDelegate> delegate;

/** The number of pages in the scroll view */
@property (nonatomic, assign) NSInteger numberOfPages;

/** Width of the spacing between pages in points (default value of 40). */
@property (nonatomic, assign) CGFloat pageSpacing;

/** The direction of the layout order of pages. */
@property (nonatomic, assign) TOPagerViewDirection pageScrollDirection;

/** Returns the index of the currently displayed page (Excluding accessory views, which will return the closest page). */
@property (nonatomic, assign) NSInteger pageIndex;

/* The current index that the scroll view is at, (Including accessory views) */
@property (nonatomic, assign) NSInteger scrollIndex;

/** Header and/or footer views for the scroll view */
@property (nonatomic, strong) UIView *headerView;       /** A view placed before the first page in the scroll view */
@property (nonatomic, strong) UIView *footerView;       /** A view placed after the last page in the scroll view */
@property (nonatomic, strong) UIView *headerFooterView; /** A single view that will be re-used for both header and footer */

/** Reload the view from scratch and re-layout all pages */
- (void)reloadPageScrollView;

/** Registers a page view class that can be automatically instantiated as needed. */
- (void)registerPageViewClass:(Class)pageViewClass;

/** Returns a recycled page view from the default pool, ready for re-use. */
- (UIView *)dequeueReusablePageView;

- (UIView *)dequeueReusablePageViewForIdentifier:(NSString *)identifier;

/** Page Navigation Checking */
- (BOOL)canGoForward;
- (BOOL)canGoBack;

/** Advance/Retreat the page by one (including accessory views) */
- (void)turnToNextPageAnimated:(BOOL)animated;
- (void)turnToPreviousPageAnimated:(BOOL)animated;

/* Jump to a specific page (-1 for header, self.numberOfPages for footer) */
- (void)turnToPageAtIndex:(NSInteger)pageIndex animated:(BOOL)animated;

@end
