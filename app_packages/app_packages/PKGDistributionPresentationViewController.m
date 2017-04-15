/*
 Copyright (c) 2017, Stephane Sudre
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 - Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 - Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 - Neither the name of the WhiteBox nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "PKGDistributionPresentationViewController.h"

#import "PKGPresentationWindowView.h"

#import "PKGPresentationListView.h"

#import "PKGPresentationImageView.h"

#import "PKGPresentationPaneTitleView.h"

#import "PKGRightInspectorView.h"

#import "PKGPresentationPluginButton.h"

#import "PKGDistributionProjectPresentationSettings+Safe.h"

#import "PKGPresentationTitleSettings.h"

#import "PKGPresentationSection+UI.h"

#import "PKGPresentationLocalizableStepSettings+UI.h"

#import "PKGPresentationBackgroundSettings+UI.h"

#import "PKGInstallerApp.h"

#import "PKGPresentationInspectorItem.h"

#import "PKGLocalizationUtilities.h"

#import "PKGLanguageConverter.h"

#import "NSAlert+block.h"

#import "NSIndexSet+Analysis.h"

#import "NSFileManager+FileTypes.h"

#import "PKGApplicationPreferences.h"

#import "PKGOwnershipAndReferenceStyleViewController.h"
#import "PKGOwnershipAndReferenceStylePanel.h"



#import "PKGPresentationSectionViewController.h"

#import "PKGPresentationSectionLicenseViewController.h"

@interface PKGDistributionPresentationOpenPanelDelegate : NSObject<NSOpenSavePanelDelegate>
{
	NSFileManager * _fileManager;
}

	@property NSArray * plugInsPaths;

@end

@implementation PKGDistributionPresentationOpenPanelDelegate

- (instancetype)init
{
	self=[super init];
	
	if (self!=nil)
	{
		_fileManager=[NSFileManager defaultManager];
	}
	
	return self;
}

- (BOOL)panel:(NSOpenPanel *)inPanel shouldEnableURL:(NSURL *)inURL
{
	if (inURL.isFileURL==NO)
		return NO;
	
	NSString * tPath=inURL.path;
	
	if ([tPath.pathExtension caseInsensitiveCompare:@"bundle"]==NSOrderedSame)
	{
		if ([self.plugInsPaths indexOfObjectPassingTest:^BOOL(NSString * bPlugInPath,NSUInteger bIndex,BOOL * bOutStop){
			
			return ([bPlugInPath caseInsensitiveCompare:tPath]==NSOrderedSame);
			
		}]!=NSNotFound)
			return NO;
		
		BOOL isDirectory;
		
		[_fileManager fileExistsAtPath:tPath isDirectory:&isDirectory];
		
		if (isDirectory==NO)
			return NO;
		
		NSBundle * tBundle=[NSBundle bundleWithPath:tPath];
		
		return [[tBundle objectForInfoDictionaryKey:@"InstallerSectionTitle"] isKindOfClass:NSString.class];
	}
	
	BOOL isDirectory;
	
	[_fileManager fileExistsAtPath:tPath isDirectory:&isDirectory];
	
	return (isDirectory==YES);
}

@end

NSString * const PKGDistributionPresentationCurrentPreviewLanguage=@"ui.project.presentation.preview.language";

NSString * const PKGDistributionPresentationSelectedStep=@"ui.project.presentation.step.selected";

NSString * const PKGDistributionPresentationInspectedItem=@"ui.project.presentation.item.inspected";

NSString * const PKGDistributionPresentationSectionsInternalPboardType=@"fr.whitebox.packages.internal.distribution.presentation.sections";

@interface PKGDistributionPresentationViewController () <PKGPresentationImageViewDelegate,PKGPresentationListViewDataSource,PKGPresentationListViewDelegate>
{
	IBOutlet PKGPresentationWindowView * _windowView;
	
	IBOutlet PKGPresentationImageView * _backgroundView;
	
	IBOutlet PKGPresentationListView * _listView;
	
	IBOutlet PKGPresentationPaneTitleView * _pageTitleView;
	
	IBOutlet NSView * _sectionContentsView;
	
	IBOutlet NSButton * _printButton;
	
	IBOutlet NSButton * _saveButton;
	
	IBOutlet NSButton * _goBackButton;
	
	IBOutlet NSButton * _continueButton;
	
	
	IBOutlet PKGPresentationPluginButton * _pluginAddButton;
	IBOutlet PKGPresentationPluginButton * _pluginRemoveButton;
	
	IBOutlet NSView * _accessoryPlaceHolderView;
	
	IBOutlet NSPopUpButton * _languagePreviewPopUpButton;
	
	
	IBOutlet PKGRightInspectorView * _rightView;
	
	IBOutlet NSPopUpButton * _inspectorPopUpButton;
	
	
	PKGPresentationSectionViewController * _currentSectionViewController;
	
	
	PKGDistributionPresentationOpenPanelDelegate * _openPanelDelegate;
	
	NSArray * _supportedLocalizations;
	
	NSString * _currentPreviewLanguage;
	
	NSIndexSet * _internalDragData;
	
	NSArray * _navigationButtons;
}

- (void)updateBackgroundView;
- (void)updateTitleViews;

- (IBAction)addPlugin:(id)sender;
- (IBAction)removePlugin:(id)sender;

- (IBAction)switchPreviewLanguage:(NSPopUpButton *)sender;

- (IBAction)switchInspectedView:(id)sender;

- (void)showViewForSection:(PKGPresentationSection *)inPresentationSection;

// Notifications

- (void)windowStateDidChange:(NSNotification *)inNotification;

- (void)selectedLicenseNativeLocalizationDidChange:(NSNotification *)inNotification;

- (void)backgroundImageSettingsDidChange:(NSNotification *)inNotification;

@end

@implementation PKGDistributionPresentationViewController

- (instancetype)initWithNibName:(NSString *)inNibName bundle:(NSBundle *)inBundle
{
	self=[super initWithNibName:inNibName bundle:inBundle];
	
	if (self!=nil)
	{
		_supportedLocalizations=[[PKGInstallerApp installerApp] supportedLocalizations];
	}
	
	return self;
}

- (void)WB_viewDidLoad
{
	[super WB_viewDidLoad];
	
	_backgroundView.presentationDelegate=self;
	
	[_backgroundView registerForDraggedTypes:@[NSFilenamesPboardType]];
	
	_listView.dataSource=self;
	_listView.delegate=self;
	
	[_listView registerForDraggedTypes:@[PKGDistributionPresentationSectionsInternalPboardType,NSFilenamesPboardType]];
	
	_navigationButtons=@[_printButton,_saveButton,_goBackButton,_continueButton];
	
	// Plugin Buttons
	
	_pluginAddButton.pluginButtonType=PKGPlusButton;
	_pluginRemoveButton.pluginButtonType=PKGMinusButton;
	
	// Build the Preview In Menu
	
	NSMenu * tLanguagesMenu=_languagePreviewPopUpButton.menu;
	
	[tLanguagesMenu removeAllItems];
	
	[_supportedLocalizations enumerateObjectsUsingBlock:^(PKGInstallerAppLocalization * bLocalization, NSUInteger bIndex, BOOL *bOutStop) {
		
		NSMenuItem * tMenuItem=[[NSMenuItem alloc] initWithTitle:bLocalization.localizedName action:nil keyEquivalent:@""];
		tMenuItem.image=bLocalization.flagIcon;
		tMenuItem.tag=bIndex;
		
		[tLanguagesMenu addItem:tMenuItem];
	}];
	
	_languagePreviewPopUpButton.menu=tLanguagesMenu;
}

#pragma mark -

- (void)setDistributionProject:(PKGDistributionProject *)inDistributionProject
{
	if (_distributionProject!=inDistributionProject)
	{
		_distributionProject=inDistributionProject;
		
		[self refreshUI];
	}
}

- (void)setPresentationSettings:(PKGDistributionProjectPresentationSettings *)inPresentationSettings
{
	if (_presentationSettings!=inPresentationSettings)
	{
		if (_presentationSettings!=nil)
			[[NSNotificationCenter defaultCenter] removeObserver:self name:PKGPresentationStepSettingsDidChangeNotification object:[_presentationSettings backgroundSettings_safe]];
		
		_presentationSettings=inPresentationSettings;
		
		[self.presentationSettings sections_safe];	// Useful to make sure there is a list of steps;
	
		[self refreshUI];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(backgroundImageSettingsDidChange:) name:PKGPresentationStepSettingsDidChangeNotification object:[_presentationSettings backgroundSettings_safe]];
	}
}

#pragma mark -

- (void)updateBackgroundView
{
	void (^displayDefaultImage)() = ^{
		
		// A COMPLETER (check if image is shown on 10.8 or later)
		
		_backgroundView.image=nil;
	};
	
	void (^displayImageNotFound)() = ^{
		
		// A COMPLETER (find the ? image)
		
		_backgroundView.image=nil;
	};
	
	PKGPresentationBackgroundSettings * tBackgroundSettings=[_presentationSettings backgroundSettings_safe];
	
	if (tBackgroundSettings.showCustomImage==NO)
	{
		displayDefaultImage();
		
		return;
	}
	
	_backgroundView.imageAlignment=tBackgroundSettings.imageAlignment;
	_backgroundView.imageScaling=tBackgroundSettings.imageScaling;
	
	PKGFilePath * tFilePath=tBackgroundSettings.imagePath;
	
	if (tFilePath==nil)
	{
		displayDefaultImage();
		
		return;
	}
	
	NSString * tAbsolutePath=[self.filePathConverter absolutePathForFilePath:tFilePath];
	
	if (tAbsolutePath==nil)
	{
		displayImageNotFound();
		
		return;
	}
	
	NSImage * tImage=[[NSImage alloc] initWithContentsOfFile:tAbsolutePath];
	
	if (tImage==nil)
	{
		displayImageNotFound();
		
		return;
	}
	
	_backgroundView.image=tImage;
}

- (void)updateTitleViews
{
	// Refresh Chapter Title View
	
	if (_currentSectionViewController!=nil)
	{
		NSString * tPaneTitle=[_currentSectionViewController sectionPaneTitle];
	
		_pageTitleView.stringValue=(tPaneTitle!=nil) ? tPaneTitle : @"";
	}
	
	// Refresh Fake Window Title
	
	PKGPresentationTitleSettings * tTitleSettings=[self.presentationSettings titleSettings_safe];
	
	NSString * tMostAppropriateLocalizedTitle=[tTitleSettings valueForLocalization:_currentPreviewLanguage exactMatch:NO];
	
	if (tMostAppropriateLocalizedTitle==nil)
		tMostAppropriateLocalizedTitle=self.document.fileURL.path.lastPathComponent.stringByDeletingPathExtension;
	
	if (tMostAppropriateLocalizedTitle!=nil)
	{
		NSString * tTitleFormat=[[PKGInstallerApp installerApp] localizedStringForKey:@"WindowTitle" localization:_currentPreviewLanguage];
		
		_windowView.title=(tTitleFormat!=nil) ? [NSString stringWithFormat:tTitleFormat,tMostAppropriateLocalizedTitle] : tMostAppropriateLocalizedTitle;
	}
	else
	{
		_windowView.title=@"-";
	}
}

- (void)refreshUI
{
	if (_backgroundView==nil)
		return;
	
	if (self.distributionProject!=nil)
	{
		// Proxy Icon
		
		NSImage * tImage=[[PKGInstallerApp installerApp] iconForPackageType:(self.distributionProject.isFlat==YES) ? PKGInstallerAppDistrbutionFlat : PKGInstallerAppDistributionBundle];
		
		_windowView.proxyIcon=tImage;
	}
	
	if (_presentationSettings!=nil)
	{
		// Background View
		
		[self updateBackgroundView];
		
		// Title Views
		
		[self updateTitleViews];
		
		// List View
		
		NSNumber * tNumber=self.documentRegistry[PKGDistributionPresentationSelectedStep];
		
		[_listView reloadData];
		
		[_listView selectStep:(tNumber!=nil) ? [tNumber integerValue] : 0];
		
		// Show the Section view
		
		[self presentationListViewSelectionDidChange:[NSNotification notificationWithName:PKGPresentationListViewSelectionDidChangeNotification object:_listView userInfo:@{}]];
		
		// Inspector
		
		tNumber=self.documentRegistry[PKGDistributionPresentationInspectedItem];
		
		PKGPresentationInspectorItemTag * tItemTag=(tNumber!=nil) ? [tNumber integerValue] : PKGPresentationInspectorItemIntroduction;
		
		[_inspectorPopUpButton selectItemWithTag:tItemTag];
		
		// Show Inspected View
		
		// A COMPLETER
		
		// Language PopUpButton
		
		NSUInteger tLocalizationIndex=[_supportedLocalizations indexOfObjectPassingTest:^BOOL(PKGInstallerAppLocalization * bLocalization, NSUInteger bIndex, BOOL *bOutStop) {
		
			return [_currentPreviewLanguage isEqualToString:bLocalization.englishName];
			
		}];
		
		[_languagePreviewPopUpButton selectItemWithTag:(tLocalizationIndex!=NSNotFound) ? tLocalizationIndex : 0];
	}
}

#pragma mark -

- (void)WB_viewWillAppear
{
	[super WB_viewWillAppear];
	
	_currentPreviewLanguage=self.documentRegistry[PKGDistributionPresentationCurrentPreviewLanguage];
	
	if (_currentPreviewLanguage==nil)
	{
		NSMutableArray * tEnglishLanguageNames=[PKGLocalizationUtilities englishLanguages];
		
		if (tEnglishLanguageNames!=nil)
		{
			NSArray * tPreferedLocalizations=(__bridge_transfer NSArray *) CFBundleCopyPreferredLocalizationsFromArray((__bridge CFArrayRef) tEnglishLanguageNames);
			
			if (tPreferedLocalizations.count>0)
				_currentPreviewLanguage=[tPreferedLocalizations.firstObject copy];
		}
		
		if (_currentPreviewLanguage==nil)
			_currentPreviewLanguage=@"English";
		
		if (_currentPreviewLanguage!=nil)
			self.documentRegistry[PKGDistributionPresentationCurrentPreviewLanguage]=[_currentPreviewLanguage copy];
	}
	
	[self refreshUI];
}

- (void)WB_viewDidAppear
{
	[super WB_viewDidAppear];
	
	// Register for notifications
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowStateDidChange:) name:NSWindowDidBecomeMainNotification object:self.view.window];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowStateDidChange:) name:NSWindowDidResignMainNotification object:self.view.window];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(selectedLicenseNativeLocalizationDidChange:) name:PKGSelectedLicenseNativeLocalizationDidChangeNotification object:self.document];
}

- (void)WB_viewWillDisappear
{
	[super WB_viewWillDisappear];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidBecomeMainNotification object:self.view.window];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidResignMainNotification object:self.view.window];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:PKGSelectedLicenseNativeLocalizationDidChangeNotification object:self.document];
}

#pragma mark -

- (IBAction)addPlugin:(id)sender
{
	NSMutableArray * tSections=self.presentationSettings.sections;
	
	NSOpenPanel * tOpenPanel=[NSOpenPanel openPanel];
	
	tOpenPanel.canChooseFiles=YES;
	tOpenPanel.canChooseDirectories=NO;
	tOpenPanel.allowsMultipleSelection=YES;
	
	_openPanelDelegate=[PKGDistributionPresentationOpenPanelDelegate new];
	
	_openPanelDelegate.plugInsPaths=[tSections WB_arrayByMappingObjectsLenientlyUsingBlock:^NSString *(PKGPresentationSection * bPresentationSection, NSUInteger bIndex) {
		
		PKGFilePath * tFilePath=bPresentationSection.pluginPath;
		
		if (tFilePath==nil)
			return nil;
		
		return [self.filePathConverter absolutePathForFilePath:tFilePath];
	}];
	
	tOpenPanel.delegate=_openPanelDelegate;
	
	tOpenPanel.prompt=NSLocalizedString(@"Add",@"No comment");
	
	__block PKGFilePathType tReferenceStyle=[PKGApplicationPreferences sharedPreferences].defaultFilePathReferenceStyle;
	
	PKGOwnershipAndReferenceStyleViewController * tOwnershipAndReferenceStyleViewController=nil;
	
	if ([PKGApplicationPreferences sharedPreferences].showOwnershipAndReferenceStyleCustomizationDialog==YES)
	{
		tOwnershipAndReferenceStyleViewController=[PKGOwnershipAndReferenceStyleViewController new];
		
		tOwnershipAndReferenceStyleViewController.canChooseOwnerAndGroupOptions=NO;
		tOwnershipAndReferenceStyleViewController.referenceStyle=tReferenceStyle;
		
		NSView * tAccessoryView=tOwnershipAndReferenceStyleViewController.view;
		
		tOpenPanel.accessoryView=tAccessoryView;
	}
	
	[tOpenPanel beginSheetModalForWindow:self.view.window completionHandler:^(NSInteger bResult){
		
		if (bResult!=NSFileHandlingPanelOKButton)
			return;
		
		if ([PKGApplicationPreferences sharedPreferences].showOwnershipAndReferenceStyleCustomizationDialog==YES)
			tReferenceStyle=tOwnershipAndReferenceStyleViewController.referenceStyle;
		
		NSArray * tPaths=[tOpenPanel.URLs WB_arrayByMappingObjectsUsingBlock:^(NSURL * bURL,NSUInteger bIndex){
			
			return bURL.path;
		}];
		
		__block BOOL tModified=NO;
		__block NSInteger tInsertionIndex=_listView.selectedStep+1;
		
		[tPaths enumerateObjectsUsingBlock:^(NSString * bPath, NSUInteger bIndex, BOOL *bOutStop) {
			
			NSBundle * tBundle=[NSBundle bundleWithPath:bPath];
			
			if (tBundle==nil)
			{
				// A COMPLETER
				
				return;
			}
			
			PKGFilePath * tFilePath=[self.filePathConverter filePathForAbsolutePath:bPath type:tReferenceStyle];
			
			if (tFilePath==nil)
			{
				// A COMPLETER
				
				return;
			}
			
			PKGPresentationSection * tPresentationSection=[[PKGPresentationSection alloc] initWithPluginPath:tFilePath];
			
			[tSections insertObject:tPresentationSection atIndex:tInsertionIndex];
			
			tInsertionIndex++;
			
			tModified=YES;
		}];
		
		if (tModified==YES)
		{
			[_listView reloadData];
			
			[self noteDocumentHasChanged];
		}
	}];
}

- (IBAction)removePlugin:(id)sender
{
	NSAlert * tAlert=[[NSAlert alloc] init];
	tAlert.messageText=NSLocalizedString(@"Do you really want to remove this Installer plugin?",@"No comment");
	tAlert.informativeText=NSLocalizedString(@"This cannot be undone.",@"No comment");
	
	[tAlert addButtonWithTitle:NSLocalizedString(@"Remove",@"No comment")];
	[tAlert addButtonWithTitle:NSLocalizedString(@"Cancel",@"No comment")];
	
	[tAlert WB_beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse bResponse){
		
		if (bResponse!=NSAlertFirstButtonReturn)
			return;
		
		NSInteger tSelectedStep=_listView.selectedStep;
		
		if (tSelectedStep<0 || tSelectedStep>=self.presentationSettings.sections.count)
			return;
		
		[self.presentationSettings.sections removeObjectAtIndex:tSelectedStep];
		
		[_listView reloadData];
		
		// Find the first selectable Step
		
		NSInteger tIndex=tSelectedStep;
		
		if (tIndex==0)
		{
			[_listView selectStep:0];
		}
		else
		{
			tIndex=tSelectedStep-1;
			
			for (;tIndex>=0;tIndex--)
			{
				if ([self presentationListView:_listView shouldSelectStep:tIndex]==YES)
				{
					[_listView selectStep:tIndex];
					
					break;
				}
			}
		}
		
		// Refresh the list view
		
		[self presentationListViewSelectionDidChange:[NSNotification notificationWithName:PKGPresentationListViewSelectionDidChangeNotification object:_listView]];
		
		[self noteDocumentHasChanged];
	}];
}

- (IBAction)switchPreviewLanguage:(NSPopUpButton *)sender
{
	NSInteger tTag=sender.selectedItem.tag;
	
	NSString * tNewLanguage=((PKGInstallerAppLocalization *)_supportedLocalizations[tTag]).englishName;
	
	if ([tNewLanguage isEqualToString:_currentPreviewLanguage]==NO)
	{
		_currentPreviewLanguage=[tNewLanguage copy];
		
		self.documentRegistry[PKGDistributionPresentationCurrentPreviewLanguage]=[_currentPreviewLanguage copy];
		
		// Refresh Section View
		
		if (_currentSectionViewController!=nil)
		{
			_currentSectionViewController.localization=_currentPreviewLanguage;
			
			// Refresh Buttons
			
			[_currentSectionViewController updateButtons:_navigationButtons];
		}
		
		// Refresh Window title and Pane title
		
		[self updateTitleViews];
		
		// Refresh List View
		
		[_listView reloadData];
	}
}

- (IBAction)switchInspectedView:(NSPopUpButton *)sender
{
	NSInteger tTag=sender.selectedItem.tag;
	
	NSInteger tSelectedStep=_listView.selectedStep;
	
	PKGPresentationSection * tSelectedPresentationSection=self.presentationSettings.sections[tSelectedStep];
	
	if (tTag!=tSelectedPresentationSection.inspectorItemTag)
	{
		PKGPresentationInspectorItemTag tSectionTag=tTag;
		
		if (tSectionTag==PKGPresentationInspectorItemTitle ||
			tSectionTag==PKGPresentationInspectorItemBackground)
			tSectionTag=PKGPresentationInspectorItemIntroduction;
		
		NSUInteger tIndex=[self.presentationSettings.sections indexOfObjectPassingTest:^BOOL(PKGPresentationSection * bPresentationSection, NSUInteger bIndex, BOOL *bOutStop) {
			
			return (bPresentationSection.inspectorItemTag==tSectionTag);
			
		}];
						   
		if (tIndex==NSNotFound)
		{
			// A COMPLETER
			
			return;
		}
		
		dispatch_async(dispatch_get_main_queue(), ^{
			
			[_listView selectStep:tIndex];
			
			[self presentationListViewSelectionDidChange:[NSNotification notificationWithName:PKGPresentationListViewSelectionDidChangeNotification object:_listView userInfo:@{}]];
			
			// Show the Inspector View
			
			// A COMPLETER
			
			self.documentRegistry[PKGDistributionPresentationInspectedItem]=@(tTag);
		});
	}
}

- (BOOL)validateMenuItem:(NSMenuItem *)inMenuItem
{
	SEL tAction=inMenuItem.action;
	
	if (tAction==@selector(switchInspectedView:))
	{
		return (inMenuItem.tag!=PKGPresentationInspectorItemPlugIn);
	}
	
	return YES;
}

#pragma mark -

- (void)showViewForSection:(PKGPresentationSection *)inPresentationSection
{
	Class tNewClass=[inPresentationSection viewControllerClass];
	
	if (_currentSectionViewController!=nil)
	{
		if ([_currentSectionViewController class]==tNewClass)
		{
		
			// A COMPLETER
		
			return;
			
		}
		
		[_currentSectionViewController WB_viewWillDisappear];
		
		[_accessoryPlaceHolderView setSubviews:@[]];
		
		[_currentSectionViewController.view removeFromSuperview];
		
		[_currentSectionViewController WB_viewDidDisappear];
	}
	
	PKGPresentationSectionViewController * tNewSectionViewController=nil;
	
	if (inPresentationSection.pluginPath==nil)
		tNewSectionViewController=[[[inPresentationSection viewControllerClass] alloc] initWithDocument:self.document presentationSettings:self.presentationSettings];
	else
		tNewSectionViewController=[[[inPresentationSection viewControllerClass] alloc] initWithDocument:self.document presentationSection:inPresentationSection];
	
	if (tNewSectionViewController==nil)
	{
		// A COMPLETER
	}
	
	// Set the appropriate localization
	
	tNewSectionViewController.localization=_currentPreviewLanguage;
	
	
	tNewSectionViewController.view.frame=_sectionContentsView.bounds;
	
	[tNewSectionViewController WB_viewWillAppear];
	
	[_sectionContentsView addSubview:tNewSectionViewController.view];
	
	// Title view
	
	NSString * tPaneTitle=[tNewSectionViewController sectionPaneTitle];
	
	_pageTitleView.stringValue=(tPaneTitle!=nil) ? tPaneTitle : @"";
	
	// Buttons
	
	[tNewSectionViewController updateButtons:_navigationButtons];
	
	// Accessory view
	
	if (tNewSectionViewController.accessoryView!=nil)
	{
		// A COMPLETER
	}
	
	[tNewSectionViewController WB_viewDidAppear];
	
	_currentSectionViewController=tNewSectionViewController;
}

#pragma mark - PKGPresentationListViewDataSource

- (NSInteger)numberOfStepsInPresentationListView:(PKGPresentationListView *)inPresentationListView
{
	if (inPresentationListView!=_listView)
		return 0;
	
	return self.presentationSettings.sections.count;
}

- (id)presentationListView:(PKGPresentationListView *)inPresentationListView objectForStep:(NSInteger)inStep
{
	if (inPresentationListView!=_listView)
		return nil;
	
	PKGPresentationSection * tPresentationSection=self.presentationSettings.sections[inStep];
	
	if (tPresentationSection.pluginPath!=nil)
	{
		// It's a plugin step
		
		NSString * tAbsolutePath=[self.filePathConverter absolutePathForFilePath:tPresentationSection.pluginPath];
		
		if (tAbsolutePath==nil)
		{
			// A COMPLETER
			
			return nil;
		}
		
		PKGInstallerPlugin * tInstallerPlugin=[[PKGInstallerPlugin alloc] initWithBundleAtPath:tAbsolutePath];
		
		if (tInstallerPlugin==nil)
		{
			return NSLocalizedStringFromTable(@"Not Found",@"Presentation",@"");
		}
		
		NSString * tSectionTitle=[tInstallerPlugin sectionTitleForLocalization:_currentPreviewLanguage];
		
		return (tSectionTitle!=nil) ? tSectionTitle : NSLocalizedStringFromTable(@"Not Found",@"Presentation",@"");
	}
	else
	{
		return [[[PKGInstallerApp installerApp] pluginWithSectionName:tPresentationSection.name] sectionTitleForLocalization:_currentPreviewLanguage];
	}
	
	return nil;
}

- (BOOL)presentationListView:(PKGPresentationListView *)inPresentationListView writeStep:(NSInteger) inStep toPasteboard:(NSPasteboard*) inPasteboard
{
	if (_listView!=inPresentationListView)
		return NO;

	if (inStep<0 || inStep>=self.presentationSettings.sections.count)
		return NO;
	
	PKGPresentationSection * tPresentationSection=self.presentationSettings.sections[inStep];
	
	if (tPresentationSection.pluginPath==nil)
		return NO;
	
	_internalDragData=[NSIndexSet indexSetWithIndex:inStep];
	
	[inPasteboard declareTypes:@[PKGDistributionPresentationSectionsInternalPboardType] owner:self];
	
	[inPasteboard setData:[NSData data] forType:PKGDistributionPresentationSectionsInternalPboardType];
	
	return YES;
}

- (NSDragOperation)presentationListView:(PKGPresentationListView*)inPresentationListView validateDrop:(id <NSDraggingInfo>)info proposedStep:(NSInteger)inStep
{
	if (_listView!=inPresentationListView)
		return NSDragOperationNone;
	
	if (inStep<0 || inStep>=self.presentationSettings.sections.count)
		return NSDragOperationNone;
	
	NSPasteboard * tPasteBoard=[info draggingPasteboard];
	
	if ([tPasteBoard availableTypeFromArray:@[PKGDistributionPresentationSectionsInternalPboardType]]!=nil)
	{
		// We need to check it's an internal drag
		
		if (_listView==[info draggingSource])
		{
			// Check that the step is acceptable
			
			if ([_internalDragData WB_containsOnlyOneRange]==YES)
			{
				NSUInteger tFirstIndex=_internalDragData.firstIndex;
				NSUInteger tLastIndex=_internalDragData.lastIndex;
				
				if (inStep>=tFirstIndex && inStep<=(tLastIndex+1))
					return NSDragOperationNone;
			}
			else
			{
				if ([_internalDragData containsIndex:(inStep-1)]==YES)
					return NSDragOperationNone;
			}
			
			return NSDragOperationMove;
		}
		
		return NSDragOperationNone;
	}
	
	if ([tPasteBoard availableTypeFromArray:@[NSFilenamesPboardType]]!=nil)
	{
		// We need to check that the plugins are not already in the list
		
		NSArray * tArray=(NSArray *) [tPasteBoard propertyListForType:NSFilenamesPboardType];
		
		if (tArray.count==0)
			return NSDragOperationNone;
		
		NSMutableArray * tExistingPlugins=[self.presentationSettings.sections WB_arrayByMappingObjectsLenientlyUsingBlock:^NSString *(PKGPresentationSection * bPresentationSection, NSUInteger bIndex) {
			
			PKGFilePath * tFilePath=bPresentationSection.pluginPath;
			
			if (tFilePath==nil)
				return nil;
			
			return [self.filePathConverter absolutePathForFilePath:tFilePath];
		}];
		
		NSFileManager * tFileManager=[NSFileManager defaultManager];
		
		for(NSString * tPath in tArray)
		{
			if ([tPath.pathExtension caseInsensitiveCompare:@"bundle"]!=NSOrderedSame)
				return NSDragOperationNone;
			
			if ([tExistingPlugins indexOfObjectPassingTest:^BOOL(NSString * bPlugInPath,NSUInteger bIndex,BOOL * bOutStop){
				
				return ([bPlugInPath caseInsensitiveCompare:tPath]==NSOrderedSame);
				
			}]!=NSNotFound)
				return NSDragOperationNone;
				
			BOOL isDirectory;
			
			[tFileManager fileExistsAtPath:tPath isDirectory:&isDirectory];
			
			if (isDirectory==NO)
				return NSDragOperationNone;
				
			NSBundle * tBundle=[NSBundle bundleWithPath:tPath];
			
			if ([[tBundle objectForInfoDictionaryKey:@"InstallerSectionTitle"] isKindOfClass:NSString.class]==NO)
				return NSDragOperationNone;
		}
		
		return NSDragOperationCopy;
	}
	
	return NSDragOperationNone;
}

- (BOOL)presentationListView:(PKGPresentationListView*)inPresentationListView acceptDrop:(id <NSDraggingInfo>)info step:(NSInteger)inStep
{
	if (_listView!=inPresentationListView)
		return NO;
	
	NSPasteboard * tPasteBoard=[info draggingPasteboard];
		
	if ([tPasteBoard availableTypeFromArray:@[PKGDistributionPresentationSectionsInternalPboardType]]!=nil)
	{
		// Switch Position of Installer Plugin
		
		NSArray * tSections=[self.presentationSettings.sections objectsAtIndexes:_internalDragData];
		
		[self.presentationSettings.sections removeObjectsAtIndexes:_internalDragData];
		
		NSUInteger tIndex=[_internalDragData firstIndex];
		
		while (tIndex!=NSNotFound)
		{
			if (tIndex<inStep)
				inStep--;
			
			tIndex=[_internalDragData indexGreaterThanIndex:tIndex];
		}
		
		NSIndexSet * tNewIndexSet=[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(inStep, _internalDragData.count)];
		
		[self.presentationSettings.sections insertObjects:tSections atIndexes:tNewIndexSet];
		
		_internalDragData=nil;
		
		// Refresh the list view
		
		[_listView reloadData];
		
		[_listView selectStep:inStep];
				
		[self presentationListViewSelectionDidChange:[NSNotification notificationWithName:PKGPresentationListViewSelectionDidChangeNotification object:_listView]];
				
		[self noteDocumentHasChanged];
		
		return YES;
	}
	
	if ([tPasteBoard availableTypeFromArray:@[NSFilenamesPboardType]]!=nil)
	{
		// Add Installer Plugins
		
		NSArray * tArray=(NSArray *) [tPasteBoard propertyListForType:NSFilenamesPboardType];
		
		BOOL (^importPlugins)(PKGFilePathType) = ^BOOL(PKGFilePathType bPathType) {
		
			NSArray * tNewSections=[tArray WB_arrayByMappingObjectsUsingBlock:^id(NSString * bPath, NSUInteger bIndex) {
				
				PKGFilePath * tFilePath=[self.filePathConverter filePathForAbsolutePath:bPath type:bPathType];
				
				return [[PKGPresentationSection alloc] initWithPluginPath:tFilePath];
			}];
			
			if (tNewSections==nil)
				return NO;
			
			[self.presentationSettings.sections insertObjects:tNewSections atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(inStep, tNewSections.count)]];
			
			// Refresh the list view
			
			[_listView reloadData];
			
			[_listView selectStep:inStep];
			
			[self presentationListViewSelectionDidChange:[NSNotification notificationWithName:PKGPresentationListViewSelectionDidChangeNotification object:_listView]];
			
			[self noteDocumentHasChanged];
			
			/*if ([tArray count]==1)
			{
				[IBinstallationStepsView_ selectStepAtIndex:inStep];
				
				[self presentationListViewSelectionDidChange:[NSNotification notificationWithName:PKGPresentationListViewSelectionDidChangeNotification object:_listView]];
			}
			else
			{
				[[IBinstallationStepsView_ window] invalidateCursorRectsForView:IBinstallationStepsView_];
				
				[IBinstallationStepsView_ setNeedsDisplay:YES];
			}*/
			
			return YES;
		};
		
		if ([PKGApplicationPreferences sharedPreferences].showOwnershipAndReferenceStyleCustomizationDialog==NO)
			return importPlugins([PKGApplicationPreferences sharedPreferences].defaultFilePathReferenceStyle);
		
		PKGOwnershipAndReferenceStylePanel * tPanel=[PKGOwnershipAndReferenceStylePanel ownershipAndReferenceStylePanel];
		 
		tPanel.canChooseOwnerAndGroupOptions=NO;
		tPanel.keepOwnerAndGroup=NO;
		tPanel.referenceStyle=[PKGApplicationPreferences sharedPreferences].defaultFilePathReferenceStyle;
		 
		[tPanel beginSheetModalForWindow:_listView.window completionHandler:^(NSInteger bReturnCode){
			
			if (bReturnCode==PKGOwnershipAndReferenceStylePanelCancelButton)
				return;
			
			importPlugins(tPanel.referenceStyle);
		}];
		
		return YES;		// It may at the end be not accepted by the completion handler from the sheet
	}
	
	return NO;
}

