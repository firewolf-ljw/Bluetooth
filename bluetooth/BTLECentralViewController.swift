//
//  BTLECentralViewController.swift
//  bluetooth
//
//  Created by  lifirewolf on 15/8/15.
//  Copyright (c) 2015年  lifirewolf. All rights reserved.
//

import UIKit
import CoreBluetooth

class BTLECentralViewController: UIViewController {

    @IBOutlet weak var msgLabel: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    
    var centralManager: CBCentralManager!
    var discoveredPeripheral: CBPeripheral!
    var data: NSMutableData!

    override func viewDidLoad() {
        super.viewDidLoad()
        
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        self.centralManager = CBCentralManager(delegate: self, queue: nil)
        
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        
        self.centralManager.stopScan()
        println("Scanning stopped")
        self.centralManager = nil
    }

    func scan() {
        
        let serviceUUID = CBUUID(string: BlueTooth.TRANSFER_SERVICE_UUID)!
        let option = [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        
        self.centralManager.scanForPeripheralsWithServices([serviceUUID], options: option)
        
        println("Scanning started")
    }
    
    func cleanup() {
        if self.discoveredPeripheral != nil {
            
            if self.discoveredPeripheral!.state == CBPeripheralState.Disconnected {
                return
            }
            
            if self.discoveredPeripheral.services != nil {
                for service in self.discoveredPeripheral.services as! [CBService] {
                    
                    if service.characteristics != nil {
                        for characteristic in service.characteristics as! [CBCharacteristic] {
                            
                            if characteristic.UUID.isEqual(CBUUID(string: BlueTooth.TRANSFER_CHARACTERISTIC_UUID)) {
                                if characteristic.isNotifying {
                                    self.discoveredPeripheral.setNotifyValue(false, forCharacteristic: characteristic)
                                    return
                                }
                            }
                        }
                    }
                }
            }
            
            self.centralManager.cancelPeripheralConnection(self.discoveredPeripheral)
        }
    }
    
    @IBAction func reset(sender: AnyObject) {
        self.msgLabel.text = ""
        self.imageView.image = nil
        self.cleanup()
        self.scan()
    }
}

extension BTLECentralViewController: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(central: CBCentralManager) {
        
        println("centralManager Did Update State")
        
        if central.state != .PoweredOn {
            return
        }
        
        self.scan()
    }
    
    func centralManager(central: CBCentralManager!, didDiscoverPeripheral peripheral: CBPeripheral!, advertisementData: [NSObject : AnyObject]!, RSSI: NSNumber!) {
        
        if RSSI.integerValue < -35 || RSSI.integerValue > -15 {
            return
        }
        
        println("Discovered \(peripheral.name) at \(RSSI)")
        
        self.centralManager.connectPeripheral(peripheral, options: nil)
        
        self.discoveredPeripheral = peripheral
        self.data = NSMutableData()
        
    }
    
    func centralManager(central: CBCentralManager!, didFailToConnectPeripheral peripheral: CBPeripheral!, error: NSError!) {
        println("Failed to connect to \(peripheral.name). for: \(error.localizedDescription)")
        self.cleanup()
    }
    
    func centralManager(central: CBCentralManager!, didConnectPeripheral peripheral: CBPeripheral!) {
        println("Peripheral Connected")
        
        self.centralManager.stopScan()
        println("Connected, so Scanning stopped")
        
        peripheral.delegate = self
        
        peripheral.discoverServices([CBUUID(string: BlueTooth.TRANSFER_SERVICE_UUID)])
        
    }
    
    func centralManager(central: CBCentralManager!, didDisconnectPeripheral peripheral: CBPeripheral!, error: NSError!) {
        println("Peripheral Disconnected")
        self.discoveredPeripheral = nil;
        
    }
    
}


extension BTLECentralViewController: CBPeripheralDelegate {
    func peripheral(peripheral: CBPeripheral!, didDiscoverServices error: NSError!) {
        if nil != error {
            println("Error discovering services: \(error)")
            self.cleanup()
            return
        }
        
        println("did Discover Services from peripheral")
        
        for service in peripheral.services as! [CBService] {
            peripheral.discoverCharacteristics([CBUUID(string: BlueTooth.TRANSFER_CHARACTERISTIC_UUID)], forService: service)
        }
    }
    
    func peripheral(peripheral: CBPeripheral!, didDiscoverCharacteristicsForService service: CBService!, error: NSError!) {
        if error != nil {
            println("Error discovering characteristics: \(error)")
            self.cleanup()
            return
        }
        
        println("did Discover Characteristics For Service from peripheral")
        
        for characteristic in service.characteristics as! [CBCharacteristic] {
            
            if characteristic.UUID.isEqual(CBUUID(string: BlueTooth.TRANSFER_CHARACTERISTIC_UUID)) {
                
                peripheral.setNotifyValue(true, forCharacteristic: characteristic)
                
            }
        }
    }
    
    func peripheral(peripheral: CBPeripheral!, didUpdateValueForCharacteristic characteristic: CBCharacteristic!, error: NSError!) {
        
        if nil != error {
            println("Error discovering characteristics: \(error)")
            return
        }
        
        let data = characteristic.value

        if data.length == BlueTooth.BUFFER_SIZE {
            
            self.data.appendData(data)
            
            println("get: \(self.data.length) , appending")
            
        } else {
            let str = NSString(data: data, encoding: NSUTF8StringEncoding)
            if str != BlueTooth.MSG_SUBFIX {
                self.data.appendData(data)
            } else if self.data.length == 0 {
                peripheral.setNotifyValue(false, forCharacteristic: characteristic)
                return
            }
            
            println("get: \(self.data.length) , end: \(str)")
            
            if let dic = NSPropertyListSerialization.propertyListWithData(self.data, options:0, format: nil, error: nil) as? Dictionary<String, AnyObject> {
            
                if let msg = dic["msg"] as? String {
                    self.msgLabel.text = msg
                }
                if let image = dic["image"] as? NSData {
                    self.imageView.image = UIImage(data: image)
                }
                
                peripheral.setNotifyValue(false, forCharacteristic: characteristic)
                
                self.cleanup()
            }
            
        }
        
    }
    
    func peripheral(peripheral: CBPeripheral!, didUpdateNotificationStateForCharacteristic characteristic: CBCharacteristic!, error: NSError!) {
        
        if error != nil {
            println("Error changing notification state: \(error)");
        }
        
        if !characteristic.UUID.isEqual(CBUUID(string: BlueTooth.TRANSFER_CHARACTERISTIC_UUID)) {
            return
        }
        
        if characteristic.isNotifying {
            println("Notification began on \(characteristic)");
        } else {
            println("Notification stopped on \(characteristic).  Disconnecting");
            self.centralManager.cancelPeripheralConnection(peripheral)
        }
        
    }
    
}

























