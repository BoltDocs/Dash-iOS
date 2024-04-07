project 'Dash/Dash iOS.xcodeproj'
platform :ios, "11.0"
inhibit_all_warnings!

target "Dash" do
    pod 'MRProgress', :path => 'Modified Pods/MRProgress/MRProgress.podspec'
    # Commented out a bunch of stuff in MRBlurView's redraw, otherwise the overlay progress makes the entire screen flicker when it is first shown
    # MRStopButton has support for whole sizes (their calculations ended up with non-integral frames)
    # Also overwrote pointInside: for MRCircularProgressView...
    # Removed AccessibilityValueChangeNotify because it causes VoiceOver to stall
    pod 'KissXML', :path => 'Modified Pods/KissXML-5.1.2/KissXML.podspec'
    # Modified to make addChild: remove parent
    pod 'UIAlertView+Blocks'
    pod 'AutoCoding'
    pod 'DZNEmptyDataSet', :git => 'https://github.com/benrudhart/DZNEmptyDataSet.git'
    pod 'JGMethodSwizzler'

    pod 'NSTimer-Blocks'
end

post_install do | installer |
    require 'fileutils'
    FileUtils.cp_r('Pods/Target Support Files/Pods-Dash/Pods-Dash-acknowledgements.plist', 'Dash/Settings.bundle/Cocoa_Pods_Acknowledgements.plist', :remove_destination => true)
end
