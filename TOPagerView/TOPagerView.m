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



// Constant Definitions
static NSString * const kTOPagerViewDefaultPageIdentifier = @"__TOPagerViewDefaultIdentifier";

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
        unsigned int delegateDidTurnToIndex;
        
    } _pageScrollViewFlags;
}

/* A flag to temporarily disable laying out pages during animations */
@property (nonatomic, assign) BOOL disablePageLayout;

/* Class prototype used to generate pages */
@property (nonatomic, assign) NSMutableDictionary<NSString *, NSValue *> *pageViewClasses;

/* The main scroll view that displays the pagess */
@property (nonatomic, strong, readwrite) UIScrollView *scrollView;

/* Pages that are currently visibly placed in the scroll view */
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, UIView *> *visiblePageViews;

/* A dictionary containing multiple pools of page views that can be reused */
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableSet *> *recycledPageSets;

/* Works out how many slots this pager view has, including accessory views. */
@property (nonatomic, readonly) NSInteger numberOfPageSlots;

/* Returns the view displayed at the front of the pages (Whether it is the header, or headerFooter view) */
@property (nonatomic, nullable, readonly) UIView *leadingAccessoryView;

/* Returns the view displayed at the end of the pages (Whether it is the footer, or headerFooter view) */
@property (nonatomic, nullable, readonly) UIView *trailingAccessoryView;

@end

//-------------------------------------------------------------------

@implementation TOPagerView

#pragma mark - Class Creation -
- (id)init
{
    self = [super init];
    if (self) {
        [self setup];
    }
    
    return self;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setup];
    }
    return self;
}

- (void)setup
{
    // Default view properties
    self.autoresizingMask       = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    self.clipsToBounds          = YES;
    self.backgroundColor        = [UIColor clearColor];
    
    // Default layout properties
    self.pageSpacing            = 20.0f;
    self.pageScrollDirection    = TOPagerViewDirectionLeftToRight;
    
    // Create the main scroll view
    self.scrollView                                 = [[UIScrollView alloc] initWithFrame:CGRectZero];
    self.scrollView.pagingEnabled                   = YES;
    self.scrollView.showsHorizontalScrollIndicator  = NO;
    self.scrollView.showsVerticalScrollIndicator    = NO;
    self.scrollView.bouncesZoom                     = NO;
    if (@available(iOS 11.0, *)) {
        self.scrollView.contentInsetAdjustmentBehavior  = UIScrollViewContentInsetAdjustmentNever;
    }
    [self addSubview:self.scrollView];
    
    // Create an observer to monitor when the scroll view offset changes or if a parent controller tries to change
    [self.scrollView addObserver:self forKeyPath:@"contentOffset" options:NSKeyValueObservingOptionNew context:NULL];
    [self.scrollView addObserver:self forKeyPath:@"contentInset" options:NSKeyValueObservingOptionNew context:NULL];
}

- (void)dealloc
{
    [self cleanup];
}

- (void)cleanup
{
    //remove any currently visible pages from the view
    for (NSNumber *pageIndex in self.visiblePageViews.allKeys) {
        [self.visiblePageViews[pageIndex] removeFromSuperview];
    }

    //clean up the page stores
    self.visiblePageViews     = nil;
    self.recycledPageSets = nil;
    
    //remove the scroll view observer
    [self.scrollView removeObserver:self forKeyPath:@"contentOffset"];
    [self.scrollView removeObserver:self forKeyPath:@"contentInset"];
}

- (void)registerPageViewClass:(Class)pageViewClass
{
    NSString *identifier = kTOPagerViewDefaultPageIdentifier;
    if ([pageViewClass respondsToSelector:@selector(pageIdentifier)]) {
        identifier = [pageViewClass pageIdentifier];
    }

    NSValue *encodedStruct = [NSValue valueWithBytes:&pageViewClass objCType:@encode(Class)];
    self.pageViewClasses[identifier] = encodedStruct;
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    if (self.window) {
        [self reloadPageScrollView];
    }
}

#pragma mark - System Notification Observation -
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"contentOffset"]) {
        [self layoutPages];
        return;
    }

    if ([keyPath isEqualToString:@"contentInset"]) {
        [self resetScrollViewVerticalContentInset];
        return;
    }
}

