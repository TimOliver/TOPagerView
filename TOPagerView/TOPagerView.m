//
//  TOPagerView.m
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

#import "TOPagerView.h"
#import <QuartzCore/QuartzCore.h>

//Default Layout Properties
#define PAGEVIEW_DEFAULT_SPACING 20

//Convienience Definitions
#define PAGEVIEW_SCROLLVIEW_WIDTH           self.scrollView.bounds.size.width

#define PAGEVIEW_HALF_SPACING               floor(self.pageSpacing * 0.5f)
#define PAGEVIEW_HALF_SCROLLVIEW            floor(self.scrollView.bounds.size.width * 0.5f)
#define PAGEVIEW_EASTERN_MODE               (self.pageScrollDirection == TOPagerViewDirectionEastern)

#define PAGEVIEW_HEADER_VIEW                (self.headerFooterView ? self.headerFooterView : (self.headerView ? self.headerView : nil))
#define PAGEVIEW_FOOTER_VIEW                (self.headerFooterView ? self.headerFooterView : (self.footerView ? self.footerView : nil))

#define PAGEVIEW_NUMBEROFSLOTS              (self.numberOfPages + (PAGEVIEW_HEADER_VIEW ? 1 : 0) + (PAGEVIEW_FOOTER_VIEW ? 1 : 0))
#define PAGEVIEW_PUBLIC_INDEX(index)        (self.headerView || self.headerFooterView) ? index - 1 : index


//-------------------------------------------------------------------

@interface TOPagerView () <CAAnimationDelegate> {
    struct {
        //dataSource flags
        unsigned int dataSourceNumberOfPages;
        unsigned int dataSourcePageForIndex;
        
        //delegate flags
        unsigned int delegateWillInsertHeader;
        unsigned int delegateWillInsertFooter;
        unsigned int delegateWillJumpToIndex;
        
    } _pageScrollViewFlags;
}

/* A flag to temporarily disable laying out pages */
@property (nonatomic, assign) BOOL disablePageLayout;

/* Class prototype used to generate pages */
@property (nonatomic, assign) Class pageViewClass;

/* The main scroll view that displays the pagess */
@property (nonatomic, strong, readwrite) UIScrollView *scrollView;

/* Pages that are currently visibly placed in the scroll view */
@property (nonatomic, strong) NSMutableDictionary *visiblePages;

/* Pages that have been requeued into the pool, waiting for re-use */
@property (nonatomic, strong) NSMutableSet *recycledPages;

/* Perform all of the necessary initiliaztion steps. */
- (void)setup;

/* Perform all necessary clean-up steps. */
- (void)cleanup;

/* Return the appropriate frame for the main scroll view */
- (CGRect)frameForScrollView;

/* Return the frame for a page inside the main scroll view */
- (CGRect)frameForViewAtIndex:(NSInteger)index;

/* Return the content offset of a segment in the scroll view */
- (CGPoint)contentOffsetForScrollViewAtIndex:(NSInteger)index;

/* Return the content size of the main scroll view */
- (CGSize)contentSizeForScrollView;

/* Works out which pages need to be recycled, and lays out any new ones */
- (void)layoutPages;

/* Creates, and then lays out a single page or accessory view */
- (void)layoutViewAtScrollIndex:(NSInteger)index;

/* Get the current view, whether it's a page or an accessory */
- (UIView *)viewForCurrentScrollIndex;

@end

//-------------------------------------------------------------------

@implementation TOPagerView

#pragma mark -
#pragma mark Class Creation
- (id)init
{
    self = [super init];
    if (self)
    {
        [self setup];
    }
    
    return self;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        [self setup];
    }
    return self;
}

- (void)setup
{
    //default view properties
    self.autoresizingMask       = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    self.clipsToBounds          = YES;
    self.backgroundColor        = [UIColor clearColor];
    
    //default layout properties
    self.pageSpacing            = PAGEVIEW_DEFAULT_SPACING;
    self.pageScrollDirection    = TOPagerViewDirectionWestern;
    
    //create the page stores
    self.visiblePages           = [NSMutableDictionary dictionary];
    self.recycledPages          = [NSMutableSet set];
    
    //create the main scroll view
    self.scrollView                                 = [UIScrollView new];
    self.scrollView.pagingEnabled                   = YES;
    self.scrollView.showsHorizontalScrollIndicator  = NO;
    self.scrollView.showsVerticalScrollIndicator    = NO;
    self.scrollView.bouncesZoom                     = NO;
    [self addSubview:self.scrollView];
    
    //create an observer to monitor when the scroll view moves
    [self.scrollView addObserver:self forKeyPath:@"contentOffset" options:NSKeyValueObservingOptionNew context:NULL];
}

