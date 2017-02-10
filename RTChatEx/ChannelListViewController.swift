//
//  ChannelListViewController.swift
//  RTChatEx
//
//  Created by Paresh Thakor on 07/02/17.
//  Copyright © 2017 Paresh Thakor. All rights reserved.
//

import Foundation
import UIKit
import Firebase

enum Section: Int {
    case createNewChannelSection = 0
    case currentChannelsSection
}

class ChannelListViewController: UITableViewController {
    var senderDisplayName: String?
    var newChannelTextField: UITextField?
    
    private var channels: [Channel] = []
    private lazy var channelRef:FIRDatabaseReference = FIRDatabase.database().reference().child("channels")
    private var channelRefHandle: FIRDatabaseHandle?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "RIC App"
        observeChannels()
    }
    
    /*override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        channels.append(Channel(id: "1", name: "Channel1"))
        channels.append(Channel(id: "2", name: "Channel2"))
        channels.append(Channel(id: "3", name: "Channel3"))
    }*/
    
    deinit {
        if let refH = channelRefHandle {
            channelRef.removeObserverWithHandle(refH)
        }
    }
    
    @IBAction func createChannel(sender: AnyObject) {
        if let name = newChannelTextField?.text {
            let newChannelRef = channelRef.childByAutoId()
            let channelItem = ["name": name]
            newChannelRef.setValue(channelItem)
        }
    }
    
    private func observeChannels() {
        channelRefHandle = channelRef.observeEventType(FIRDataEventType.ChildAdded, withBlock: { (snapshot) -> Void in
            let channelData = snapshot.value as! Dictionary<String, AnyObject>
            let id = snapshot.key
            if let name = channelData["name"] as! String! where name.characters.count > 0 {
                self.channels.append(Channel(id: id, name: name))
                self.tableView.reloadData()
            } else {
                print("Error! Could not decode channel data.")
            }
        })
    }
    
    // MARK: UITableViewDataSource Methods
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 2
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let currentSection: Section = Section(rawValue: section) {
            switch currentSection {
                case .createNewChannelSection:
                    return 1
                case .currentChannelsSection:
                    return channels.count
            }
        } else {
            return 0
        }
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let rid = indexPath.section == Section.createNewChannelSection.rawValue ? "NewChannel" : "ExistingChannel"
        let cell = tableView.dequeueReusableCellWithIdentifier(rid, forIndexPath: indexPath)
        
        if indexPath.section == Section.createNewChannelSection.rawValue {
            if let createNewChannelCell = cell as? CreateChannelCell {
                newChannelTextField = createNewChannelCell.newChannelNameField
            }
        } else if indexPath.section == Section.currentChannelsSection.rawValue {
            cell.textLabel?.text = channels[indexPath.row].name
        }
        
        return cell
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if indexPath.section == Section.currentChannelsSection.rawValue {
            let channel = channels[indexPath.row]
            self.performSegueWithIdentifier("ShowChannel", sender: channel)
        }
    }
    
    // MARK: Navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        super.prepareForSegue(segue, sender: sender)
        if let channel = sender as? Channel {
            let chatvc = segue.destinationViewController as! ChatViewController
            chatvc.senderDisplayName = senderDisplayName
            chatvc.channel = channel
            chatvc.channelRef = channelRef.child(channel.id)
        }
    }
    
}