#pragma mark - Rendering Set-up and Initialization -
- (void)reloadPageScrollView
{
    if (self.dataSource == nil) {
        return;
    }

    //create the page stores
    if (!self.pageViewClasses)  { self.pageViewClasses= [NSMutableDictionary dictionary]; }
    if (!self.visiblePageViews) { self.visiblePageViews = [NSMutableDictionary dictionary]; }
    if (!self.recycledPageSets) { self.recycledPageSets = [NSMutableDictionary dictionary]; }

    //start getting information from the data source
    self.numberOfPages = 0;
    if (_pageScrollViewFlags.dataSourceNumberOfPages) {
        self.numberOfPages = [self.dataSource numberOfPagesInPagerView:self];
    }

    //configure the scroll view
    self.scrollView.frame = [self frameForScrollView];
    self.scrollView.contentSize = [self contentSizeForScrollView];
    self.scrollView.contentOffset = [self contentOffsetForScrollViewAtIndex:self.scrollIndex];

    //reset the pages
    [self resetPageLayout];
}

#pragma mark - View Sizing and Layout -
- (void)resetScrollViewVerticalContentInset
{
    UIEdgeInsets insets = self.scrollView.contentInset;
    if (insets.top == 0.0f && insets.bottom == 0.0f) { return; }

    insets.top = 0.0f;
    insets.bottom = 0.0f;
    self.scrollView.contentInset = insets;
}

- (CGRect)frameForScrollView
{
    CGRect scrollFrame      = CGRectZero;
    scrollFrame.size.width  = CGRectGetWidth(self.bounds) + self.pageSpacing;
    scrollFrame.size.height = CGRectGetHeight(self.bounds);
    scrollFrame.origin.x    = 0.0f - (self.pageSpacing * 0.5f);
    scrollFrame.origin.y    = 0.0f;
    
    return scrollFrame;
}

- (CGPoint)contentOffsetForScrollViewAtIndex:(NSInteger)index
{
    CGPoint contentOffset = CGPointZero;
    contentOffset.y = 0.0f;
    
    //invert the layout direction for eastern mode
    if (self.pageScrollDirection == TOPagerViewDirectionRightToLeft) {
        contentOffset.x = ((self.scrollView.contentSize.width) - (CGRectGetWidth(self.scrollView.bounds) * (index+1)));
    }
    else {
        contentOffset.x = (CGRectGetWidth(self.scrollView.bounds) * index);
    }

    return contentOffset;
}

- (CGSize)contentSizeForScrollView
{
    CGSize contentSize = CGSizeZero;
    contentSize.height = CGRectGetHeight(self.bounds);
    contentSize.width  = self.numberOfPageSlots * (CGRectGetWidth(self.bounds) + self.pageSpacing);
    return contentSize;
}

- (CGRect)frameForViewAtIndex:(NSInteger)index
{
    CGFloat scrollViewWidth = CGRectGetWidth(self.scrollView.bounds);
    
    CGRect pageFrame = CGRectZero;
    pageFrame.size.height   = CGRectGetHeight(self.scrollView.bounds);
    pageFrame.size.width    = scrollViewWidth - self.pageSpacing;
    
    pageFrame.origin        = [self contentOffsetForScrollViewAtIndex:index];
    pageFrame.origin.x      += (self.pageSpacing * 0.5f);

    return pageFrame;
}

- (void)resetPageLayout
{
    // Remove all pages from the hierarchy so they can be recalculated from scratch again
    [self.visiblePageViews enumerateKeysAndObjectsUsingBlock: ^(NSNumber *key, UIView *page, BOOL *stop) {
        [page removeFromSuperview];
        [[self recycledPagesSetForPage:page] addObject:page];
    }];
    [self.visiblePageViews removeAllObjects];

    // Remove all accessory views
    [self.leadingAccessoryView removeFromSuperview];
    [self.trailingAccessoryView removeFromSuperview];

    // Perform relayout calculation
    [self layoutPages];

    // Inform the delegate on first run
    if (_pageScrollViewFlags.delegateDidTurnToIndex) {
        [self.delegate pagerView:self didTurnToPageAtIndex:self.pageIndex];
    }
}