- (void)dealloc
{
    [self cleanup];
}

- (void)cleanup
{
    //remove any currently visible pages from the view
    for (UIView *page in self.visiblePages)
        [page removeFromSuperview];
    
    //clean up the page stores
    self.visiblePages = nil;
    self.recycledPages = nil;
    
    //remove the scroll view observer
    [self.scrollView removeObserver:self forKeyPath:@"contentOffset"];
}

- (void)registerPageViewClass:(Class)pageViewClass
{
    self.pageViewClass = pageViewClass;
}

- (void)didMoveToSuperview
{
    [super didMoveToSuperview];
    [self reloadPageScrollView];
}

#pragma mark -
#pragma mark System Notification Observation
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"contentOffset"])
        [self layoutPages];
}

#pragma mark -
#pragma mark Rendering Set-up and Initialization
- (void)reloadPageScrollView
{
    if (self.dataSource == nil)
        return;
    
    self.numberOfPages = 0;
    if (_pageScrollViewFlags.dataSourceNumberOfPages)
        self.numberOfPages = [self.dataSource numberOfPagesInPagerView:self];
    
    if (self.numberOfPages == 0)
        self.numberOfPages = 1;
    
    self.scrollView.frame = [self frameForScrollView];
    self.scrollView.contentSize = [self contentSizeForScrollView];
    
    [self layoutPages];
}

#pragma mark -
#pragma mark View Sizing and Layout
- (CGRect)frameForScrollView
{
    CGRect scrollFrame      = CGRectZero;
    scrollFrame.size.width  = CGRectGetWidth(self.bounds) + self.pageSpacing;
    scrollFrame.size.height = CGRectGetHeight(self.bounds);
    scrollFrame.origin.x    = 0.0f - PAGEVIEW_HALF_SPACING;
    scrollFrame.origin.y    = 0.0f;
    
    return scrollFrame;
}

- (CGPoint)contentOffsetForScrollViewAtIndex:(NSInteger)index
{
    CGPoint contentOffset = CGPointZero;
    contentOffset.y = 0.0f;
    
    //invert the layout direction for eastern mode
    if (PAGEVIEW_EASTERN_MODE)
        contentOffset.x = ((self.scrollView.contentSize.width) - (CGRectGetWidth(self.scrollView.bounds) * (index+1)));
    else
        contentOffset.x = (CGRectGetWidth(self.scrollView.bounds) * index);
    
    return contentOffset;
}

- (CGSize)contentSizeForScrollView
{
    CGSize contentSize = CGSizeZero;
    contentSize.height = CGRectGetHeight(self.bounds);
    contentSize.width  = PAGEVIEW_NUMBEROFSLOTS * (CGRectGetWidth(self.bounds) + self.pageSpacing);
    return contentSize;
}

- (CGRect)frameForViewAtIndex:(NSInteger)index
{
    CGFloat scrollViewWidth = CGRectGetWidth(self.scrollView.bounds);
    
    CGRect pageFrame = CGRectZero;
    pageFrame.size.height   = CGRectGetHeight(self.scrollView.bounds);
    pageFrame.size.width    = scrollViewWidth - self.pageSpacing;
    
    pageFrame.origin        = [self contentOffsetForScrollViewAtIndex:index];
    pageFrame.origin.x      += PAGEVIEW_HALF_SPACING;

    return pageFrame;
}

- (UIView *)viewForCurrentScrollIndex
{
    //if it's a standard page, return it
    UIView *page = [self.visiblePages objectForKey:@(self.scrollIndex)];
    if (page)
        return page;
    
    page = PAGEVIEW_HEADER_VIEW;
    if (page && self.scrollIndex == 0)
        return page;

    page = PAGEVIEW_FOOTER_VIEW;
    if (page && self.scrollIndex >= PAGEVIEW_NUMBEROFSLOTS-1)
        return page;
        
    return nil;
}

