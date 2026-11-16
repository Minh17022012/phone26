// Phone26 - tab bar nổi kiểu iOS 26 cho app Điện thoại (MobilePhone)
// 3 tab (Cuộc gọi / Danh bạ / Bàn phím) + nút tìm kiếm tròn tách rời cùng hàng.
#import <UIKit/UIKit.h>

static const CGFloat kBarH       = 64.0;   // chiều cao thanh & đường kính nút tìm kiếm
static const CGFloat kSide       = 18.0;   // lề trái/phải
static const CGFloat kGap        = 10.0;   // khoảng cách giữa thanh và nút tìm kiếm
static const NSInteger kSearchTag  = 26001;
static const NSInteger kEffectTag  = 26002;
static const NSInteger kCapsuleTag = 26003;

@interface UITabBarController (Phone26)
- (void)tw26_search;
@end

#pragma mark - Helpers

static NSString *tw26_name(UIViewController *vc) {
    NSMutableString *s = [NSMutableString stringWithString:NSStringFromClass(vc.class)];
    if ([vc isKindOfClass:UINavigationController.class]) {
        for (UIViewController *c in ((UINavigationController *)vc).viewControllers)
            [s appendString:NSStringFromClass(c.class)];
    }
    return s.lowercaseString;
}

// Bỏ tab Yêu thích & Thư thoại -> còn 3 tab
static NSArray *tw26_filter(NSArray *vcs) {
    if (vcs.count <= 3) return vcs;
    NSMutableArray *out = [NSMutableArray array];
    for (UIViewController *vc in vcs) {
        NSString *n = tw26_name(vc);
        if ([n containsString:@"favorite"] || [n containsString:@"voicemail"]) continue;
        [out addObject:vc];
    }
    return out.count == 3 ? out : vcs;
}

static CGRect tw26_barFrame(UITabBar *bar, CGRect orig) {
    UIView *sv = bar.superview;
    if (!sv || sv.bounds.size.width < 1) return orig;
    CGRect b = sv.bounds;
    CGFloat margin = sv.safeAreaInsets.bottom > 0 ? 18.0 : 12.0;
    CGFloat w = b.size.width - 2 * kSide - kGap - kBarH;
    return CGRectMake(kSide, b.size.height - margin - kBarH, w, kBarH);
}

static UISearchBar *tw26_findSB(UIView *v) {
    if ([v isKindOfClass:UISearchBar.class]) return (UISearchBar *)v;
    for (UIView *s in v.subviews) {
        UISearchBar *r = tw26_findSB(s);
        if (r) return r;
    }
    return nil;
}

static void tw26_style(UITabBar *bar, BOOL animated) {
    CGRect bounds = bar.bounds;
    if (bounds.size.width < 1) return;

    // Nền kính mờ bo tròn
    UIVisualEffectView *ev = (UIVisualEffectView *)[bar viewWithTag:kEffectTag];
    if (!ev) {
        UITabBarAppearance *ap = [UITabBarAppearance new];
        [ap configureWithTransparentBackground];
        bar.standardAppearance = ap;
        bar.scrollEdgeAppearance = ap;

        ev = [[UIVisualEffectView alloc] initWithEffect:
              [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial]];
        ev.tag = kEffectTag;
        ev.userInteractionEnabled = NO;
        ev.clipsToBounds = YES;
        ev.layer.cornerCurve = kCACornerCurveContinuous;
        [bar insertSubview:ev atIndex:0];

        UIView *cap = [UIView new];
        cap.tag = kCapsuleTag;
        cap.userInteractionEnabled = NO;
        cap.backgroundColor = [UIColor tertiarySystemFillColor];
        [bar insertSubview:cap atIndex:1];

        bar.layer.shadowColor = [UIColor blackColor].CGColor;
        bar.layer.shadowOpacity = 0.12;
        bar.layer.shadowRadius = 14;
        bar.layer.shadowOffset = CGSizeMake(0, 4);
    }
    ev.frame = bounds;
    ev.layer.cornerRadius = bounds.size.height / 2.0;
    bar.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:bounds
                                                      cornerRadius:bounds.size.height / 2.0].CGPath;

    // Viên thuốc (capsule) quanh tab đang chọn
    UIView *cap = [bar viewWithTag:kCapsuleTag];
    NSMutableArray<UIView *> *btns = [NSMutableArray array];
    for (UIView *s in bar.subviews)
        if ([NSStringFromClass(s.class) isEqualToString:@"UITabBarButton"]) [btns addObject:s];
    [btns sortUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
        return a.frame.origin.x < b.frame.origin.x ? NSOrderedAscending : NSOrderedDescending;
    }];
    NSUInteger idx = bar.selectedItem ? [bar.items indexOfObject:bar.selectedItem] : NSNotFound;
    if (cap && idx != NSNotFound && idx < btns.count) {
        CGRect f = CGRectInset(btns[idx].frame, 4, 6);
        void (^apply)(void) = ^{
            cap.frame = f;
            cap.layer.cornerRadius = f.size.height / 2.0;
        };
        if (animated && !CGRectIsEmpty(cap.frame)) {
            [UIView animateWithDuration:0.35 delay:0 usingSpringWithDamping:0.8
                  initialSpringVelocity:0.3 options:UIViewAnimationOptionBeginFromCurrentState
                             animations:apply completion:nil];
        } else {
            apply();
        }
        cap.hidden = NO;
    }
}