- (void)layoutPages
{
    if (self.disablePageLayout || self.numberOfPages == 0) {
        return;
    }

    //-------------------------------------------------------------------
    
    //Determine which pages are currently visible on screen
    CGPoint contentOffset       = self.scrollView.contentOffset;
    CGFloat scrollViewWidth     = self.scrollView.bounds.size.width;
    
    //Work out the number of slots the scroll view has (eg, pages + accessories)
    NSInteger numberOfPageSlots = self.numberOfPageSlots;
    
    //Determine the origin page on the far left
    NSRange visiblePagesRange   = NSMakeRange(0, 1);
    visiblePagesRange.location  = MAX(0, floor(contentOffset.x / scrollViewWidth));
    
    //Based on the delta between the offset of that page from the current offset, determine if the page after it is visible
    CGFloat pageOffsetDelta     = contentOffset.x - (visiblePagesRange.location * scrollViewWidth);
    visiblePagesRange.length    = fabs(pageOffsetDelta) > (self.pageSpacing * 0.5f) ? 2 : 1;
    
    //cap the values to ensure we don't go past the absolute bounds
    visiblePagesRange.location  = MAX(visiblePagesRange.location, 0);
    visiblePagesRange.location  = MIN(visiblePagesRange.location, numberOfPageSlots-1);
    
    visiblePagesRange.length    = contentOffset.x < 0.0f + FLT_EPSILON ? 1 : visiblePagesRange.length;
    visiblePagesRange.length    = (visiblePagesRange.location == numberOfPageSlots-1) ? 1 : visiblePagesRange.length;

    //Capture the current index we're on
    NSInteger oldPageIndex = self.pageIndex;

    //Work out at which index we are scrolled to (Whichever one is overlapping the middle
    self.scrollIndex = floor((self.scrollView.contentOffset.x + (scrollViewWidth * 0.5f)) / scrollViewWidth);
    self.scrollIndex = MIN(self.scrollIndex, numberOfPageSlots-1);
    self.scrollIndex = MAX(self.scrollIndex, 0);

    //if we're in reversed mode, swap the origin
    if (self.pageScrollDirection == TOPagerViewDirectionRightToLeft) {
        visiblePagesRange.location = (numberOfPageSlots - 1) - visiblePagesRange.location - (visiblePagesRange.length > 1 ? visiblePagesRange.length - 1 : 0);
        self.scrollIndex = (numberOfPageSlots - 1) - self.scrollIndex;
    }

    // Check if the page index has changed now, and if it has, inform the delegate
    NSInteger newPageIndex = self.pageIndex;
    if (oldPageIndex != newPageIndex && _pageScrollViewFlags.delegateDidTurnToIndex) {
        [self.delegate pagerView:self didTurnToPageAtIndex:newPageIndex];
    }

    //-------------------------------------------------------------------
    
    //work out if any visible pages need to be removed, and remove as necessary
    __block NSInteger visiblePagesCount = 0;
    NSSet *keysToRemove = [self.visiblePageViews keysOfEntriesWithOptions:0 passingTest:^BOOL (NSNumber *pageNumber, UIView *page, BOOL *stop) {
        if ([pageNumber isKindOfClass:[NSNumber class]] == NO) { return NO; }
        if (NSLocationInRange(pageNumber.unsignedIntegerValue, visiblePagesRange) == NO)
        {
            //move the page back into the recycle pool
            UIView *page = (UIView *)self.visiblePageViews[pageNumber];
            //give it a chance to clear itself before we remove it
            if ([page respondsToSelector:@selector(prepareForReuse)]) {
                [page performSelector:@selector(prepareForReuse)];
            }
            NSMutableSet *recycledPagesSet = [self recycledPagesSetForPage:page];
            [recycledPagesSet addObject:page];
            [page removeFromSuperview];
            
            return YES;
        }
        
        visiblePagesCount++;
        return NO;
    }];
    [self.visiblePageViews removeObjectsForKeys:[keysToRemove allObjects]];
    
    //if there are any accessory views, work out if they need to be removed
    //remove either headerFooter view
    if (self.headerFooterView.superview) {
        if (visiblePagesRange.location > 0 && (NSMaxRange(visiblePagesRange)-1) < numberOfPageSlots-1) {
            [self.headerFooterView removeFromSuperview];
        }
        else {
            visiblePagesCount++;
        }
    }
    
    //remove header view if necessary
    if (self.headerView.superview) {
        if (visiblePagesRange.location > 0) {
            [self.headerView removeFromSuperview];
        }
        else {
            visiblePagesCount++;
        }
    }

    //remove footer view if necessary
    if (self.footerView.superview)
    {
        if ((NSMaxRange(visiblePagesRange)-1) < numberOfPageSlots-1) {
            [self.footerView removeFromSuperview];
        }
        else {
            visiblePagesCount++;
        }
    }
    
    //-------------------------------------------------------------------
    
    //if the number of visible pages is what we were expecting, there's no need to continue
    if (visiblePagesCount == visiblePagesRange.length)
        return;
    
    //go through and insert all new pages necessary
    for (NSInteger i = visiblePagesRange.location; i < NSMaxRange(visiblePagesRange); i++) {
        [self layoutViewAtScrollIndex:i];
    }
}