- (void)layoutPages
{
    if (self.disablePageLayout || self.numberOfPages == 0)
        return;

    //-------------------------------------------------------------------
    
    //Determine which pages are currently visible on screen
    CGPoint     contentOffset       = self.scrollView.contentOffset;
    
    //Work out the number of slots the scroll view has (eg, pages + accessories)
    NSInteger numberOfPageSlots = PAGEVIEW_NUMBEROFSLOTS;
    
    //Determine the origin page on the far left
    NSRange visiblePagesRange   = NSMakeRange(0, 1);
    visiblePagesRange.location  = MAX(0, floor(contentOffset.x / PAGEVIEW_SCROLLVIEW_WIDTH));
    
    //Based on the delta between the offset of that page from the current offset, determine if the page after it is visible
    CGFloat pageOffsetDelta     = contentOffset.x - (visiblePagesRange.location * PAGEVIEW_SCROLLVIEW_WIDTH);
    visiblePagesRange.length    = fabs(pageOffsetDelta) > PAGEVIEW_HALF_SPACING ? 2 : 1;
    
    //cap the values to ensure we don't go past the absolute bounds
    visiblePagesRange.location  = MAX(visiblePagesRange.location, 0);
    visiblePagesRange.location  = MIN(visiblePagesRange.location, numberOfPageSlots-1);
    
    visiblePagesRange.length    = contentOffset.x < 0.0f + FLT_EPSILON ? 1 : visiblePagesRange.length;
    visiblePagesRange.length    = (visiblePagesRange.location == numberOfPageSlots-1) ? 1 : visiblePagesRange.length;
    
    //Work out at which index we are scrolled to (Whichever one is overlappting the middle
    self.scrollIndex = floor((self.scrollView.contentOffset.x + (PAGEVIEW_SCROLLVIEW_WIDTH * 0.5f)) / PAGEVIEW_SCROLLVIEW_WIDTH);
    self.scrollIndex = MIN(self.scrollIndex, PAGEVIEW_NUMBEROFSLOTS-1);
    self.scrollIndex = MAX(self.scrollIndex, 0);
    
    //if we're in eastern mode, swap the origin
    if (PAGEVIEW_EASTERN_MODE)
    {
        visiblePagesRange.location = numberOfPageSlots - visiblePagesRange.location;
        self.scrollIndex = numberOfPageSlots - self.scrollIndex;
    }
        
    //-------------------------------------------------------------------
    
    //work out if any visible pages need to be removed, and remove as necessary
    __block NSInteger visiblePagesCount = 0;
    NSSet *keysToRemove = [self.visiblePages keysOfEntriesWithOptions:NSEnumerationConcurrent passingTest:^BOOL (NSNumber *pageNumber, UIView *page, BOOL *stop) {
        if (NSLocationInRange(pageNumber.unsignedIntegerValue, visiblePagesRange) == NO)
        {
            //move the page back into the recycle pool
            UIView *page = (UIView *)self.visiblePages[pageNumber];
            [self.recycledPages addObject:page];
            [page removeFromSuperview];
            
            return YES;
        }
        
        visiblePagesCount++;
        return NO;
    }];
    [self.visiblePages removeObjectsForKeys:[keysToRemove allObjects]];
    
    //if there are any accessory views, work out if they need to be removed
    //remove either headerFooter view
    if (self.headerFooterView.superview)
    {
        if (visiblePagesRange.location > 0 && (NSMaxRange(visiblePagesRange)-1) < numberOfPageSlots-1)
            [self.headerFooterView removeFromSuperview];
        else
            visiblePagesCount++;
    }
    
    //remove header view if necessary
    if (self.headerView.superview)
    {
        if (visiblePagesRange.location > 0)
            [self.headerView removeFromSuperview];
        else
            visiblePagesCount++;
    }

    //remove footer view if necessary
    if (self.footerView.superview)
    {
        if ((NSMaxRange(visiblePagesRange)-1) < numberOfPageSlots-1)
            [self.footerView removeFromSuperview];
        else
            visiblePagesCount++;
    }
    
    //-------------------------------------------------------------------
    
    //if the number of visible pages is what we were expecting, there's no need to continue
    if (visiblePagesCount == visiblePagesRange.length)
        return;
    
    //go through and insert all new pages necessary
    for (NSInteger i = visiblePagesRange.location; i < NSMaxRange(visiblePagesRange); i++)
        [self layoutViewAtScrollIndex:i];
}

