//
//  ViewController.swift
//  RTChatEx
//
//  Created by Paresh Thakor on 07/02/17.
//  Copyright © 2017 Paresh Thakor. All rights reserved.
//

import UIKit
import Firebase

class LoginViewController: UIViewController, UITextFieldDelegate {
    
    @IBOutlet weak var nameField: UITextField!
    @IBOutlet weak var bottomLayoutGuideConstraint: NSLayoutConstraint!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        setupViewResizerOnKeyboardShown()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func loginDidTouch(sender: AnyObject?) {
        nameField.resignFirstResponder()
        if nameField.text != "" {
            FIRAuth.auth()?.signInAnonymouslyWithCompletion({ (user, error) in
                if let err = error {
                    print(err.localizedDescription)
                    return
                }
                
                self.performSegueWithIdentifier("LoginToChat", sender: nil)
            })
        }
    }
    
    // MARK: Navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        super.prepareForSegue(segue, sender: sender)
        let nvc = segue.destinationViewController as! UINavigationController
        let cvc = nvc.viewControllers.first as! ChannelListViewController
        cvc.senderDisplayName = nameField.text
    }
    
    func setupViewResizerOnKeyboardShown() {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardWillHide:", name: UIKeyboardWillHideNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardWillShow:", name: UIKeyboardWillShowNotification, object: nil)
//        NotificationCenter.default.addObserver(self,
//        selector: #selector(UIViewController.keyboardWillHideForResizing),
//        name: Notification.Name.UIKeyboardWillHide,
//        object: nil)
    }
    
    func keyboardWillHide(notification: NSNotification) -> Void {
        let frame = (notification.userInfo as Dictionary!)[UIKeyboardFrameEndUserInfoKey]?.CGRectValue
        self.bottomLayoutGuideConstraint.constant -= (frame?.height)!
        
        UIView.animateWithDuration(0.5, animations: {
            self.view.layoutIfNeeded()
        })
    }
    
    func keyboardWillShow(notification: NSNotification) -> Void {
        let frame = (notification.userInfo as Dictionary!)[UIKeyboardFrameEndUserInfoKey]?.CGRectValue
        //let newFrame = self.view.convertRect(frame!, fromView: (UIApplication.sharedApplication().delegate?.window)!)
        self.bottomLayoutGuideConstraint.constant += (frame?.height)!
        
        UIView.animateWithDuration(0.5, animations: {
            self.view.layoutIfNeeded()
        })
    }
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        nameField.resignFirstResponder()
    }

    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        loginDidTouch(nil)
        return true
    }
}