- (void)layoutViewAtScrollIndex:(NSInteger)scrollIndex
{
    NSInteger numberOfPageSlots = self.numberOfPageSlots;
    scrollIndex = MAX(0, scrollIndex);
    scrollIndex = MIN(numberOfPageSlots, scrollIndex);
    
    //add the header view
    UIView *headerView = self.leadingAccessoryView;
    if (headerView && scrollIndex == 0) {
        if (headerView.superview == nil) {
            //configure frame to match
            headerView.frame    = [self frameForViewAtIndex:0];
            headerView.tag      = 0;
            
            //inform the delegate in case it needs to update itself
            if (_pageScrollViewFlags.delegateWillInsertHeader) {
                [self.delegate pagerView:self willInsertHeaderView:headerView];
            }

            [self.scrollView addSubview:headerView];
        }
        
        return;
    }
    
    UIView *footerView = self.trailingAccessoryView;
    if (footerView && scrollIndex >= numberOfPageSlots-1) { //add the footer view
        if (footerView.superview == nil) {
            //configure frame to match
            footerView.frame    = [self frameForViewAtIndex:numberOfPageSlots-1];
            footerView.tag      = numberOfPageSlots-1;
            
            //inform the delegate in case it needs to update itself
            if (_pageScrollViewFlags.delegateWillInsertFooter) {
                [self.delegate pagerView:self willInsertFooterView:footerView];
            }

            [self.scrollView addSubview:footerView];
        }
        
        return;
    }
    
    //add as a page
    if ([self.visiblePageViews objectForKey:@(scrollIndex)]) {
        return;
    }
    
    UIView *page = nil;
    NSInteger publicIndex = self.leadingAccessoryView ? scrollIndex - 1 : scrollIndex;
    if (_pageScrollViewFlags.dataSourcePageForIndex) {
        page = [self.dataSource pagerView:self pageViewForIndex:publicIndex];
    }
    if (page == nil) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Page from data source cannot be nil!" userInfo:nil];
    }

    page.frame = [self frameForViewAtIndex:scrollIndex];
    [self.scrollView addSubview:page];
    [self.visiblePageViews setObject:page forKey:@(scrollIndex)];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    //exit out if there's no content to display
    if (self.numberOfPages == 0) { return; }

    //disable the layout code since we'll be manually doing it here
    self.disablePageLayout = YES;
    
    //re-align the scroll view to our new bounds
    self.scrollView.frame           = [self frameForScrollView];
    self.scrollView.contentSize     = [self contentSizeForScrollView];
    self.scrollView.contentOffset   = [self contentOffsetForScrollViewAtIndex:self.scrollIndex];
    
    //resize any visible pages
    [self.visiblePageViews enumerateKeysAndObjectsUsingBlock:^(NSNumber *pageNumber, UIView *page, BOOL *stop) {
        page.frame = [self frameForViewAtIndex:pageNumber.unsignedIntegerValue];
    }];
    
    //place the header/footer views
    if (self.headerFooterView.superview) {
        self.headerFooterView.frame = [self frameForViewAtIndex:self.headerFooterView.tag];
    }

    //place the header view
    if (self.headerView) {
        self.headerView.frame = [self frameForViewAtIndex:self.headerView.tag];
    }

    //place the footer view
    if (self.footerView) {
        self.footerView.frame = [self frameForViewAtIndex:self.footerView.tag];
    }

    //re-enable the layout code
    self.disablePageLayout = NO;
}

#pragma mark - Page Recycling -
- (UIView *)dequeueReusablePageView
{
    return [self dequeueReusablePageViewForIdentifier:kTOPagerViewDefaultPageIdentifier];
}

