//
//  ViewController.swift
//  RTChatEx
//
//  Created by Paresh Thakor on 07/02/17.
//  Copyright © 2017 Paresh Thakor. All rights reserved.
//

import UIKit
import Firebase

class LoginViewController: UIViewController {
    
    @IBOutlet weak var nameField: UITextField!
    @IBOutlet weak var bottomLayoutGuideConstraint: NSLayoutConstraint!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func loginDidTouch(sender: AnyObject) {
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
}

