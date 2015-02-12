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

#import "AIQDataStore.h"
#import "AIQError.h"
#import "AIQHomeViewController.h"
#import "AIQLog.h"
#import "AIQSynchronization.h"

@interface AIQHomeViewController () <UIAlertViewDelegate> {
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
    self.navigationController.toolbarHidden = NO;
    
    self.navigationItem.title = self.session[kAIQUserInfo][kAIQUserFullName];
    self.navigationItem.hidesBackButton = YES;

    _dataStore = [_session dataStoreForSolution:AIQGlobalSolution];
    _synchronization = [_session synchronization];
    
    [_dataStore documentsOfType:@"todo.model.TODO" processor:^(NSDictionary *document, NSError *__autoreleasing *error) {
        NSUInteger index = [self indexOfNewDocumentWithTitle:document[@"title"]];
        [_documents insertObject:document atIndex:index];
    } failure:^(NSError *error) {
        AIQLogError(@"Did fail to retrieve trains: %@", error.localizedDescription);
    }];

    [_center addObserver:self selector:@selector(logout:) name:AIQDidCloseSessionNotification object:nil];
    [_center addObserver:self selector:@selector(didCreateDocument:) name:AIQDidCreateDocumentNotification object:nil];
    [_center addObserver:self selector:@selector(didUpdateDocument:) name:AIQDidUpdateDocumentNotification object:nil];
    [_center addObserver:self selector:@selector(didDeleteDocument:) name:AIQDidDeleteDocumentNotification object:nil];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _documents.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
    
    NSDictionary *document = _documents[indexPath.row];
    NSString *title = document[@"title"];
    
    NSMutableAttributedString *attributed = [[NSMutableAttributedString alloc] initWithString:title];
    if ([document[@"completed"] boolValue]) {
        [attributed addAttribute:NSStrikethroughStyleAttributeName value:@2 range:NSMakeRange(0, title.length)];
    }
    cell.textLabel.attributedText = attributed;
    
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return @"TODOs";
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSMutableDictionary *document = [_documents[indexPath.row] mutableCopy];
    document[@"completed"] = @(![document[@"completed"] boolValue]);
    [_documents replaceObjectAtIndex:indexPath.row withObject:document];
    
    [_dataStore updateFields:document ofDocumentWithId:document[kAIQDocumentId] success:^(NSDictionary *document) {
        [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    } failure:^(NSError *error) {
        [self displayError:error];
    }];
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 1) {
        NSString *title = [[alertView textFieldAtIndex:0].text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (title.length == 0) {
            AIQLogWarn(@"No field value to store");
            return;
        }
        
        AIQLogInfo(@"Creating document with field value %@", title);
        [_dataStore createDocument:@{@"title": title} ofType:@"todo.model.TODO" success:^(NSDictionary *document) {
            NSUInteger index = [self indexOfNewDocumentWithTitle:title];
            [_documents insertObject:document atIndex:index];
            [self.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:index inSection:0]]
                                  withRowAnimation:UITableViewRowAnimationAutomatic];
        } failure:^(NSError *error) {
            [self displayError:error];
            
        }];
    }
}

#pragma mark - Private API

- (void)displayError:(NSError *)error {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                    message:error.localizedDescription
                                                   delegate:nil
                                          cancelButtonTitle:@"Dismiss"
                                          otherButtonTitles:nil];
    [alert show];
}

- (IBAction)logout:(id)sender {
    [_center removeObserver:self];

    [_session close:^{
        [self.navigationController popViewControllerAnimated:YES];
    } failure:^(NSError *error) {
        [self displayError:error];
    }];
}

- (IBAction)add:(id)sender {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Alert"
                                                    message:@"Enter text"
                                                   delegate:self
                                          cancelButtonTitle:@"Cancel"
                                          otherButtonTitles:@"Add", nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    [alert textFieldAtIndex:0].placeholder = @"Field value";
    [alert show];
}

