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

#import <UIKit/UIKit.h>

@class DHSearchResultsController;

@protocol DHSearchResultsControllerDelegate <NSObject>

@optional
- (void)searchResultsController:(DHSearchResultsController *)controller didLoadSearchResultsTableView:(UITableView *)tableView;
- (void)searchResultsController:(DHSearchResultsController *)controller willShowSearchResultsTableView:(UITableView *)tableView;
- (void)searchResultsController:(DHSearchResultsController *)controller willHideSearchResultsTableView:(UITableView *)tableView;

@end

@interface DHSearchResultsController : UIViewController

@property (strong) UITableView *searchResultsTableView;
@property (weak) id<DHSearchResultsControllerDelegate>delegate;

@end
