/*
 The MIT License (MIT)

 Copyright (c) 2015 Appear Networks AB

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */

#import "AIQHomeViewController.h"
#import "AIQLog.h"
#import "AIQLoginViewController.h"
#import "AIQSession.h"
#import "DDLog.h"
#import "DDTTYLogger.h"

#define VersionAtLeast(v)  ([[[UIDevice currentDevice] systemVersion] compare:(v) options:NSNumericSearch] != NSOrderedAscending)

@interface AIQLoginViewController () {
    IBOutlet UITextField *_usernameField;
    IBOutlet UITextField *_passwordField;
    IBOutlet UITextField *_organizationField;
    IBOutlet UIButton *_loginButton;
    IBOutlet NSLayoutConstraint *_constraint;
    
    AIQSession *_session;
}

@end

@implementation AIQLoginViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [AIQLog addLogger:[DDTTYLogger sharedInstance]];
    [AIQLog ddSetLogLevel:LOG_LEVEL_ALL];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    
    if ([AIQSession canResume]) {
        NSError *error = nil;
        _session = [AIQSession resume:&error];
        [self performSegueWithIdentifier:@"showHomeView" sender:self];
        if (! _session) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                            message:error.localizedDescription
                                                           delegate:nil
                                                  cancelButtonTitle:@"Dismiss"
                                                  otherButtonTitles:nil];
            [alert show];
        }
    } else {
        _session = [AIQSession sessionWithBaseURL:[NSURL URLWithString:@"https://dev.appeariq.com"]];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self.navigationController setNavigationBarHidden:YES animated:animated];
    [self.navigationController setToolbarHidden:YES animated:animated];
    
    _passwordField.text = nil;
}

- (IBAction)loginOrCancel:(id)sender {
    [_usernameField resignFirstResponder];
    [_passwordField resignFirstResponder];
    [_organizationField resignFirstResponder];
    
    [_session openForUser:_usernameField.text password:_passwordField.text inOrganization:_organizationField.text success:^{
        [self performSegueWithIdentifier:@"showHomeView" sender:self];
    } failure:^(NSError *error) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                        message:error.localizedDescription
                                                       delegate:nil
                                              cancelButtonTitle:@"Dismiss"
                                              otherButtonTitles:nil];
        [alert show];
    }];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    AIQHomeViewController *destination = segue.destinationViewController;
    destination.session = _session;
}

- (void)keyboardWillShow:(NSNotification *)notification {
    NSTimeInterval duration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    CGSize size = [[notification.userInfo valueForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue].size;
    if ((UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation)) && (! VersionAtLeast(@"8.0"))) {
        size = CGSizeMake(size.height, size.width);
    }
    
    _constraint.constant = size.height;
    [UIView animateWithDuration:duration animations:^{
        [self.view layoutIfNeeded];
    }];
}

- (void)keyboardWillHide:(NSNotification *)notification {
    NSTimeInterval duration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    
    _constraint.constant = 0.0;
    [UIView animateWithDuration:duration animations:^{
        [self.view layoutIfNeeded];
    }];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [_usernameField resignFirstResponder];
    [_passwordField resignFirstResponder];
    [_organizationField resignFirstResponder];
}

- (UIViewAnimationOptions)optionsFromCurve:(UIViewAnimationCurve)curve {
    switch (curve) {
        case UIViewAnimationCurveEaseInOut:
            return UIViewAnimationOptionCurveEaseInOut;
        case UIViewAnimationCurveEaseIn:
            return UIViewAnimationOptionCurveEaseIn;
        case UIViewAnimationCurveEaseOut:
            return UIViewAnimationOptionCurveEaseOut;
        case UIViewAnimationCurveLinear:
            return UIViewAnimationOptionCurveLinear;
    }
}

@end