- (IBAction)clear:(id)sender {
    NSMutableArray *indexPaths = [NSMutableArray array];
    for (NSDictionary *document in _documents) {
        if ([document[@"completed"] boolValue]) {
            NSString *identifier = document[kAIQDocumentId];
            [_dataStore deleteDocumentWithId:identifier success:^() {
                [indexPaths addObject:[NSIndexPath indexPathForRow:[self indexOfExistingDocumentWithId:identifier] inSection:0]];
            } failure:^(NSError *error) {
                AIQLogError(@"Did fail to delete document: %@", error.localizedDescription);
            }];
        }
    }
    
    for (NSInteger index = indexPaths.count - 1; index >= 0; index--) {
        [_documents removeObjectAtIndex:[indexPaths[index] row]];
    }
    
    [self.tableView deleteRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationAutomatic];
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
        ([notification.userInfo[AIQDocumentTypeUserInfoKey] isEqualToString:@"todo.model.TODO"])) {
        NSString *identifier = notification.userInfo[AIQDocumentIdUserInfoKey];
        [_dataStore documentWithId:identifier success:^(NSDictionary *document) {
            NSUInteger index = [self indexOfNewDocumentWithTitle:document[@"title"]];
            [_documents insertObject:document atIndex:index];
            [self.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:index inSection:0]]
                                  withRowAnimation:UITableViewRowAnimationAutomatic];
        } failure:^(NSError *error) {
            AIQLogError(@"Did fail to retrieve document %@: %@", identifier, error.localizedDescription);
        }];
    }
}

- (void)didUpdateDocument:(NSNotification *)notification {
    if (([notification.userInfo[AIQSolutionUserInfoKey] isEqualToString:AIQGlobalSolution]) &&
        ([notification.userInfo[AIQDocumentTypeUserInfoKey] isEqualToString:@"todo.model.TODO"])) {
        NSString *identifier = notification.userInfo[AIQDocumentIdUserInfoKey];
        [_dataStore documentWithId:identifier success:^(NSDictionary *document) {
            NSUInteger index = [self indexOfExistingDocumentWithTitle:document[@"title"]];
            [_documents replaceObjectAtIndex:index withObject:document];
            [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:index inSection:0]]
                                  withRowAnimation:UITableViewRowAnimationAutomatic];
        } failure:^(NSError *error) {
            AIQLogError(@"Did fail to retrieve document %@: %@", identifier, error.localizedDescription);
        }];
    }
}

- (void)didDeleteDocument:(NSNotification *)notification {
    if (([notification.userInfo[AIQSolutionUserInfoKey] isEqualToString:AIQGlobalSolution]) &&
        ([notification.userInfo[AIQDocumentTypeUserInfoKey] isEqualToString:@"todo.model.TODO"])) {
        NSString *identifier = notification.userInfo[AIQDocumentIdUserInfoKey];
        NSUInteger index = [self indexOfExistingDocumentWithId:identifier];
        [_documents removeObjectAtIndex:index];
        [self.tableView deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:index inSection:0]]
                              withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}

- (NSUInteger)indexOfExistingDocumentWithId:(NSString *)identifier {
    for (NSUInteger index = 0; index < _documents.count; index++) {
        NSString *current = _documents[index][kAIQDocumentId];
        if ([current isEqualToString:identifier]) {
            return index;
        }
    }
    return NSNotFound;
}

- (NSUInteger)indexOfExistingDocumentWithTitle:(NSString *)title {
    for (NSUInteger index = 0; index < _documents.count; index++) {
        NSString *current = _documents[index][@"title"];
        if ([current isEqualToString:title]) {
            return index;
        }
    }
    return NSNotFound;
}

- (NSUInteger)indexOfNewDocumentWithTitle:(NSString *)title {
    for (NSUInteger index = 0; index < _documents.count; index++) {
        NSString *current = _documents[index][@"title"];
        if ([current compare:title] == NSOrderedDescending) {
            return index;
        }
    }
    return _documents.count;
}

@end
