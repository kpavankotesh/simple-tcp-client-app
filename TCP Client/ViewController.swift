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
  
  // MARK: - Constants
  let maxPortValueLength = 5

  // MARK: - IBOutlets
  @IBOutlet weak var addressTextField: UITextField!
  @IBOutlet weak var portTextField: UITextField!
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
    addressTextField.becomeFirstResponder()

    NotificationCenter.default.addObserver(forName: NSNotification.Name.UIKeyboardWillHide, object: nil, queue: nil, using: keyboardWillHide(_:))
    NotificationCenter.default.addObserver(forName: NSNotification.Name.UIKeyboardWillShow, object: nil, queue: nil, using: keyboardWillShow(_:))

    addressTextField.addTarget(self, action: #selector(textFieldDidChange), for: UIControlEvents.editingChanged)
    portTextField.addTarget(self, action: #selector(textFieldDidChange), for: UIControlEvents.editingChanged)

    setupStatusTextView()
    setupTextFields()
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
  private func setupStatusTextView() {
    statusTextView.layer.borderColor = UIColor.lightGray.cgColor
    statusTextView.layer.borderWidth = 0.25
    statusTextView.layer.cornerRadius = 5
  }
  
  private func setupTextFields() {
    addressTextField.delegate = self
    portTextField.delegate = self
    sendMessageTextField.delegate = self
  }
  
  @objc dynamic private func keyboardWillShow(_ notification: Notification) {
    let info = notification.userInfo!
    let keyboardFrame = (info[UIKeyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
    sendMessageViewBottomConstraint.constant = keyboardFrame.height + 10
  }
  
  @objc dynamic private func keyboardWillHide(_ notification: Notification) {
    sendMessageViewBottomConstraint.constant = 15
  }

  @objc dynamic private func textFieldDidChange(textField: UITextField) {
    connectButton.isEnabled = hasHostValues()
  }

  private func hasHostValues() -> Bool {
    return (addressTextField.text ?? "").count > 0 && (portTextField.text ?? "").count > 0
  }

  private func connectToClient() {
    let address = addressTextField.text ?? getValue(forKey: "address")
    let port = Int32(portTextField.text ?? getValue(forKey: "port"))

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
    addressTextField.text = getValue(forKey: "address")
    portTextField.text = getValue(forKey: "port")
    connectButton.isEnabled = hasHostValues()
  }

  private func saveEnteredValues() {
    set(addressTextField.text ?? "", forKey: "address")
    set(portTextField.text ?? "", forKey: "port")
  }

  private func set(_ value: String, forKey: String) {
    UserDefaults.standard.setValue(value, forKey: forKey)
  }
  
  private func getValue(forKey: String) -> String {
    return UserDefaults.standard.string(forKey: forKey) ?? ""
  }
}

// MARK: - UITextFieldDelegate
extension ViewController: UITextFieldDelegate {
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    if textField == sendMessageTextField {
      sendButtonClicked(sendButton)
    } else if textField == portTextField {
      connectButtonClicked(connectButton)
    } else if textField == addressTextField {
      portTextField.becomeFirstResponder()
    }
    
    return true
  }
  
  func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
    if textField == portTextField {
      if string.count > 0 && (textField.text ?? "").count >= maxPortValueLength {
        return false
      }
    }
    
    return true
  }
}