- (void)layoutViewAtScrollIndex:(NSInteger)scrollIndex
{
    NSInteger numberOfPageSlots = PAGEVIEW_NUMBEROFSLOTS;
    scrollIndex = MAX(0, scrollIndex);
    scrollIndex = MIN(numberOfPageSlots, scrollIndex);
    
    //add the header view
    UIView *headerView = PAGEVIEW_HEADER_VIEW;
    if (headerView && scrollIndex == 0)
    {
        if (headerView.superview == nil)
        {
            //configure frame to match
            headerView.frame    = [self frameForViewAtIndex:0];
            headerView.tag      = 0;
            
            //inform the delegate in case it needs to update itself
            if (_pageScrollViewFlags.delegateWillInsertHeader)
                [self.delegate pagerView:self willInsertHeaderView:headerView];
            
            [self.scrollView addSubview:headerView];
        }
        
        return;
    }
    
    UIView *footerView = PAGEVIEW_FOOTER_VIEW;
    if (footerView && scrollIndex >= PAGEVIEW_NUMBEROFSLOTS-1) //add the footer view
    {
        if (footerView.superview == nil)
        {
            //configure frame to match
            footerView.frame    = [self frameForViewAtIndex:PAGEVIEW_NUMBEROFSLOTS-1];
            footerView.tag      = PAGEVIEW_NUMBEROFSLOTS-1;
            
            //inform the delegate in case it needs to update itself
            if (_pageScrollViewFlags.delegateWillInsertFooter)
                [self.delegate pagerView:self willInsertFooterView:footerView];
            
            [self.scrollView addSubview:footerView];
        }
        
        return;
    }
    
    //add as a page
    if ([self.visiblePages objectForKey:@(scrollIndex)])
        return;
    
    UIView *page = nil;
    if (_pageScrollViewFlags.dataSourcePageForIndex)
        page = [self.dataSource pagerView:self pageViewForIndex:PAGEVIEW_PUBLIC_INDEX(scrollIndex)];
    
    if (page == nil)
        @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Page from data source cannot be nil!" userInfo:nil];
    
    page.frame = [self frameForViewAtIndex:scrollIndex];
    [self.scrollView addSubview:page];
    [self.visiblePages setObject:page forKey:@(scrollIndex)];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    //disable the layout code since we'll be manually doing it here
    self.disablePageLayout = YES;
    
    //re-align the scroll view to our new bounds
    self.scrollView.frame           = [self frameForScrollView];
    self.scrollView.contentSize     = [self contentSizeForScrollView];
    self.scrollView.contentOffset   = [self contentOffsetForScrollViewAtIndex:self.scrollIndex];
    
    //resize any visible pages
    [self.visiblePages enumerateKeysAndObjectsUsingBlock:^(NSNumber *pageNumber, UIView *page, BOOL *stop) {
        page.frame = [self frameForViewAtIndex:pageNumber.unsignedIntegerValue];
    }];
    
    //place the header/footer views
    if (self.headerFooterView.superview)
        self.headerFooterView.frame = [self frameForViewAtIndex:self.headerFooterView.tag];
    
    //place the header view
    if (self.headerView)
        self.headerView.frame = [self frameForViewAtIndex:self.headerView.tag];
    
    //place the footer view
    if (self.footerView)
        self.footerView.frame = [self frameForViewAtIndex:self.footerView.tag];
    
    //re-enable the layout code
    self.disablePageLayout = NO;
}

#pragma mark -
#pragma mark Page Recycling
- (UIView *)dequeueReusablePageView
{
    UIView *pageView = [self.recycledPages anyObject];

    if (pageView)
    {
        pageView.frame = self.bounds;
        [self.recycledPages removeObject:pageView];
    }
    else if (self.pageViewClass)
    {
        pageView = [[self.pageViewClass alloc] initWithFrame:self.bounds];
    }
        
    return pageView;
}

#pragma mark -
#pragma mark Page Navigation
- (BOOL)canGoBack
{
    return self.scrollIndex > 0;
}

- (BOOL)canGoForward
{
    return self.scrollIndex < PAGEVIEW_NUMBEROFSLOTS-1;
}

- (void)turnToNextPageAnimated:(BOOL)animated
{
    if ([self canGoForward] == NO)
        return;
    
    NSInteger index = self.scrollIndex;
    if (PAGEVIEW_HEADER_VIEW)
        index--;
    
    [self turnToPageAtIndex:index+1 animated:YES];
}

- (void)turnToPreviousPageAnimated:(BOOL)animated
{
    if ([self canGoBack] == NO)
        return;
    
    NSInteger index = self.scrollIndex;
    if (PAGEVIEW_HEADER_VIEW)
        index--;
    
    [self turnToPageAtIndex:index-1 animated:YES];
}

