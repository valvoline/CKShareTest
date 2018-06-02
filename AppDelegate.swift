//
//  AppDelegate.swift
//  shareTest
//
//  Created by Costantino Pistagna on 27/05/2018.
//  Copyright © 2018 sofapps. All rights reserved.
//

import UIKit
import CoreData
import CloudKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        CKContainer.default().requestApplicationPermission(CKApplicationPermissions.userDiscoverability) { (status, error) in
            if let error = error {
                print("handle error appropriatelly: ", error)
            }
            if status == .granted {
                //do something
            }
        }
        return true
    }

}