#pragma mark - PKGPresentationListViewDelegate

- (BOOL)presentationListView:(PKGPresentationListView *)inPresentationListView shouldSelectStep:(NSInteger)inStep
{
	if (inPresentationListView!=_listView)
		return YES;
	
	PKGPresentationSection * tPresentationSection=self.presentationSettings.sections[inStep];
	
	return  ([tPresentationSection.name isEqualToString:PKGPresentationSectionDestinationSelectName]==NO &&
			 [tPresentationSection.name isEqualToString:PKGPresentationSectionInstallationName]==NO);
}

- (BOOL)presentationListView:(PKGPresentationListView *)inPresentationListView stepWillBeVisible:(NSInteger)inStep
{
	if (inPresentationListView!=_listView)
		return YES;
	
	PKGPresentationSection * tPresentationSection=self.presentationSettings.sections[inStep];
	
	if (tPresentationSection.pluginPath!=nil)
		return YES;
	
	if ([tPresentationSection.name isEqualToString:PKGPresentationSectionReadMeName]==YES)
	{
		return [self.presentationSettings readMeSettings_safe].isCustomized;
	}
	
	if ([tPresentationSection.name isEqualToString:PKGPresentationSectionLicenseName]==YES)
	{
		return [self.presentationSettings licenseSettings_safe].isCustomized;
	}
	
	return YES;
}

