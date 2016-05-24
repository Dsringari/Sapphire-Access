//
//  AppDelegate.swift
//  Grade Checker
//
//  Created by Dhruv Sringari on 3/8/16.
//  Copyright © 2016 Dhruv Sringari. All rights reserved.
//

import UIKit
import CoreData
import MagicalRecord

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

	var window: UIWindow?

	func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
		// Override point for customization after application launch.

		// Set default preferences
		let appDefaults = ["setupTouchID": NSNumber(bool: true), "useTouchID": NSNumber(bool: false), "setupNotifications": NSNumber(bool: true)]
		NSUserDefaults.standardUserDefaults().registerDefaults(appDefaults)
		// Start the Magic!
		MagicalRecord.setLoggingLevel(.Warn)
		MagicalRecord.setupAutoMigratingCoreDataStack()

		return true
	}

	func application(application: UIApplication, willFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
		let settings = NSUserDefaults.standardUserDefaults()
		if (settings.stringForKey("selectedStudent") != nil) {
			UIApplication.sharedApplication().setMinimumBackgroundFetchInterval(NSTimeInterval(300)) // 5 min
		} else {
			UIApplication.sharedApplication().setMinimumBackgroundFetchInterval(UIApplicationBackgroundFetchIntervalNever)
		}
		return true
	}

	func applicationWillResignActive(application: UIApplication) {
		// Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
		// Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
	}

	func applicationDidEnterBackground(application: UIApplication) {
		// Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
		// If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.

		let settings = NSUserDefaults.standardUserDefaults()

		if (settings.stringForKey("selectedStudent") != nil) {
			UIApplication.sharedApplication().setMinimumBackgroundFetchInterval(NSTimeInterval(300)) // 5 min
            
		} else {
			UIApplication.sharedApplication().setMinimumBackgroundFetchInterval(UIApplicationBackgroundFetchIntervalNever)
		}

		var tabBarController: UITabBarController?
		if let containerVC = UIApplication.sharedApplication().keyWindow?.rootViewController as? ContainerVC {
			if let navigationController = containerVC.currentViewController as? UINavigationController {
                tabBarController = navigationController.visibleViewController as? UITabBarController
            }
		}

		if let mainTabBarController = tabBarController {
            mainTabBarController.selectedIndex = 0
            if let nVC = mainTabBarController.viewControllers?.first as? UINavigationController {
                if let gradesVC = nVC.visibleViewController as? GradesVC {
                    gradesVC.performSegueWithIdentifier("lock", sender: nil)
                }
            }
		}
	}

	func applicationWillEnterForeground(application: UIApplication) {
		// Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
	}

	func applicationDidBecomeActive(application: UIApplication) {
		// Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
	}

	func applicationWillTerminate(application: UIApplication) {
		// Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
		MagicalRecord.cleanUp()
	}
    
	func application(application: UIApplication, performFetchWithCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {

		let settings = NSUserDefaults.standardUserDefaults()
		let selectedStudentName = settings.stringForKey("selectedStudent")!
		let oldStudentAssignmentCount: Int = Assignment.MR_numberOfEntities().integerValue
		let student: Student = Student.MR_findFirstByAttribute("name", withValue: selectedStudentName)!
		var oldSubjects: [Subject] = Subject.MR_findAll()! as! [Subject]

		oldSubjects = oldSubjects.filter({ $0.lastUpdated != nil })
		var sectionGUIDs: [String] = []
		var dates: [NSDate] = []
		for s in oldSubjects {
			sectionGUIDs.append(s.sectionGUID!)
			dates.append(s.lastUpdated!)
		}

		let _ = UpdateService(studentID: student.objectID, completionHandler: { successful, error in
			settings.setBool(true, forKey: "updatedInBackground")
			if (!successful) {
				completionHandler(UIBackgroundFetchResult.Failed)
			} else {
				let localMOC = NSManagedObjectContext.MR_context()
				let newStudentAssignmentCount: Int = Assignment.MR_numberOfEntitiesWithContext(localMOC).integerValue

				let updatedSubjects = Subject.MR_findAllWithPredicate(NSPredicate(format: "lastUpdated != nil")) as! [Subject]

				var aGradeWasUpdated = false
				for subject in updatedSubjects {
					if let sectionGUID = sectionGUIDs.filter({ (s: String) in return s == subject.sectionGUID }).first {
						let index: Int = sectionGUIDs.indexOf(sectionGUID)!
						if (dates[index].compare(subject.lastUpdated!) == NSComparisonResult.OrderedDescending) {
							aGradeWasUpdated = true
							break
						}
					}
				}

				/*  
                    Values that Trigger the Notification
                    * The count of the old subjects with a lastUpdated value should be less than the count new subjects
				    * Any lastUpdated value becomes newer
				    * The count of assignments is increased
                */

				if (newStudentAssignmentCount != oldStudentAssignmentCount || sectionGUIDs.count < updatedSubjects.count || aGradeWasUpdated) {
					UIApplication.sharedApplication().cancelAllLocalNotifications()
					let newNotification = UILocalNotification()
					let now = NSDate()
					newNotification.fireDate = now
					newNotification.alertBody = student.name!.componentsSeparatedByString(" ")[0] + "'s Grades Have Been Updated"
					newNotification.soundName = UILocalNotificationDefaultSoundName
					UIApplication.sharedApplication().scheduleLocalNotification(newNotification)
					completionHandler(UIBackgroundFetchResult.NewData)
				} else {
					completionHandler(UIBackgroundFetchResult.NoData)
				}
			}
		})

	}
}