- (void)turnToPageAtIndex:(NSInteger)index animated:(BOOL)animated
{
    //verify index is valid (Still in page space and not scroll space)
    if (PAGEVIEW_HEADER_VIEW)
        index = MAX(-1, index);
    else
        index = MAX(0, index);
    
    if (PAGEVIEW_FOOTER_VIEW)
        index = MIN(self.numberOfPages, index);
    else
        index = MIN(self.numberOfPages-1, index);
    
    //convert to scroll space
    if (PAGEVIEW_HEADER_VIEW)
        index++;
    
    if (animated == NO)
    {
        self.scrollView.contentOffset = [self contentOffsetForScrollViewAtIndex:index];
        [self layoutPages];
    }
    else
    {
        static NSString *animationKey = @"pageTurnAnimation";
        
        //if we're already animating, cancel that last animation
        CABasicAnimation *animation = (CABasicAnimation *)[self.scrollView.layer animationForKey:animationKey];
        if (animation != nil)
        {
            [self.scrollView.layer removeAnimationForKey:animationKey];
            animation = nil;
            
            self.disablePageLayout = NO;
            [self layoutPages];
        }
        
        //disable page layout (We'll manually handle placement here)
        self.disablePageLayout = YES;
        
        //if we're turning more than one page away, move the current page right up to the side of the target page,
        //so we can have a seamless jump animation
        if (labs(index - self.scrollIndex) > 1)
        {
            UIView *page = [self viewForCurrentScrollIndex];
            
            NSInteger newIndex = 0;
            if (index > self.scrollIndex)
                newIndex = index - 1;
            else
                newIndex = index + 1;
            
            //jump to the position just before
            page.frame = [self frameForViewAtIndex:newIndex];
            self.scrollView.contentOffset = [self contentOffsetForScrollViewAtIndex:newIndex];
        }
        
        //layout the target cell
        [self layoutViewAtScrollIndex:index];
        
        //set up the animation
        animation = [CABasicAnimation animationWithKeyPath:@"bounds"];
        animation.duration = 0.35f;
        animation.delegate = self;
        animation.timingFunction = [CAMediaTimingFunction functionWithControlPoints:0.30f :0.60f :0.35f :0.95f];
        
        CGRect bounds = self.scrollView.bounds;
        animation.fromValue = [NSValue valueWithCGRect:bounds];
        bounds.origin = [self contentOffsetForScrollViewAtIndex:index];
        animation.toValue = [NSValue valueWithCGRect:bounds];
        
        [self.scrollView.layer addAnimation:animation forKey:animationKey];
        self.scrollView.contentOffset = bounds.origin;
        
        //update the scroll index to the new value
        self.scrollIndex = index;
    }
    
    if (_pageScrollViewFlags.delegateWillJumpToIndex)
        [self.delegate pagerView:self willJumpToPageAtIndex:index];
}

- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag
{
    if (flag==NO)
        return;
    
    //re-enable the page layout and perform a refresh
    self.disablePageLayout = NO;
    [self layoutPages];
    
    if (self.scrollView.delegate && [self.scrollView.delegate respondsToSelector:@selector(scrollViewDidEndScrollingAnimation:)])
        [self.scrollView.delegate scrollViewDidEndScrollingAnimation:self.scrollView];
}

#pragma mark -
#pragma mark Accessor Methods
- (NSInteger)pageIndex
{
    NSInteger pageIndex = self.scrollIndex;
    
    //subtract by one to remove the header
    if (PAGEVIEW_HEADER_VIEW && pageIndex > 0)
        pageIndex--;
    
    //cap to the maximum number of pages (which will remove the footer)
    if (pageIndex >= self.numberOfPages)
        pageIndex = self.numberOfPages-1;
    
    return pageIndex;
}

- (void)setPageIndex:(NSInteger)pageIndex
{
    [self turnToPageAtIndex:pageIndex animated:NO];
}

- (void)setDelegate:(id<TOPagerViewDelegate>)delegate
{
    _delegate = delegate;
    
    _pageScrollViewFlags.delegateWillInsertFooter   = [_delegate respondsToSelector:@selector(pagerView:willInsertFooterView:)];
    _pageScrollViewFlags.delegateWillInsertHeader   = [_delegate respondsToSelector:@selector(pagerView:willInsertHeaderView:)];
    _pageScrollViewFlags.delegateWillJumpToIndex    = [_delegate respondsToSelector:@selector(pagerView:willJumpToPageAtIndex:)];
}

- (void)setDataSource:(id<TOPagerViewDataSource>)dataSource
{
    _dataSource = dataSource;
    
    _pageScrollViewFlags.dataSourceNumberOfPages    = [_dataSource respondsToSelector:@selector(numberOfPagesInPagerView:)];
    _pageScrollViewFlags.dataSourcePageForIndex     = [_dataSource respondsToSelector:@selector(pagerView:pageViewForIndex:)];
}

@end
