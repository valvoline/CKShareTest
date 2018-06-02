//
//  ProfileEditViewController.swift
//  shareTest
//
//  Created by Costantino Pistagna on 27/05/2018.
//  Copyright © 2018 sofapps. All rights reserved.
//

import UIKit
import CloudKit

class ProfileEditViewController: UIViewController {
    @IBOutlet var firstNameTextField:UITextField!
    @IBOutlet var lastNameTextField:UITextField!
    @IBOutlet var emailTextField:UITextField!
    @IBOutlet var phoneNumberTextField:UITextField!


    override func viewDidLoad() {
        super.viewDidLoad()
        createFavZone(nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        fetchPublicRecord { (firstName, lastName, error) in
            if let error = error {
                //handle error appropriatelly
                print(error)
            }
            else if let firstName = firstName, let lastName = lastName {
                DispatchQueue.main.async {
                    self.firstNameTextField.text = firstName
                    self.lastNameTextField.text = lastName
                }
            }
        }
        
        fetchPrivateRecord { (email, phoneNumber, error) in
            if let error = error {
                //handle error appropriatelly
                print(error)
            }
            else if let email = email, let phoneNumber = phoneNumber {
                DispatchQueue.main.async {
                    self.emailTextField.text = email
                    self.phoneNumberTextField.text = phoneNumber
                }
            }
        }
    }
    
    @IBAction func saveDidPressed() {
        if let firstName = firstNameTextField.text, let lastName = lastNameTextField.text {
            createPublicRecord(firstName: firstName, lastName: lastName) { (status, error) in
                if let error = error {
                    //handle error appropriatelly
                    print(error)
                }
                else {
                    print("record saved succesfully")
                }
            }
        }
        if let email = emailTextField.text, let phoneNumber = phoneNumberTextField.text {
            createPrivateRecord(email: email, phoneNumber: phoneNumber) { (status, error) in
                if let error = error {
                    //handle error appropriatelly
                    print(error)
                }
                else {
                    print("record saved succesfully")
                }
            }
        }
    }
    
    func fetchPublicRecord( completion: ((String?, String?, Error?) -> Void)?) {
        let container = CKContainer.default()
        let publicDatabase = container.publicCloudDatabase
        let query = CKQuery(recordType: "MyUser", predicate: NSPredicate(format: "TRUEPREDICATE", argumentArray: nil))
        var ourRecord:CKRecord?
        
        publicDatabase.perform(query, inZoneWith: nil) { (results, error) -> Void in
            if let error = error {
                completion?(nil, nil, error)
            }
            else if let results = results {
                for aRecord in results {
                    if aRecord.creatorUserRecordID?.recordName == "__defaultOwner__" {
                        ourRecord = aRecord
                        break
                    }
                }
            }
            else {
                completion?(nil, nil, NSError(domain: "No record found", code: -3, userInfo: nil))
            }
            
            if let ourRecord = ourRecord,
                let firstName = ourRecord.object(forKey: "firstName") as? String,
                let lastName = ourRecord.object(forKey: "lastName") as? String
            {
                completion?(firstName, lastName, nil)
            }
            else {
                completion?(nil, nil, NSError(domain: "Unknown error", code: -4, userInfo: nil))
            }
        }
    }

    func fetchPrivateRecord( completion: ((String?, String?, Error?) -> Void)?) {
        let container = CKContainer.default()
        let privateDatabase = container.privateCloudDatabase
        let query = CKQuery(recordType: "PrivateInfo", predicate: NSPredicate(format: "TRUEPREDICATE", argumentArray: nil))
        let recordZone: CKRecordZone = CKRecordZone(zoneName: "FavZone")
        var ourRecord:CKRecord?
        
        privateDatabase.perform(query, inZoneWith: recordZone.zoneID) { (results, error) -> Void in
            if let error = error {
                completion?(nil, nil, error)
            }
            else if let results = results, let firstRecord = results.first {
                ourRecord = firstRecord
            }
            else {
                completion?(nil, nil, NSError(domain: "No record found", code: -3, userInfo: nil))
            }
            if let ourRecord = ourRecord,
                let email = ourRecord.object(forKey: "email") as? String,
                let phoneNumber = ourRecord.object(forKey: "phoneNumber") as? String
            {
                completion?(email, phoneNumber, nil)
            }
            else {
                completion?(nil, nil, NSError(domain: "Unknown error", code: -4, userInfo: nil))
            }
        }
    }

    func createPublicRecord(firstName: String, lastName: String, completion: ((Bool, Error?) -> Void)?) {
        let container = CKContainer.default()
        let publicDatabase = container.publicCloudDatabase
        let query = CKQuery(recordType: "MyUser", predicate: NSPredicate(format: "TRUEPREDICATE", argumentArray: nil))
        var ourRecord = CKRecord(recordType: "MyUser")

        publicDatabase.perform(query, inZoneWith: nil) { (results, error) -> Void in
            if let error = error {
                completion?(false, error)
                return
            }
            else if let results = results {
                for aRecord in results {
                    if aRecord.creatorUserRecordID?.recordName == "__defaultOwner__" {
                        ourRecord = aRecord
                        break
                    }
                }
            }

            ourRecord.setObject(firstName as CKRecordValue, forKey: "firstName")
            ourRecord.setObject(lastName as CKRecordValue, forKey: "lastName")
            
            publicDatabase.save(ourRecord, completionHandler: { (record, error) -> Void in
                if let error = error {
                    completion?(false, error)
                }
                else {
                    completion?(true, nil)
                }
            })
        }
    }
    
    func createPrivateRecord(email: String, phoneNumber: String, completion: ((Bool, Error?) -> Void)?) {
        let container = CKContainer.default()
        let privateDatabase = container.privateCloudDatabase
        let query = CKQuery(recordType: "PrivateInfo", predicate: NSPredicate(format: "TRUEPREDICATE", argumentArray: nil))
        let recordZone: CKRecordZone = CKRecordZone(zoneName: "FavZone")
        var ourRecord = CKRecord(recordType: "PrivateInfo", zoneID: recordZone.zoneID)

        privateDatabase.perform(query, inZoneWith: recordZone.zoneID) { (results, error) -> Void in
            if let error = error {
                completion?(false, error)
            }
            else if let results = results, let firstRecord = results.first {
                ourRecord = firstRecord
            }
            ourRecord.setObject(email as CKRecordValue, forKey: "email")
            ourRecord.setObject(phoneNumber as CKRecordValue, forKey: "phoneNumber")
            
            privateDatabase.save(ourRecord, completionHandler: { (record, error) -> Void in
                if let error = error {
                    completion?(false, error)
                }
                else {
                    completion?(true, nil)
                }
            })
        }
    }
    
    func createFavZone(_ completionHandler:((Bool, Error?)->Void)?) {
        let container = CKContainer.default()
        let privateDatabase = container.privateCloudDatabase
        let customZone = CKRecordZone(zoneName: "FavZone")
        
        privateDatabase.save(customZone, completionHandler: ({returnRecord, error in
            if let error = error {
                completionHandler?(false, error)
            }
            else {
                completionHandler?(true, nil)
            }
        }))
    }
    
    func createDefaultShareProfileURL() {
        let container = CKContainer.default()
        let privateDatabase = container.privateCloudDatabase
        
        let query = CKQuery(recordType: "PrivateInfo", predicate: NSPredicate(format: "TRUEPREDICATE", argumentArray: nil))
        let recordZone: CKRecordZone = CKRecordZone(zoneName: "FavZone")
        
        privateDatabase.perform(query, inZoneWith: recordZone.zoneID) { (results, error) -> Void in
            if let error = error {
                print(error)
            }
            else if let results = results, let ourRecord = results.first {
                let share = CKShare(rootRecord: ourRecord)
                
                let modOp: CKModifyRecordsOperation = CKModifyRecordsOperation(recordsToSave: [ourRecord, share], recordIDsToDelete: nil)
                modOp.savePolicy = .ifServerRecordUnchanged
                modOp.modifyRecordsCompletionBlock = { records, recordIDs, error in
                    if let error = error  {
                        print("error in modifying the records: ", error)
                    }
                    else if let anURL = share.url {
                        let container = CKContainer.default()
                        let publicDatabase = container.publicCloudDatabase
                        let query = CKQuery(recordType: "MyUser", predicate: NSPredicate(format: "TRUEPREDICATE", argumentArray: nil))
                        var myPublicProfile:CKRecord?
                        
                        publicDatabase.perform(query, inZoneWith: nil) { (results, error) -> Void in
                            if let error = error {
                                print("error: ", error)
                            }
                            else if let results = results {
                                for aRecord in results {
                                    if aRecord.creatorUserRecordID?.recordName == "__defaultOwner__" {
                                        myPublicProfile = aRecord
                                        break
                                    }
                                }
                            }
                            if let myPublicProfile = myPublicProfile {
                                myPublicProfile.setObject(anURL.absoluteString as CKRecordValue, forKey: "privateShareUrl")
                                publicDatabase.save(myPublicProfile, completionHandler: { (record, error) -> Void in
                                    if let error = error {
                                        print("error: ", error)
                                    }
                                    else {
                                        print("all done, folks!")
                                    }
                                })
                            }
                        }
                    }
                }
                privateDatabase.add(modOp)
            }
        }
    }

}

