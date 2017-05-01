# TOPagerView
> A `UIScrollView` subclass that allows paged horizontal swiping with a re-use mechansim similar to `UITableView`.

<p align="center">
<img src="https://raw.githubusercontent.com/timoliver/TOPagerView/master/screenshot.jpg" style="margin:0 auto" />
</p>

Originally developed in a time period where `UICollectionView` wasn't 100% feasible yet, `TOPagerView` is a view to streamline rendering fullscreen 'pages' of content in a horizontal layout, similar to the slideshow view in Photos.app.

It is built on the same architectural principles as `UITableView`, where a pool of page views are continually recycled via a delegate object as pages scroll on and off the screen.

In this day and age, it's definitely recommended to use `UICollectionView` instead of custom classes like this one, but there *may* still be cases where this sort of view might have value.

# Features
* Displays child views as full-screen pages that can be swiped left or right.
* The ascending page direction can be changed from left-to-right, to right-to-left as needed.
* Header and Footer accessory views can also be added as needed.
* Provides APIs to randomly jump to specific page numbers.
* The automatic page turning animation can be cancelled in response to user events to allow extremely fast navigation.

# Requirements
iOS 5.0 and above

# Installation
## Manually
Drag the folder `TOPagerView` into your Xcode project. Make sure `Copy Items if Needed` is checked to ensure a copy is imported into your Xcode project folder properly.

## CocoaPods
[CocoaPods](http://cocoapods.org) is a dependency manager that makes it simple to import and manage third party libraries in your projects.

Add the following to your `Podfile`:
```
pod 'TOPageView'
```

## Usage
`TOPagerView` behaves very similarly to `UITableView`. You can pre-register classes, or create new instances on demand.

You add `TOPagerView` to a view controller like most other views:

```objc
    self.pagerView = [[TOPagerView alloc] initWithFrame:self.view.bounds];
    self.pagerView.scrollView.delegate = self; // The internal scroll view delegate can be publicly accessed if needed
    self.pagerView.dataSource  = self;
    self.pagerView.delegate    = self;
    [self.view addSubview:self.pagerView];
```

By default, displaying content is extremely straightforward. It's not even necessary to subclass `UIView`: 

```objc
- (NSInteger)numberOfPagesInPagerView:(TOPagerView *)pageScrollView
{
    return 8;
}

- (UIView *)pagerView:(TOPagerView *)pagerView pageViewForIndex:(NSInteger)pageIndex
{
    UIView *view = [pagerView dequeueReusablePageView];
    if (view == nil) {
        view = [[UIView alloc] init];
        view.backgroundColor = [UIColor whiteColor];
    }

    // Configure the view further
    
    return view;
}
```

If you want to display separate types of views in a single pager view, you can optionally add a string identifier in order to distinguish page views:

```objc
@interface MyView : UIView<TOPagerViewPageProtocol>
@end

@implmentation MyView

+ (NSString *)pageIdentifier
{
   return @"MyViewIdentifier";
}

@end

// ---

@implementation MyViewController

- (UIView *)pagerView:(TOPagerView *)pagerView pageViewForIndex:(NSInteger)pageIndex
{
    MyView *view = (MyView *)[pagerView dequeueReusablePageViewForIdentifier:[MyView pageIdentifier]];
    if (view == nil) {
        view = [[MyView alloc] init];
        view.backgroundColor = [UIColor whiteColor];
    }

    // Configure the view further
    
    return view;
}

@end

```

# Why Build This?

I started writing this library in 2013 (On my 27th birthday apparently!) as a replacement for the pager view I originally wrote in 2011 for [iComics](http://icomics.co).

I wrote the original pager during the era of iOS 5, before `UICollectionView` was announced in 2012. I was still VERY new to iOS development in that time, and as such, the architecture of the original pager is 'not great'. Functional, but definitely not subscribing to the proper MVC architectural model.

In 2013, I was still gung-ho on supporting the original iPad (running iOS 5) so I wanted to avoid using `UICollectionView` as much possible. As such, I wrote this library as an eventual replacement, greatly cleaning up the design in the process.

It's now 2017, and we've long since reached the point where the original iPad and its immediate successors are long dead, and rolling your own `UIScrollView` subclass instead of taking advantage of `UICollectionView` is extremely questionable.

As such, I'm releasing this code more as an educational piece, more than something that should be used in production, but you're more than welcome to use it in your apps if you wish! :)

# License

This library is licensed under the MIT license. Please see [LICENSE] for more details.

# Credits
`TOPagerView` was created by [Tim Oliver](http://twitter.com/TimOliverAU) as a component for iComics.