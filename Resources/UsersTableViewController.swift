//
//  UsersTableViewController.swift
//  shareTest
//
//  Created by Costantino Pistagna on 27/05/2018.
//  Copyright © 2018 sofapps. All rights reserved.
//

import UIKit
import CloudKit

class UsersTableViewController: UITableViewController {
    var dataSource:[CKRecord]?

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        fetchPublicRecord { [weak self] (results, error) in
            if let error = error {
                //handle error appropriately
                print(error)
            }
            else if let results = results {
                DispatchQueue.main.async {
                    self?.dataSource = results
                    self?.tableView.reloadData()
                }
            }
        }
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource?.count ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cellIdentifier", for: indexPath)
        if let aRecord = dataSource?[indexPath.row], let firstName = aRecord.object(forKey: "firstName"), let lastName = aRecord.object(forKey: "lastName") {
            cell.textLabel?.text = "\(firstName) \(lastName)"
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if let aRecord = dataSource?[indexPath.row] {
            self.performSegue(withIdentifier: "showDetails", sender: aRecord)
        }

    }

    func fetchPublicRecord( completion: (([CKRecord]?, Error?) -> Void)?) {
        let container = CKContainer.default()
        let publicDatabase = container.publicCloudDatabase
        let query = CKQuery(recordType: "MyUser", predicate: NSPredicate(format: "TRUEPREDICATE", argumentArray: nil))
        
        publicDatabase.perform(query, inZoneWith: nil) { (results, error) -> Void in
            if let error = error {
                completion?(nil, error)
            }
            else if let results = results {
                var retRecord = [CKRecord]()
                for aRecord in results {
                    if aRecord.creatorUserRecordID?.recordName != "__defaultOwner__" {
                        retRecord.append(aRecord)
                    }
                }
                completion?(retRecord, nil)
            }
            else {
                completion?(nil, NSError(domain: "No record found", code: -3, userInfo: nil))
            }
        }
    }


    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showDetails", let aVC = segue.destination as? UserDetailsViewController, let aRecord = sender as? CKRecord {
            aVC.dataSource = aRecord
        }
    }

}