- (UIView *)dequeueReusablePageViewForIdentifier:(NSString *)identifier
{
    NSMutableSet *recycledPagesSet = self.recycledPageSets[identifier];
    UIView *pageView = recycledPagesSet.anyObject;

    if (pageView) {
        pageView.frame = self.bounds;
        [recycledPagesSet removeObject:pageView];
    }
    else if (self.pageViewClasses[identifier]) {
        Class pageClass;
        [self.pageViewClasses[identifier] getValue:&pageClass];
        pageView = [[pageClass alloc] initWithFrame:self.bounds];
    }

    return pageView;
}

- (NSMutableSet *)recycledPagesSetForPage:(UIView *)pageView
{
    // See if the page implemented an identifier, but defer to the default if not
    NSString *identifier = kTOPagerViewDefaultPageIdentifier;
    if ([[pageView class] respondsToSelector:@selector(pageIdentifier)]) {
        identifier = [[pageView class] pageIdentifier];
    }

    // See if a set object already exists for that identifier. Create a new one if not
    NSMutableSet *set = self.recycledPageSets[identifier];
    if (set == nil) {
        set = [NSMutableSet set];
        self.recycledPageSets[identifier] = set;
    }

    return set;
}

- (UIView *)visibleView
{
    // If it's an accessory view, return it
    UIView *page = self.leadingAccessoryView;
    if (page && self.scrollIndex == 0) {
        return page;
    }

    page = self.trailingAccessoryView;
    if (page && self.scrollIndex >= self.numberOfPageSlots-1) {
        return page;
    }

    //if it's a standard page, return it
    page = [self.visiblePageViews objectForKey:@(self.scrollIndex)];
    if (page) {
        return page;
    }

    return nil;
}

- (UIView *)visiblePageView
{
    return [self pageViewForIndex:self.pageIndex];
}

- (UIView *)pageViewForIndex:(NSInteger)pageIndex
{
    // Skip leading accessory view
    if (self.leadingAccessoryView && pageIndex == 0) {
        return nil;
    }

    // Skip trailing accessory view
    if (self.trailingAccessoryView && pageIndex >= self.numberOfPageSlots-1) {
        return nil;
    }

    // Return page
    UIView *page = [self.visiblePageViews objectForKey:@(pageIndex)];
    return page;
}

#pragma mark - Page Navigation -
- (BOOL)canGoBack
{
    return self.scrollIndex > 0;
}

- (BOOL)canGoForward
{
    return self.scrollIndex < self.numberOfPageSlots-1;
}

- (void)turnToNextPageAnimated:(BOOL)animated
{
    if ([self canGoForward] == NO) {
        return;
    }
    
    NSInteger index = self.scrollIndex;
    if (self.leadingAccessoryView) {
        index--;
    }
    
    [self turnToPageAtIndex:index+1 animated:YES];
}

- (void)turnToPreviousPageAnimated:(BOOL)animated
{
    if ([self canGoBack] == NO) {
        return;
    }
    
    NSInteger index = self.scrollIndex;
    if (self.leadingAccessoryView) {
        index--;
    }
    
    [self turnToPageAtIndex:index-1 animated:YES];
}

