//
//  Copyright (C) 2024  Bolt Contributors
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//


#import "DHSearchResultsController.h"

@interface DHSearchResultsController ()

@end

@implementation DHSearchResultsController

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
        _searchResultsTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.searchResultsTableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.searchResultsTableView];
    
    [self.view.topAnchor constraintEqualToAnchor:self.searchResultsTableView.topAnchor].active = YES;
    [self.view.bottomAnchor constraintEqualToAnchor:self.searchResultsTableView.bottomAnchor].active = YES;
    [self.view.leadingAnchor constraintEqualToAnchor:self.searchResultsTableView.leadingAnchor].active = YES;
    [self.view.trailingAnchor constraintEqualToAnchor:self.searchResultsTableView.trailingAnchor].active = YES;
    
    if ([self.delegate respondsToSelector:@selector(searchResultsController:didLoadSearchResultsTableView:)]) {
        [self.delegate searchResultsController:self didLoadSearchResultsTableView:self.searchResultsTableView];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if ([self.delegate respondsToSelector:@selector(searchResultsController:willShowSearchResultsTableView:)]) {
        [self.delegate searchResultsController:self willShowSearchResultsTableView:self.searchResultsTableView];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if ([self.delegate respondsToSelector:@selector(searchResultsController:willHideSearchResultsTableView:)]) {
        [self.delegate searchResultsController:self willHideSearchResultsTableView:self.searchResultsTableView];
    }
}

@end