#pragma mark - PKGPresentationImageViewDelegate

- (NSDragOperation)presentationImageView:(PKGPresentationImageView *)inImageView validateDrop:(id <NSDraggingInfo>)info
{
	if (inImageView!=_backgroundView)
		return NSDragOperationNone;
	
	NSPasteboard * tPasteBoard = [info draggingPasteboard];
	
	if ([[tPasteBoard types] containsObject:NSFilenamesPboardType]==NO)
		return NSDragOperationNone;
	
	NSDragOperation sourceDragMask= [info draggingSourceOperationMask];
	
	if ((sourceDragMask & NSDragOperationCopy)==0)
		return NSDragOperationNone;
	
	NSArray * tFiles = [tPasteBoard propertyListForType:NSFilenamesPboardType];
	
	if (tFiles.count!=1)
		return NSDragOperationNone;
	
	NSString * tFilePath=tFiles.lastObject;
	
	BOOL tImageFormatSupported=[[NSFileManager defaultManager] WB_fileAtPath:tFilePath matchesTypes:[PKGPresentationBackgroundSettings backgroundImageTypes]];
	
	if (tImageFormatSupported==NO)
	{
		NSURL * tURL = [NSURL fileURLWithPath:tFilePath];
		
		CGImageSourceRef tSourceRef = CGImageSourceCreateWithURL((__bridge CFURLRef) tURL, NULL);
		
		if (tSourceRef!=NULL)
		{
			NSString * tImageUTI=(__bridge NSString *) CGImageSourceGetType(tSourceRef);
			
			if (tImageUTI!=nil)
				tImageFormatSupported=[[PKGPresentationBackgroundSettings backgroundImageUTIs] containsObject:tImageUTI];
			
			// Release Memory
			
			CFRelease(tSourceRef);
		}
	}
	
	if (tImageFormatSupported==NO)
		return NSDragOperationNone;
	
	return NSDragOperationCopy;
}