#pragma mark - Hooks

%hook UITabBar

- (void)setFrame:(CGRect)f {
    %orig(tw26_barFrame(self, f));
}

- (void)layoutSubviews {
    %orig;
    CGRect nf = tw26_barFrame(self, self.frame);
    if (!CGRectEqualToRect(nf, self.frame)) self.frame = nf;
    tw26_style(self, NO);
}

- (void)setSelectedItem:(UITabBarItem *)item {
    %orig;
    tw26_style(self, YES);
}

%end

%hook UITabBarController

- (void)setViewControllers:(NSArray *)vcs animated:(BOOL)animated {
    %orig(tw26_filter(vcs), animated);
}

- (void)setViewControllers:(NSArray *)vcs {
    %orig(tw26_filter(vcs));
}

- (void)viewDidLayoutSubviews {
    %orig;
    UIView *host = self.view;
    UIView *box = [host viewWithTag:kSearchTag];
    if (!box) {
        box = [UIView new];
        box.tag = kSearchTag;
        box.layer.shadowColor = [UIColor blackColor].CGColor;
        box.layer.shadowOpacity = 0.12;
        box.layer.shadowRadius = 14;
        box.layer.shadowOffset = CGSizeMake(0, 4);

        UIVisualEffectView *ev = [[UIVisualEffectView alloc] initWithEffect:
                                  [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial]];
        ev.frame = CGRectMake(0, 0, kBarH, kBarH);
        ev.clipsToBounds = YES;
        ev.layer.cornerRadius = kBarH / 2.0;
        [box addSubview:ev];

        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        UIImageSymbolConfiguration *cfg =
            [UIImageSymbolConfiguration configurationWithPointSize:24 weight:UIImageSymbolWeightMedium];
        [btn setImage:[UIImage systemImageNamed:@"magnifyingglass" withConfiguration:cfg]
             forState:UIControlStateNormal];
        btn.tintColor = [UIColor labelColor];
        btn.frame = CGRectMake(0, 0, kBarH, kBarH);
        [btn addTarget:self action:@selector(tw26_search) forControlEvents:UIControlEventTouchUpInside];
        [ev.contentView addSubview:btn];

        [host addSubview:box];
    }
    CGRect bf = self.tabBar.frame;
    box.frame = CGRectMake(host.bounds.size.width - kSide - kBarH, bf.origin.y, kBarH, kBarH);
    box.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:box.bounds
                                                      cornerRadius:kBarH / 2.0].CGPath;
    [host bringSubviewToFront:box];
}

%new
- (void)tw26_search {
    NSUInteger found = NSNotFound, i = 0;
    for (UIViewController *vc in self.viewControllers) {
        if ([tw26_name(vc) containsString:@"contact"]) { found = i; break; }
        i++;
    }
    if (found == NSNotFound) found = 1;
    self.selectedIndex = found;

    __weak UITabBarController *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        UITabBarController *s = weakSelf;
        UIViewController *vc = s.selectedViewController;
        UIViewController *top = [vc isKindOfClass:UINavigationController.class]
            ? ((UINavigationController *)vc).topViewController : vc;
        UISearchController *sc = top.navigationItem.searchController;
        if (sc) {
            sc.active = YES;
            [sc.searchBar becomeFirstResponder];
            return;
        }
        [tw26_findSB(vc.view) becomeFirstResponder];
    });
}

%end
