//
//  UserDetailsViewController.swift
//  shareTest
//
//  Created by Costantino Pistagna on 27/05/2018.
//  Copyright © 2018 sofapps. All rights reserved.
//

import UIKit
import CloudKit

class UserDetailsViewController: UIViewController {
    var dataSource:CKRecord?
    @IBOutlet var firstNameTextField:UITextField!
    @IBOutlet var lastNameTextField:UITextField!
    @IBOutlet var emailTextField:UITextField!
    @IBOutlet var phoneNumberTextField:UITextField!


    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard let dataSource = dataSource else { return }
        fetchPublicRecord(recordID: dataSource.recordID) { [weak self] (firstName, lastName, shareURL, error) in
            if let error = error {
                print("error: ", error)
            }
            if let firstName = firstName, let lastName = lastName {
                DispatchQueue.main.async {
                    self?.firstNameTextField.text = firstName
                    self?.lastNameTextField.text = lastName
                }
            }
            if let shareURL = shareURL {
                self?.acceptShare(shareURL, completionHandler: { (privateRecord, error) in
                    if let error = error {
                        print("error: ", error)
                    }
                    else if let privateRecord = privateRecord,
                        let email = privateRecord.object(forKey: "email") as? String,
                        let phoneNumber = privateRecord.object(forKey: "phoneNumber") as? String
                    {
                        DispatchQueue.main.async {
                            self?.emailTextField.text = email
                            self?.phoneNumberTextField.text = phoneNumber
                        }
                    }
                })
            }
        }
    }
    
    func fetchPrivateRecord( completion: ((CKRecord?, Error?) -> Void)?) {
        let container = CKContainer.default()
        let privateDatabase = container.privateCloudDatabase
        let query = CKQuery(recordType: "PrivateInfo", predicate: NSPredicate(format: "TRUEPREDICATE", argumentArray: nil))
        let recordZone: CKRecordZone = CKRecordZone(zoneName: "FavZone")

        privateDatabase.perform(query, inZoneWith: recordZone.zoneID) { (results, error) -> Void in
            if let error = error {
                completion?(nil, error)
            }
            else if let results = results, let firstRecord = results.first {
                completion?(firstRecord, nil)
            }
        }
    }
    
    func updatePublicRecord(shareURL: String, completion: ((Bool, Error?) -> Void)?) {
        let container = CKContainer.default()
        let publicDatabase = container.publicCloudDatabase
        let query = CKQuery(recordType: "MyUser", predicate: NSPredicate(format: "TRUEPREDICATE", argumentArray: nil))
        var ourRecord:CKRecord?
        
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
            if let ourRecord = ourRecord {
                ourRecord.setObject(shareURL as CKRecordValue, forKey: "privateShareUrl")
                publicDatabase.save(ourRecord, completionHandler: { (record, error) -> Void in
                    if let error = error {
                        completion?(false, error)
                    }
                    else {
                        completion?(true, nil)
                    }
                })
            }
            else {
                completion?(false, NSError(domain: "Unknown error", code: -5, userInfo: nil))
            }
        }
    }

    
    @IBAction func addToFavoritesDidPressed() {
        guard let dataSource = dataSource, let creatorID = dataSource.creatorUserRecordID else { return }

        let container = CKContainer.default()
        let privateDatabase = container.privateCloudDatabase
        
        container.discoverUserIdentity(withUserRecordID: creatorID) { [weak self] (userIdentity, error) in
            if let error = error {
                print(error)
            }
            else if let userIdentity = userIdentity {

                self?.fetchPrivateRecord(completion: { (privateRecord, error) in
                    if let error = error {
                        print("error: ", error)
                    }
                    else if let privateRecord = privateRecord {
                        let share = CKShare(rootRecord: privateRecord)

                        /// Setup the participants for the share (take the CKUserIdentityLookupInfo from the identity you fetched)
                        if let lookupInfo = userIdentity.lookupInfo {
                            let op: CKFetchShareParticipantsOperation = CKFetchShareParticipantsOperation(userIdentityLookupInfos: [lookupInfo])
                            op.fetchShareParticipantsCompletionBlock = { error in
                                if let error = error {
                                    print("error: ", error)
                                }
                            }
                            op.shareParticipantFetchedBlock = { participant in
                                participant.permission = .readOnly
                                share.addParticipant(participant)
                                let modOp: CKModifyRecordsOperation = CKModifyRecordsOperation(recordsToSave: [privateRecord, share], recordIDsToDelete: nil)
                                modOp.savePolicy = .ifServerRecordUnchanged
                                modOp.perRecordCompletionBlock = {record, error in
                                    print("record completion \(record) and \(String(describing: error))")
                                }
                                modOp.modifyRecordsCompletionBlock = {records, recordIDs, error in
                                    if let error = error  {
                                        print("error in modifying the records: ", error)
                                    }
                                    else if let anURL = share.url {
                                        self?.updatePublicRecord(shareURL: anURL.absoluteString, completion: { (status, error) in
                                            if let error = error {
                                                print("error: ", error)
                                            }
                                        })
                                        print("share url \(String(describing: share.url))")
                                    }
                                }
                                privateDatabase.add(modOp)
                            }
                            container.add(op)
                        }

                    }
                })
            }
        }
    }
    
    func acceptShare(_ anURL: String, completionHandler: ((CKRecord?, Error?) -> Void)?) {
        let container = CKContainer.default()
        let sharedDatabase = container.sharedCloudDatabase
        let anURL = URL(string: anURL)!
        
        let op = CKFetchShareMetadataOperation(shareURLs: [anURL])
        op.perShareMetadataBlock = { shareURL, shareMetadata, error in
            if let error = error {
                completionHandler?(nil, error)
            }
            else if let shareMetadata = shareMetadata {
                if shareMetadata.participantStatus == .accepted {
                    let query = CKQuery(recordType: "PrivateInfo", predicate: NSPredicate(format: "TRUEPREDICATE", argumentArray: nil))
                    let zone = CKRecordZoneID(zoneName: "FavZone", ownerName: (shareMetadata.ownerIdentity.userRecordID?.recordName)!)
                    sharedDatabase.perform(query, inZoneWith: zone, completionHandler: { (records, error) in
                        if let error = error {
                            completionHandler?(nil, error)
                        }
                        else if let records = records, let firstRecord = records.first {
                            completionHandler?(firstRecord, nil)
                        }
                    })
                }
                else if shareMetadata.participantStatus == .pending {
                    let acceptOp = CKAcceptSharesOperation(shareMetadatas: [shareMetadata])
                    acceptOp.qualityOfService = .userInteractive
                    acceptOp.perShareCompletionBlock = {meta, share, error in
                        if let error = error {
                            completionHandler?(nil, error)
                        }
                        else if let share = share {
                            let query = CKQuery(recordType: "PrivateInfo", predicate: NSPredicate(format: "TRUEPREDICATE", argumentArray: nil))
                            let zone = CKRecordZoneID(zoneName: "FavZone", ownerName: (share.owner.userIdentity.userRecordID?.recordName)!)
                            sharedDatabase.perform(query, inZoneWith: zone, completionHandler: { (records, error) in
                                if let error = error {
                                    completionHandler?(nil, error)
                                }
                                else if let records = records, let firstRecord = records.first {
                                    completionHandler?(firstRecord, nil)
                                }
                            })
                        }
                    }
                    container.add(acceptOp)
                }
            }
        }
        op.fetchShareMetadataCompletionBlock = { error in
            if let error = error {
                completionHandler?(nil, error)
            }
        }
        container.add(op)
    }

    
    func fetchPublicRecord(recordID: CKRecordID, completion: ((String?, String?, String?, Error?) -> Void)?) {
        let container = CKContainer.default()
        let publicDatabase = container.publicCloudDatabase

        publicDatabase.fetch(withRecordID: recordID) { (record, error) in
            if let error = error {
                completion?(nil, nil, nil, error)
            }
            else if let record = record,
                let firstName = record.object(forKey: "firstName") as? String,
                let lastName = record.object(forKey: "lastName") as? String
            {
                let shareURL = record.object(forKey: "privateShareUrl") as? String
                completion?(firstName, lastName, shareURL, nil)
            }
        }
    }
}