- (BOOL)presentationImageView:(PKGPresentationImageView *)inImageView acceptDrop:(id <NSDraggingInfo>)info
{
	if (inImageView!=_backgroundView)
		return NO;
	
	NSPasteboard * tPasteBoard= [info draggingPasteboard];
	
	if ([[tPasteBoard types] containsObject:NSFilenamesPboardType]==NO)
		return NO;
	
	NSArray * tFiles = [tPasteBoard propertyListForType:NSFilenamesPboardType];
	
	if (tFiles.count!=1)
		return NO;
	
	NSString * tPath=tFiles.lastObject;
	
	NSImage * tImage=[[NSImage alloc] initWithContentsOfFile:tPath];
	
	if (tImage==nil)
		return NO;
	
	PKGFilePath * tFilePath=nil;
	
	void (^finalizeSetBackgroundImagePath)(PKGFilePath *) = ^(PKGFilePath * bFilePath) {
		
		self.presentationSettings.backgroundSettings.imagePath=bFilePath;
		
		_backgroundView.image=tImage;
		
		[[NSNotificationCenter defaultCenter] postNotificationName:PKGPresentationStepSettingsDidChangeNotification object:self.presentationSettings.backgroundSettings userInfo:@{}];
		
		[self noteDocumentHasChanged];
	};
	
	if ([PKGApplicationPreferences sharedPreferences].showOwnershipAndReferenceStyleCustomizationDialog==YES)
	{
		PKGOwnershipAndReferenceStylePanel * tPanel=[PKGOwnershipAndReferenceStylePanel ownershipAndReferenceStylePanel];
		
		tPanel.canChooseOwnerAndGroupOptions=NO;
		tPanel.keepOwnerAndGroup=NO;
		tPanel.referenceStyle=[PKGApplicationPreferences sharedPreferences].defaultFilePathReferenceStyle;
		
		[tPanel beginSheetModalForWindow:self.view.window completionHandler:^(NSInteger bReturnCode){
			
			if (bReturnCode==PKGOwnershipAndReferenceStylePanelCancelButton)
				return;
			
			PKGFilePath * tNewFilePath=[self.filePathConverter filePathForAbsolutePath:tPath type:[PKGApplicationPreferences sharedPreferences].defaultFilePathReferenceStyle];
			
			finalizeSetBackgroundImagePath(tNewFilePath);
		}];
		
		return YES;
	}
	
	tFilePath=[self.filePathConverter filePathForAbsolutePath:tPath type:[PKGApplicationPreferences sharedPreferences].defaultFilePathReferenceStyle];
	
	finalizeSetBackgroundImagePath(tFilePath);
	
	return YES;
}

