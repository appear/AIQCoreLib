#import "AIQHomeViewController.h"
#import "AIQLog.h"
#import "AIQLoginViewController.h"
#import "AIQSession.h"
#import "DDTTYLogger.h"

#define VersionAtLeast(v)  ([[[UIDevice currentDevice] systemVersion] compare:(v) options:NSNumericSearch] != NSOrderedAscending)

@interface AIQLoginVIewController () {
    IBOutlet UITextField *_usernameField;
    IBOutlet UITextField *_passwordField;
    IBOutlet UITextField *_organizationField;
    IBOutlet UIButton *_loginButton;
    IBOutlet NSLayoutConstraint *_constraint;
    
    AIQSession *_session;
}

@end

@implementation AIQLoginVIewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [AIQLog ddSetLogLevel:LOG_LEVEL_ALL];
    [AIQLog addLogger:[DDTTYLogger sharedInstance]];
    
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
    UIViewAnimationOptions options = [self optionsFromCurve:[notification.userInfo[UIKeyboardAnimationCurveUserInfoKey] unsignedIntegerValue]];
    CGSize size = [[notification.userInfo valueForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue].size;
    if ((UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation)) && (! VersionAtLeast(@"8.0"))) {
        size = CGSizeMake(size.height, size.width);
    }
    
    _constraint.constant = size.height;
    [UIView animateWithDuration:duration delay:0.0 options:options animations:^{
        [self.view layoutIfNeeded];
    } completion:nil];
}

- (void)keyboardWillHide:(NSNotification *)notification {
    NSTimeInterval duration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationOptions options = [self optionsFromCurve:[notification.userInfo[UIKeyboardAnimationCurveUserInfoKey] unsignedIntegerValue]];
    
    _constraint.constant = 0.0;
    [UIView animateWithDuration:duration delay:0.0 options:options animations:^{
        [self.view layoutIfNeeded];
    } completion:nil];
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
