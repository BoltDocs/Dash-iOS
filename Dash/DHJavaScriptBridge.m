//
//  Copyright (C) 2016  Kapeli
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

#import "DHJavaScriptBridge.h"
#import "DHWebViewController.h"
#import "DHCSS.h"

@implementation DHJavaScriptBridge

+ (DHJavaScriptBridge *)sharedBridge
{
    static dispatch_once_t pred;
    static DHJavaScriptBridge *_singleton = nil;
    
    dispatch_once(&pred, ^{
        _singleton = [[DHJavaScriptBridge alloc] init];
        _singleton.alertBlock = ^(JSValue *message) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"JavaScript Alert" message:[message toString] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
        };
    });
    return _singleton;
}

- (void)switchAppleLanguage:(JSValue *)nameValue
{
    NSString *name = [nameValue toString];
    name = [name trimWhitespace];
    if(name && name.length)
    {
        [[NSUserDefaults standardUserDefaults] setObject:name forKey:DHActiveAppleLanguageKey];
        [[DHCSS sharedCSS] refreshActiveCSS];
        [[DHWebViewController sharedWebViewController] reload];
    }
}

- (void)newSwitchAppleLanguage:(JSValue *)nameValue
{
    NSString *text = [[nameValue toString] trimWhitespace];
    if([text contains:@"Swift"])
    {
        [DHAppleActiveLanguage setLanguage:DHNewActiveAppleLanguageSwift];
    }
    else if([text contains:@"Objective-C"] || [text contains:@"ObjC"])
    {
        [DHAppleActiveLanguage setLanguage:DHNewActiveAppleLanguageObjC];
    }
}

- (void)unityConsoleLog:(NSString *)message
{
    if([message isKindOfClass:[JSValue class]])
    {
        message = [(JSValue*)message toString];
    }
    if([message isKindOfClass:[NSString class]] && [message isEqualToString:@"selected"])
    {
        NSString *value = [[[DHWebViewController sharedWebViewController] webView] stringByEvaluatingJavaScriptFromString:@"document.getElementsByClassName('cSelect-Selected')[0].innerText"];
        if(value && value.length)
        {
            [[NSUserDefaults standardUserDefaults] setObject:value forKey:@"unitySelectedSnippetLanguage"];
        }
    }
}

- (void)coffeeScriptOpenLink_:(NSString *)string
{
    NSURL *url = [NSURL URLWithString:[@"http://coffeescript.org/" stringByAppendingString:string]];
    if(url)
    {
        [[UIApplication sharedApplication] openURL:url];
    }
}

- (void)showFallbackExplanation
{

}

- (void)loadFallbackURL_:(JSValue *)suppressButtonChecked
{

}

- (void)openDownloads
{

}

- (void)openDocsets
{

}

- (void)openProfiles
{

}

- (void)openGuide
{
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://kapeli.com/dash_guide"]];
}

- (void)openIOSLink
{
    [UIAlertView showWithTitle:@"Dash for iOS" message:@"You're using it!" cancelButtonTitle:@"Okay" otherButtonTitles:nil tapBlock:nil];
}

- (void)webViewDidChangeLocationWithinPage
{
    [[DHWebViewController sharedWebViewController] webViewDidChangeLocationWithinPage];
}

- (void)log:(JSValue *)value
{
    NSLog(@"JS Log: %@", value);
}
@end
