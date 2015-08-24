//
//  BTLEPeripheralViewController.swift
//  bluetooth
//
//  Created by  lifirewolf on 15/8/15.
//  Copyright (c) 2015年  lifirewolf. All rights reserved.
//

import UIKit
import CoreBluetooth

struct BlueTooth {
    static let TRANSFER_SERVICE_UUID = "E20A39F4-73F5-4BC4-A12F-17D1AD07A961"
    static let TRANSFER_CHARACTERISTIC_UUID = "08590F7E-DB05-467E-8757-72F6FAEB13D4"
    static let BUFFER_SIZE = 128
    static let MSG_SUBFIX = "!~fw~!"
}

class BTLEPeripheralViewController: UIViewController {

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var advertisingSwitch: UISwitch!
    @IBOutlet weak var tipLable: UILabel!
    
    var data: NSData!
    var offset = 0
    
    var peripheralManager: CBPeripheralManager!
    var transferCharacteristic: CBMutableCharacteristic!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        self.textView.delegate = self
        self.peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        self.advertisingSwitch.on = false
        data = nil
        offset = 0
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        
        self.peripheralManager.stopAdvertising()
        self.peripheralManager = nil
        println("Advertising stopped")
    }
    
    func sendData() {
    
        let length = data.length
        
        var size = BlueTooth.BUFFER_SIZE
        while offset < length {
            
            if length - offset < size {
                size = length - offset
            }
            
            let chunk = NSData(bytes: data.bytes + offset, length: size)
            
            let didSend = self.peripheralManager.updateValue(chunk, forCharacteristic: self.transferCharacteristic, onSubscribedCentrals: nil)
            if didSend {
                println("data chunk sended, size: \(size), offset: \(offset); totle: \(data.length)")
                offset += size
            } else {
                return
            }
        }
        
        if offset == length && size == BlueTooth.BUFFER_SIZE {
            let didSend = self.peripheralManager.updateValue(BlueTooth.MSG_SUBFIX.dataUsingEncoding(NSUTF8StringEncoding), forCharacteristic: self.transferCharacteristic, onSubscribedCentrals: nil)
            if didSend {
                println("sended end")
                offset = 0
            } else {
                println("sended end failed")
            }
        } else if offset < BlueTooth.BUFFER_SIZE {
            println("sended finished")
            offset = 0
        }
        
    }
    
    @IBAction func switchChanged(sender: UISwitch) {
        
        self.endEdit()
        
        self.peripheralManager.stopAdvertising()
        data = nil
        offset = 0
        
        if self.advertisingSwitch.on {
            
            tipLable.text = "正在广播信息"
            
            var dic = [String: AnyObject]()
            dic["msg"] = self.textView.text
            dic["image"] = UIImagePNGRepresentation(self.imageView.image)
            self.data = NSPropertyListSerialization.dataWithPropertyList(dic, format: NSPropertyListFormat.BinaryFormat_v1_0, options: 0, error: nil)
            
            self.peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [CBUUID(string: BlueTooth.TRANSFER_SERVICE_UUID)]])
        } else {
            tipLable.text = "未广播信息"
        }
    }
    
    var endEditTap: UITapGestureRecognizer!
    
    func beginEdit() {
        
        if self.advertisingSwitch.on {
            self.advertisingSwitch.on = false
            self.peripheralManager.stopAdvertising()
        }
        
        self.endEditTap = UITapGestureRecognizer(target: self, action: "endEdit")
        self.view.addGestureRecognizer(self.endEditTap)
    }
    
    func endEdit() {
        self.textView.resignFirstResponder()
        
        if let tap = self.endEditTap {
            self.view.removeGestureRecognizer(tap)
        }
    }
    
}


extension BTLEPeripheralViewController: CBPeripheralManagerDelegate {
    
    
    func peripheralManagerDidUpdateState(peripheral: CBPeripheralManager!) {
        if peripheral.state != CBPeripheralManagerState.PoweredOn {
            return
        }
        
        println("peripheralManager powered on.")
        
        self.transferCharacteristic = CBMutableCharacteristic(type: CBUUID(string: BlueTooth.TRANSFER_CHARACTERISTIC_UUID), properties: CBCharacteristicProperties.Notify, value: nil, permissions: CBAttributePermissions.Readable)
        
        let transferService: CBMutableService = CBMutableService(type: CBUUID(string: BlueTooth.TRANSFER_SERVICE_UUID), primary: true)
        
        transferService.characteristics = [self.transferCharacteristic]
        
        self.peripheralManager.addService(transferService)
    }
    
    func peripheralManager(peripheral: CBPeripheralManager!, central: CBCentral!, didSubscribeToCharacteristic characteristic: CBCharacteristic!) {
        
        println("Central subscribed to characteristic: \(central.description)")
        
        self.sendData()
        
    }
    
    func peripheralManager(peripheral: CBPeripheralManager!, central: CBCentral!, didUnsubscribeFromCharacteristic characteristic: CBCharacteristic!) {
        println("Central unsubscribed from characteristic: \(central.description)")
    }
    
    func peripheralManagerIsReadyToUpdateSubscribers(peripheral: CBPeripheralManager!) {
        
        println("peripheralManager Is Ready To Update Subscribers")
        
        self.sendData()
    }
    
}

extension BTLEPeripheralViewController: UITextViewDelegate {
    
    func textViewDidBeginEditing(textView: UITextView) {
        println("begin editing")
        self.beginEdit()
    }
    
    func textViewDidEndEditing(textView: UITextView) {
        println("end editing")
    }
    
    func textViewDidChange(textView: UITextView) {
        println("did change")
    }
    
}






















