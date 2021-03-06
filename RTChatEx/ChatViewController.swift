//
//  ChatViewController.swift
//  RTChatEx
//
//  Created by Paresh Thakor on 07/02/17.
//  Copyright © 2017 Paresh Thakor. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import JSQMessagesViewController
import Photos

final class ChatViewController: JSQMessagesViewController {
    
    // MARK: Properties
    lazy var outgoingBubbleImg: JSQMessagesBubbleImage = self.setupOutgoingBubble()
    lazy var incomingBubbleImg: JSQMessagesBubbleImage = self.setupIncomingBubble()
    lazy var storageRef: FIRStorageReference = FIRStorage.storage().referenceForURL("gs://rtchatex.appspot.com")
    
    private lazy var userIsTypingRef: FIRDatabaseReference = self.channelRef!.child("typingIndicator").child(self.senderId)
    private lazy var usersTypingQuery: FIRDatabaseQuery = self.channelRef!.child("typingIndicator").queryOrderedByValue().queryEqualToValue(true)
    private lazy var messageRef: FIRDatabaseReference = self.channelRef!.child("messages")
    
    private let imageURLNotSetKey = "NOTSET"
    private var localTyping = false
    private var photoMessageMap = [String: JSQPhotoMediaItem]()
    private var updateMessageRefHandle: FIRDatabaseHandle?
    
    var isTyping: Bool {
        get {
            return localTyping
        }
        set {
            localTyping = newValue
            userIsTypingRef.setValue(newValue)
        }
    }
    private var newMessageRefHandle: FIRDatabaseHandle?
    
    var messages = [JSQMessage]()
    var channelRef:FIRDatabaseReference?
    var channel: Channel? {
        didSet {
            title = channel?.name
        }
    }
    
    // MARK: View Lifecycle
    
    deinit {
        if let refHandle = newMessageRefHandle {
            messageRef.removeObserverWithHandle(refHandle)
        }
        
        if let refHandle = updateMessageRefHandle {
            messageRef.removeObserverWithHandle(refHandle)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.senderId = FIRAuth.auth()?.currentUser?.uid
        
        collectionView!.collectionViewLayout.incomingAvatarViewSize = CGSize.zero
        collectionView!.collectionViewLayout.outgoingAvatarViewSize = CGSize.zero
        
        observeMessages()
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
//        addMessage("Foo", name: "Mr. Bolt", text: "I love you!")
//        addMessage(senderId, name: "Me", text: "I bet on it")
//        addMessage(senderId, name: "Me", text: "I like it!")
//        
//        finishReceivingMessage()
        observeTyping()
    }
    
    // MARK: Collection view data source (and related) methods
    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return messages.count
    }
    
    override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = super.collectionView(collectionView, cellForItemAtIndexPath: indexPath) as! JSQMessagesCollectionViewCell
        let message = messages[indexPath.item]
        
        if message.senderId == senderId {
            cell.textView?.textColor = UIColor.whiteColor()
        } else {
            cell.textView?.textColor = UIColor.blackColor()
        }
        