#pragma mark - Notifications

- (void)windowStateDidChange:(NSNotification *)inNotification
{
	if ([[_currentSectionViewController className] isEqualToString:@"PKGPresentationSectionInstallerPluginViewController"]==YES)
	{
		// Refresh Chapter Title View
		
		NSString * tPaneTitle=[_currentSectionViewController sectionPaneTitle];
	 
		_pageTitleView.stringValue=(tPaneTitle!=nil) ? tPaneTitle : @"";
	}
	
	// Refresh Background
	
	[self updateBackgroundView];
}

- (void)presentationListViewSelectionDidChange:(NSNotification *)inNotification
{
	if (inNotification.object!=_listView)
		return;
	
	NSInteger tSelectedStep=_listView.selectedStep;
	
	if (tSelectedStep<0 || tSelectedStep>=self.presentationSettings.sections.count)
		return;
	
	self.documentRegistry[PKGDistributionPresentationSelectedStep]=@(tSelectedStep);
	
	PKGPresentationSection * tSelectedPresentationSection=self.presentationSettings.sections[tSelectedStep];
	
	_pluginRemoveButton.enabled=(tSelectedPresentationSection.pluginPath!=nil);
	
	// Show the Section View
	
	[self showViewForSection:tSelectedPresentationSection];
	
	// Inspector
	
	if (inNotification.userInfo==nil)
	{
		PKGPresentationInspectorItemTag tTag=tSelectedPresentationSection.inspectorItemTag;
	
		if (((NSInteger)tTag)==-1)
		{
			// A COMPLETER
		
			NSLog(@"");
		}
		else
		{
			[_inspectorPopUpButton selectItemWithTag:tTag];
		
			if (tTag==PKGPresentationInspectorItemPlugIn)
				[_inspectorPopUpButton selectedItem].enabled=NO;
		
			// Show the Inspector View
			
			// A COMPLETER
		
			self.documentRegistry[PKGDistributionPresentationInspectedItem]=@(tTag);
		}
	}
}

- (void)backgroundImageSettingsDidChange:(NSNotification *)inNotification
{
	[self updateBackgroundView];
}

- (void)selectedLicenseNativeLocalizationDidChange:(NSNotification *)inNotification
{
	NSString * tPaneTitle=[_currentSectionViewController sectionPaneTitle];
	
	_pageTitleView.stringValue=(tPaneTitle!=nil) ? tPaneTitle : @"";
}

@end
