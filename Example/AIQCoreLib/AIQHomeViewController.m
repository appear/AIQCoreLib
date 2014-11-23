#import "AIQDataStore.h"
#import "AIQHomeViewController.h"
#import "AIQLog.h"
#import "AIQSynchronization.h"

@interface AIQHomeViewController () {
    AIQDataStore *_dataStore;
    AIQSynchronization *_synchronization;
    NSMutableArray *_documents;
    NSNotificationCenter *_center;
}

@end

@implementation AIQHomeViewController

- (void)awakeFromNib {
    [super awakeFromNib];

    _documents = [NSMutableArray array];
    _center = [NSNotificationCenter defaultCenter];

}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationController.navigationBarHidden = NO;
    self.navigationItem.title = self.session[kAIQUserInfo][kAIQUserFullName];
    self.navigationItem.hidesBackButton = YES;

    _dataStore = [_session dataStoreForSolution:AIQGlobalSolution];
    _synchronization = [_session synchronization];

    [_dataStore documentsOfType:@"TD.Train" processor:^(NSDictionary *document, NSError *__autoreleasing *error) {
        NSString *identifier = document[kAIQDocumentId];
        NSUInteger index = [self indexOfNewDocumentWithId:identifier];
        [_documents insertObject:@{@"id": identifier, @"number": [NSString stringWithFormat:@"%@", document[@"number"]]} atIndex:index];
    } failure:^(NSError *error) {
        AIQLogError(@"Did fail to retrieve trains: %@", error.localizedDescription);
    }];

    [_center addObserver:self selector:@selector(didCreateDocument:) name:AIQDidCreateDocumentNotification object:nil];
    [_center addObserver:self selector:@selector(didUpdateDocument:) name:AIQDidUpdateDocumentNotification object:nil];
    [_center addObserver:self selector:@selector(didDeleteDocument:) name:AIQDidDeleteDocumentNotification object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    if ([self isMovingFromParentViewController]) {
        [_center removeObserver:self];
    }

    [super viewWillDisappear:animated];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _documents.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
    cell.textLabel.text = _documents[indexPath.row][@"number"];
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return @"TD.Train";
}

#pragma mark - Private API

- (IBAction)logout:(id)sender {
    [_session close:^{
        [self.navigationController popViewControllerAnimated:YES];
    } failure:^(NSError *error) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                        message:error.localizedDescription
                                                       delegate:nil
                                              cancelButtonTitle:@"Dismiss"
                                              otherButtonTitles:nil];
        [alert show];
    }];
}

- (IBAction)synchronize:(id)sender {
    [_synchronization synchronize:^{
        AIQLogInfo(@"Did synchronize");
        [self.refreshControl endRefreshing];
    } failure:^(NSError *error) {
        AIQLogError(@"Did fail to synchronize: %@", error.localizedDescription);
        [self.refreshControl endRefreshing];
    }];
}

- (void)didCreateDocument:(NSNotification *)notification {
    if (([notification.userInfo[AIQSolutionUserInfoKey] isEqualToString:AIQGlobalSolution]) &&
        ([notification.userInfo[AIQDocumentTypeUserInfoKey] isEqualToString:@"TD.Train"])) {
        NSString *identifier = notification.userInfo[AIQDocumentIdUserInfoKey];
        [_dataStore documentWithId:identifier success:^(NSDictionary *document) {
            NSUInteger index = [self indexOfNewDocumentWithId:identifier];
            [_documents insertObject:@{@"id": identifier, @"number": [document[@"number"] description]} atIndex:index];
            [self.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:index inSection:0]]
                                  withRowAnimation:UITableViewRowAnimationAutomatic];
        } failure:^(NSError *error) {
            AIQLogError(@"Did fail to retrieve document %@: %@", identifier, error.localizedDescription);
        }];
    }
}

- (void)didUpdateDocument:(NSNotification *)notification {
    if (([notification.userInfo[AIQSolutionUserInfoKey] isEqualToString:AIQGlobalSolution]) &&
        ([notification.userInfo[AIQDocumentTypeUserInfoKey] isEqualToString:@"TD.Train"])) {
        NSString *identifier = notification.userInfo[AIQDocumentIdUserInfoKey];
        [_dataStore documentWithId:identifier success:^(NSDictionary *document) {
            NSUInteger index = [self indexOfExistingDocumentWithId:identifier];
            [_documents replaceObjectAtIndex:index withObject:@{@"id": identifier, @"number": [document[@"number"] description]}];
            [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:index inSection:0]]
                                  withRowAnimation:UITableViewRowAnimationAutomatic];
        } failure:^(NSError *error) {
            AIQLogError(@"Did fail to retrieve document %@: %@", identifier, error.localizedDescription);
        }];
    }
}

- (void)didDeleteDocument:(NSNotification *)notification {
    if (([notification.userInfo[AIQSolutionUserInfoKey] isEqualToString:AIQGlobalSolution]) &&
        ([notification.userInfo[AIQDocumentTypeUserInfoKey] isEqualToString:@"TD.Train"])) {
        NSString *identifier = notification.userInfo[AIQDocumentIdUserInfoKey];
        NSUInteger index = [self indexOfExistingDocumentWithId:identifier];
        [_documents removeObjectAtIndex:index];
        [self.tableView deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:index inSection:0]]
                              withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}

- (NSUInteger)indexOfExistingDocumentWithId:(NSString *)identifier {
    for (NSUInteger index = 0; index < _documents.count; index++) {
        NSString *current = _documents[index][@"id"];
        if ([current isEqualToString:identifier]) {
            return index;
        }
    }
    return NSNotFound;
}

- (NSUInteger)indexOfNewDocumentWithId:(NSString *)identifier {
    for (NSUInteger index = 0; index < _documents.count; index++) {
        NSString *current = _documents[index][@"id"];
        if ([current compare:identifier] == NSOrderedDescending) {
            return index;
        }
    }
    return _documents.count;
}

@end