        return cell
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!, messageDataForItemAtIndexPath indexPath: NSIndexPath!) -> JSQMessageData! {
        return messages[indexPath.item]
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!, messageBubbleImageDataForItemAtIndexPath indexPath: NSIndexPath!) -> JSQMessageBubbleImageDataSource! {
        let message = messages[indexPath.item]
        if message.senderId == senderId {
            return outgoingBubbleImg
        } else {
            return incomingBubbleImg
        }
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!, avatarImageDataForItemAtIndexPath indexPath: NSIndexPath!) -> JSQMessageAvatarImageDataSource! {
        return nil
    }
    
    override func didPressSendButton(button: UIButton!, withMessageText text: String!, senderId: String!, senderDisplayName: String!, date: NSDate!) {
        let itemRef = messageRef.childByAutoId()
        let messageItem = ["senderId": senderId!, "senderName": senderDisplayName!, "text": text!]
        itemRef.setValue(messageItem)
        JSQSystemSoundPlayer.jsq_playMessageSentSound()
        finishSendingMessage()
        
        isTyping = false
    }
    
    override func didPressAccessoryButton(sender: UIButton!) {
        let picker = UIImagePickerController()
        picker.delegate = self
        if UIImagePickerController.isSourceTypeAvailable(.Camera) {
            picker.sourceType = .Camera
        } else {
            picker.sourceType = .PhotoLibrary
        }
        
        presentViewController(picker, animated: true, completion: nil)
    }
    
    private func observeTyping() {
        let typingIR = channelRef?.child("typingIndicator")
        userIsTypingRef = (typingIR?.child(senderId))!
        userIsTypingRef.onDisconnectRemoveValue()
        
        usersTypingQuery.observeEventType(.Value, withBlock: { (data) in
            if data.childrenCount == 1 && self.isTyping {
                return
            }
            
            self.showTypingIndicator = data.childrenCount > 0
            self.scrollToBottomAnimated(true)
        })
    }
    
    private func observeMessages() {
        messageRef = (channelRef?.child("messages"))!
        let messageQ = messageRef.queryLimitedToLast(25)
        
        newMessageRefHandle = messageQ.observeEventType(.ChildAdded, withBlock: { (snapshot) -> Void in
            let messageData = snapshot.value as! Dictionary<String, String>
            
            if let id = messageData["senderId"] as String!, let name = messageData["senderName"] as String!, let text = messageData["text"] as String! where text.characters.count > 0 {
                self.addMessage(id, name: name, text: text)
                self.finishReceivingMessage()
            } else if let id = messageData["senderId"] as String!, let photoURL = messageData["photoURL"] as String! {
                if let mediaItem = JSQPhotoMediaItem(maskAsOutgoing: id == self.senderId) {
                    self.addPhotoMessage(withId: id, key: snapshot.key, mediaItem: mediaItem)
                    if photoURL.hasPrefix("gs://") {
                        self.fetchImageDataAtURL(photoURL, forMediaItem: mediaItem, clearsPhotoMessageMapOnSuccessForKey: nil)
                    }
                }
                print("Error! Could not decode message data.")
            }
        })
        
        updateMessageRefHandle = messageRef.observeEventType(.ChildAdded, withBlock: {(snapshot) in
            let key = snapshot.key
            let messageData = snapshot.value as! Dictionary<String, String>
            if let photoURL = messageData["photoURL"] as String! {
                if let mediaItem = self.photoMessageMap[key] {
                    self.fetchImageDataAtURL(photoURL, forMediaItem: mediaItem, clearsPhotoMessageMapOnSuccessForKey: key)
                }
            }
        })
    }
    
    // MARK: Firebase related methods
    func sendPhotoMessage () -> String? {
        let itemRef = messageRef.childByAutoId()
        let messageItem = ["photoURL": imageURLNotSetKey, "senderId": senderId!]
        itemRef.setValue(messageItem)
        
        JSQSystemSoundPlayer.jsq_playMessageSentSound()
        finishSendingMessage()
        
        return itemRef.key
    }
    
    
    // MARK: UI and User Interaction
    func setImageURL(url: String, forPhotoMessageWithKey key: String) {
        let itemRef = messageRef.child(key)
        itemRef.updateChildValues(["photoURL": url])
    }
    
    private func fetchImageDataAtURL(photoURL: String, forMediaItem mediaItem: JSQPhotoMediaItem, clearsPhotoMessageMapOnSuccessForKey key: String?) {
        let storageRef = FIRStorage.storage().referenceForURL(photoURL)
        
        storageRef.dataWithMaxSize(INT64_MAX, completion: { (data, error) in
            if let error = error {
                print("Error downloading image data: \(error)")
                return
            }
            
            storageRef.metadataWithCompletion({ (metadata, merr) in
                if let err = merr {
                    print("Error Downloading metadata: \(err)")
                    return
                }
                
                if metadata!.contentType == "image/gif" {
                    // GIF Image
                } else {
                    mediaItem.image = UIImage(data: data!)
                }
                
                self.collectionView?.reloadData()
                
                guard key != nil else {
                    return
                }
                self.photoMessageMap.removeValueForKey(key!)
            })
        })
    }
    
    private func setupOutgoingBubble() -> JSQMessagesBubbleImage {
        let bf = JSQMessagesBubbleImageFactory()
        return bf.outgoingMessagesBubbleImageWithColor(UIColor.jsq_messageBubbleBlueColor())
    }
    
    private func setupIncomingBubble() -> JSQMessagesBubbleImage {
        let bf = JSQMessagesBubbleImageFactory()
        return bf.incomingMessagesBubbleImageWithColor(UIColor.jsq_messageBubbleLightGrayColor())
    }
    
    // MARK: UITextViewDelegate methods
    
    override func textViewDidChange(textView: UITextView) {
        super.textViewDidChange(textView)
        //print(textView.text != "")
        isTyping = textView.text != ""
    }
    
    private func addMessage(withId: String, name: String, text: String) {
        if let message = JSQMessage(senderId: withId, displayName: name, text: text) {
            messages.append(message)
        }
    }
    
    private func addPhotoMessage(withId id: String, key: String, mediaItem: JSQPhotoMediaItem) {
        if let message = JSQMessage(senderId: id, displayName: "", media: mediaItem) {
            messages.append(message)
            
            if mediaItem.image == nil {
                photoMessageMap[key] = mediaItem
            }
            
            collectionView?.reloadData()
        }
    }
}