- (void)turnToPageAtIndex:(NSInteger)index animated:(BOOL)animated
{
    //verify index is valid (Still in page space and not scroll space)
    if (self.leadingAccessoryView) {
        index = MAX(-1, index);
    }
    else {
        index = MAX(0, index);
    }

    if (self.trailingAccessoryView) {
        index = MIN(self.numberOfPages, index);
    }
    else {
        index = MIN(self.numberOfPages-1, index);
    }
    
    //convert to scroll space
    if (self.leadingAccessoryView) {
        index++;
    }

    // Inform the delegate
    if (_pageScrollViewFlags.delegateWillJumpToIndex) {
        [self.delegate pagerView:self willJumpToPageAtIndex:index];
    }

    // If not animated, just change the offset and relayout
    if (animated == NO) {
        self.scrollView.contentOffset = [self contentOffsetForScrollViewAtIndex:index];
        [self layoutPages];
        return;
    }

    // Kill any existing animations
    [self.scrollView.layer removeAllAnimations];

    // Re-enable layouts after the animation has been killed so we can update the current state
    self.disablePageLayout = NO;
    [self layoutPages];

    // Before animating, disable page layout (We'll manually handle placement from here)
    self.disablePageLayout = YES;

    // If we're turning more than one page away, move the current page right up
    // to the side of the target page so we can have a seamless jump animation
    if (labs(index - self.scrollIndex) > 1) {
        UIView *page = [self visibleView];

        NSInteger newIndex = 0;
        if (index > self.scrollIndex) {
            newIndex = index - 1;
        }
        else {
            newIndex = index + 1;
        }

        //jump to the position just before
        [UIView performWithoutAnimation:^{
            page.frame = [self frameForViewAtIndex:newIndex];
            self.scrollView.contentOffset = [self contentOffsetForScrollViewAtIndex:newIndex];
        }];
    }

    // Update the scroll index to match the new value
    self.scrollIndex = index;

    // Layout the target cell
    [self layoutViewAtScrollIndex:index];

    // Trigger the did move to page index delegate
    if (_pageScrollViewFlags.delegateDidTurnToIndex) {
        [self.delegate pagerView:self didTurnToPageAtIndex:self.pageIndex];
    }

    // Set up the animation block
    id animationBlock = ^{
        self.scrollView.contentOffset = [self contentOffsetForScrollViewAtIndex:index];
    };

    // Set up the completion block
    id completionBlock = ^(BOOL complete) {
        // Don't relayout if we intentionally killed the animation
        if (complete == NO) { return; }

        //re-enable the page layout and perform a refresh
        self.disablePageLayout = NO;
        [self layoutPages];

        // Inform the scroll view delegate (if there is one) that the scrolling animation completed
        if (self.scrollView.delegate && [self.scrollView.delegate respondsToSelector:@selector(scrollViewDidEndScrollingAnimation:)]) {
            [self.scrollView.delegate scrollViewDidEndScrollingAnimation:self.scrollView];
        }
    };

    // Perform the animation
    [UIView animateWithDuration:0.35f
                          delay:0.0f
         usingSpringWithDamping:1.0f
          initialSpringVelocity:0.3f
                        options:UIViewAnimationOptionAllowUserInteraction
                     animations:animationBlock
                     completion:completionBlock];
}

#pragma mark - Accessor Methods -
- (NSInteger)pageIndex
{
    NSInteger pageIndex = self.scrollIndex;
    
    //subtract by one to remove the header
    if (self.leadingAccessoryView && pageIndex > 0) {
        pageIndex--;
    }
    
    //cap to the maximum number of pages (which will remove the footer)
    if (pageIndex >= self.numberOfPages) {
        pageIndex = self.numberOfPages - 1;
    }

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
    _pageScrollViewFlags.delegateDidTurnToIndex     = [_delegate respondsToSelector:@selector(pagerView:didTurnToPageAtIndex:)];
}

- (void)setDataSource:(id<TOPagerViewDataSource>)dataSource
{
    _dataSource = dataSource;
    
    _pageScrollViewFlags.dataSourceNumberOfPages    = [_dataSource respondsToSelector:@selector(numberOfPagesInPagerView:)];
    _pageScrollViewFlags.dataSourcePageForIndex     = [_dataSource respondsToSelector:@selector(pagerView:pageViewForIndex:)];
}

- (void)setHeaderFooterView:(UIView *)headerFooterView
{
    if (_headerFooterView == headerFooterView) { return; }
    _headerFooterView = headerFooterView;
    [self reloadPageScrollView];
}

- (void)setHeaderView:(UIView *)headerView
{
    if (_headerView == headerView) { return; }
    _headerView = headerView;
    [self reloadPageScrollView];
}

- (void)setFooterView:(UIView *)footerView
{
    if (_footerView == footerView) { return; }
    _footerView = footerView;
    [self reloadPageScrollView];
}

- (NSArray *)visiblePages
{
    return self.visiblePageViews.allValues;
}

#pragma mark - Internal Accessors -
- (NSInteger)numberOfPageSlots
{
    return self.numberOfPages + (self.leadingAccessoryView ? 1 : 0) + (self.trailingAccessoryView ? 1 : 0);
}

- (UIView *)leadingAccessoryView
{
    return (self.headerFooterView ? self.headerFooterView : (self.headerView ? self.headerView : nil));
}

- (UIView *)trailingAccessoryView
{
    return (self.headerFooterView ? self.headerFooterView : (self.footerView ? self.footerView : nil));
}

@end
