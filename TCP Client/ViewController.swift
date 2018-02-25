//
//  ViewController.swift
//  TCP Client
//
//  Created by Pavan Kotesh on 25/02/18.
//  Copyright © 2018 Pavan. All rights reserved.
//

import UIKit
import SwiftSocket

class ViewController: UIViewController {

  // MARK: - IBOutlets
  @IBOutlet weak var addressField: UITextField!
  @IBOutlet weak var portField: UITextField!
  @IBOutlet weak var connectButton: UIButton!
  @IBOutlet weak var statusTextView: UITextView!
  
  @IBOutlet weak var sendMessageTextField: UITextField!
  @IBOutlet weak var sendButton: UIButton!
  @IBOutlet weak var sendMessageViewBottomConstraint: NSLayoutConstraint!
  
  // MARK: - Variables
  var client: TCPClient!
  var isConnected: Bool = false
  
  // MARK: - Lifecycle
  override func viewDidLoad() {
    super.viewDidLoad()
    
    prepopulateValues()
    addressField.becomeFirstResponder()
    NotificationCenter.default.addObserver(self, selector: #selector(keyboarWillShow), name:NSNotification.Name.UIKeyboardWillShow, object: nil);
    addressField.addTarget(self, action: #selector(textFieldDidChange), for: UIControlEvents.editingChanged)
    portField.addTarget(self, action: #selector(textFieldDidChange), for: UIControlEvents.editingChanged)
  }
  
  // MARK: - IBActions
  @IBAction func connectButtonClicked(_ sender: UIButton) {
    if isConnected {
      disconnectFromClient()
    } else {
      connectToClient()
    }
  }
  
  @IBAction func sendButtonClicked(_ sender: Any) {
    switch client.send(string: sendMessageTextField.text ?? "" ) {
    case .success:
      statusTextView.insertText("You: \(sendMessageTextField.text ?? "")\n")
      sendMessageTextField.text = ""

    case .failure(let error):
      statusTextView.insertText("Failed to send with \(error) \n")
    }
  }

  @IBAction func clearButtonClicked(_ sender: Any) {
    statusTextView.text = ""
  }
  
  // MARK: - Private Methods
  @objc dynamic private func keyboarWillShow(notification: NSNotification) {
    let info = notification.userInfo!
    let keyboardFrame = (info[UIKeyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
    sendMessageViewBottomConstraint.constant = keyboardFrame.height + 10
  }

  @objc dynamic private func textFieldDidChange(textField: UITextField) {
    connectButton.isEnabled = hasHostValues()
  }
  
  private func hasHostValues() -> Bool {
    return (addressField.text ?? "").count > 0 && (portField.text ?? "").count > 0
  }

  private func connectToClient() {
    let address = addressField.text ?? getValue(forKey: "address")
    let port = Int32(portField.text ?? getValue(forKey: "port"))

    client = TCPClient(address: address, port: port!)
    
    switch client.connect(timeout: 5) {
    case .success:
      isConnected = true
      saveEnteredValues()
      updateUIFor(connectedStatus: isConnected)
      receiveMessage()
      
    case .failure(let error):
      statusTextView.insertText("Failed\n")
      print(error)
    }
  }
  
  private func disconnectFromClient() {
    client.close()
    
    isConnected = false
    updateUIFor(connectedStatus: isConnected)
  }
  
  private func updateUIFor(connectedStatus: Bool) {
    DispatchQueue.main.async {
      self.sendButton.isEnabled = connectedStatus
      self.sendMessageTextField.isEnabled = connectedStatus
      
      if connectedStatus {
        self.statusTextView.insertText("Connected\n")
        self.connectButton.setTitle("Disconnect", for: .normal)
        self.sendMessageTextField.becomeFirstResponder()
      } else {
        self.statusTextView.insertText("Disconnected\n")
        self.connectButton.setTitle("Connect", for: .normal)
      }
    }
  }
  
  private func receiveMessage() {
    DispatchQueue.global(qos: .background).async {
      while true {
        guard let data = self.client.read(1024*10, timeout: 100) else { return }

        DispatchQueue.main.async {
          if let response = String(bytes: data, encoding: .utf8) {
            self.statusTextView.insertText("Server: \(response)\n")
          }
        }
      }
    }
  }
  
  private func prepopulateValues() {
    addressField.text = getValue(forKey: "address")
    portField.text = getValue(forKey: "port")
    connectButton.isEnabled = hasHostValues()
  }

  private func saveEnteredValues() {
    set(addressField.text ?? "", forKey: "address")
    set(portField.text ?? "", forKey: "port")
  }

  private func set(_ value: String, forKey: String) {
    UserDefaults.standard.setValue(value, forKey: forKey)
  }
  
  private func getValue(forKey: String) -> String {
    return UserDefaults.standard.string(forKey: forKey) ?? ""
  }
}