extension ChatViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
        picker.dismissViewControllerAnimated(true, completion: nil)
        
        if let photoRefUrl = info[UIImagePickerControllerReferenceURL] as? NSURL {
            let assets = PHAsset.fetchAssetsWithALAssetURLs([photoRefUrl], options: nil)
            let asset = assets.firstObject
            
            if let key = sendPhotoMessage() {
                asset?.requestContentEditingInputWithOptions(nil, completionHandler:{ (contentEditingInput, info) in
                    let imageFileURL = contentEditingInput?.fullSizeImageURL
                    let path = "\(FIRAuth.auth()?.currentUser?.uid)/\(Int(NSDate.timeIntervalSinceReferenceDate() * 1000))/\(photoRefUrl.lastPathComponent)"
                    self.storageRef.child(path).putFile(imageFileURL!, metadata: nil) { (metadata, error) in
                        if let error = error {
                            print("Error uploading photo: \(error.localizedDescription)")
                            return
                        }
                        self.setImageURL(self.storageRef.child((metadata?.path)!).description, forPhotoMessageWithKey: key)
                    }
                })
            }
        } else {
            // Handle photo picking from Camera
            let image = info[UIImagePickerControllerOriginalImage] as! UIImage
            if let key = sendPhotoMessage() {
                let imageData = UIImageJPEGRepresentation(image, 1.0)
                let imagePath = (FIRAuth.auth()!.currentUser?.uid)! + "\(Int(NSDate.timeIntervalSinceReferenceDate()*1000)).jpg"
                let metadata = FIRStorageMetadata()
                metadata.contentType = "image/jpeg"
                
                storageRef.child(imagePath).putData(imageData!, metadata: metadata) { (metadata, error) in
                    if let error = error {
                        print("Error uploading photo: \(error)")
                        return
                    }
                    
                    self.setImageURL(self.storageRef.child((metadata?.path)!).description, forPhotoMessageWithKey: key)
                }
            }
        }
    }
    
    func imagePickerControllerDidCancel(picker: UIImagePickerController) {
        picker.dismissViewControllerAnimated(true, completion: nil)
    }
}