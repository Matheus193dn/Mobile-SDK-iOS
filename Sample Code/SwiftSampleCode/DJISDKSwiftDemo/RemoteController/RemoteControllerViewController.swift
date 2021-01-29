//
//  RemoteControllerViewController.swift
//  DJISDKSwiftDemo
//
//  Created by hoangnm on 1/28/21.
//  Copyright © 2021 DJI. All rights reserved.
//

import UIKit
import DJISDK

final class RemoteControllerViewController: UIViewController {
    
    // Views
    @IBOutlet weak var listMasterTableView: UITableView!
    @IBOutlet weak var listSlaveTableView: UITableView!
    @IBOutlet weak var debugTextView: UITextView!
    
    // Buttons
    @IBOutlet weak var startMasterSearchingBtn: UIButton!
    @IBOutlet weak var stopMasterSearchingBtn: UIButton!
    @IBOutlet weak var getMasterSearchingStateBtn: UIButton!
    @IBOutlet weak var setModeBtn: UIButton!
    @IBOutlet weak var getModeBtn: UIButton!
    
    // Labels
    @IBOutlet weak var supportMasterSlaveStatusLabel: UILabel!
    
    // Properties
    var remoteController: DJIRemoteController?
    var masterList = ["Master: N/A"]
    var slaveList = ["Slave: N/A"]
    var slaveCredentials: DJIRCCredentials?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        listMasterTableView.delegate = self
        listMasterTableView.dataSource = self
        listMasterTableView.tableFooterView = UIView()
        listMasterTableView.register(UITableViewCell.self, forCellReuseIdentifier: "masterCell")
        
        listSlaveTableView.delegate = self
        listSlaveTableView.dataSource = self
        listSlaveTableView.tableFooterView = UIView()
        listSlaveTableView.register(UITableViewCell.self, forCellReuseIdentifier: "slaveCell")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let rc = fetchRemoteController() {
            rc.delegate = self
            remoteController = rc
            supportMasterSlaveStatusLabel.text = "isMasterSlaveModeSupported: \(rc.isMasterSlaveModeSupported())"
            
            rc.getNameWithCompletion { [weak self] (name, error) in
                guard let this = self else { return }
                let currentContent = this.debugTextView.text ?? ""
                if error == nil {
                    this.debugTextView.text = currentContent + "\nController name: \(name ?? "nil")"
                } else {
                    this.debugTextView.text = currentContent + "\nGetNameWithCompletion \(error!.localizedDescription)"
                }
            }
            
            rc.getPasswordWithCompletion { [weak self] (pass, error) in
                guard let this = self else { return }
                let currentContent = this.debugTextView.text ?? ""
                if error == nil {
                    this.debugTextView.text = currentContent + "\nController pass: \(pass ?? "nil")"
                } else {
                    this.debugTextView.text = currentContent + "\nGetPasswordWithCompletion \(error!.localizedDescription)"
                }
            }
            
            rc.getConnectedMasterCredentials { [weak self] (credentials, error) in
                guard let this = self else { return }
                let currentContent = this.debugTextView.text ?? ""
                if error == nil, credentials != nil {
                    let receivedSlaveCredentials = credentials!
                    this.slaveCredentials = receivedSlaveCredentials
                    this.debugTextView.text = currentContent + "\nCredentials id: \(receivedSlaveCredentials.id) - name: \(receivedSlaveCredentials.name ?? "null name") - pass: \(receivedSlaveCredentials.password ?? "null pass")"
                } else {
                    this.debugTextView.text = currentContent + "\nGetConnectedMasterCredentials \(error!.localizedDescription)"
                }
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        listMasterTableView.reloadData()
        listSlaveTableView.reloadData()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    @IBAction func buttonDidTap(_ sender: UIButton) {
        handleButtonDidTap(sender)
    }
    
    private func handleButtonDidTap(_ sender: UIButton) {
        guard let rc = remoteController else { return }
        let currentContent = debugTextView.text ?? ""
        switch sender {
        case startMasterSearchingBtn:
//            rc.startMasterSearching { [weak self] (remoteInfo) in
//                remoteInfo.forEach { (info) in
//                    self?.debugTextView.text = currentContent + "\nremote - id:\(info.id) - name:\(info.name)"
//                }
//            } withCompletion: { (error) in
//                if error != nil {
//                    DJIAlert.show(title: "StartMasterSearching Error", msg: "\(error!.localizedDescription)", fromVC: self)
//                }
//            }
//            rc.connectToMaster(withID: "", authorizationCode: nil) { (result, error) in
//                //
//            }
            rc.getModeWithCompletion { [weak self] (currentMode, error) in
                guard let this = self else { return }
                let currentContent = this.debugTextView.text ?? ""
                if error == nil {
                    if currentMode == .master {
                        this.debugTextView.text = currentContent + "\nCurrentMode is master"
                        rc.getSlaveList { [weak this] (slaveList, error) in
                            guard let unwrappedThis = this else { return }
                            let currentContent = unwrappedThis.debugTextView.text ?? ""
                            if error == nil, let unwrappedSlaveList = slaveList {
                                unwrappedThis.debugTextView.text = currentContent + "\nGetSlaveList success"
                                unwrappedThis.slaveList.removeAll()
                                unwrappedSlaveList.forEach { (rcInfo) in
                                    unwrappedThis.slaveList.append("\(rcInfo.id)")
                                }
                                unwrappedThis.listSlaveTableView.reloadData()
                            } else {
                                unwrappedThis.debugTextView.text = currentContent + "\nGetSlaveList fail \(error!.localizedDescription)"
                            }
                        }
                    } else if currentMode == .slave {
                        this.debugTextView.text = currentContent + "\nCurrentMode is slave"
//                        rc.requestGimbalControl { [weak this] (error) in
//                            guard let unwrappedThis = this else { return }
//                            let currentContent = unwrappedThis.debugTextView.text ?? ""
//                            if error == nil {
//                                unwrappedThis.debugTextView.text = currentContent + "\nRequestGimbalControl success"
//                            } else {
//                                unwrappedThis.debugTextView.text = currentContent + "\nRequestGimbalControl fail \(error!.localizedDescription)"
//                            }
//                        }
                    } else {
                        this.debugTextView.text = currentContent + "\(currentMode == .normal ? "Normal" : "Unknow")"
                    }
                } else {
                    this.debugTextView.text = currentContent + "\(error!.localizedDescription)"
                }
            }
        case stopMasterSearchingBtn:
            rc.stopMasterSearching { (error) in
                if error != nil {
                    DJIAlert.show(title: "StopMasterSearchingBtn Error", msg: "\(error!.localizedDescription)", fromVC: self)
                }
            }
        case getMasterSearchingStateBtn:
            rc.getMasterSearchingState { (isStarted, error) in
                if error == nil {
                    self.debugTextView.text = currentContent + "\nSearching is started:\(isStarted)"
                } else {
                    DJIAlert.show(title: "GetMasterSearchingStateBtn Error", msg: "\(error!.localizedDescription)", fromVC: self)
                }
            }
        case setModeBtn:
            rc.setMode(.master) { (error) in
                if error != nil {
                    DJIAlert.show(title: "SetModeBtn Error", msg: "\(error!.localizedDescription)", fromVC: self)
                }
            }
        case getModeBtn:
            rc.getModeWithCompletion { (mode, error) in
                if error == nil {
                    if mode == .master {
                        self.debugTextView.text = currentContent + "\n1.Index 0 - Master"
                    } else if mode == .slave {
                        self.debugTextView.text = currentContent + "\n1.Index 0 - Slave"
                    } else {
                        self.debugTextView.text = currentContent + "\n1.Index 0 - \(mode == .normal ? "Normal" : "Unknow")"
                    }
                } else {
                    DJIAlert.show(title: "GetModeBtn Error", msg: "\(error!.localizedDescription)", fromVC: self)
                }
            }
        default: break
        }
        listMasterTableView.reloadData()
        listSlaveTableView.reloadData()
    }
}

extension RemoteControllerViewController {
    func fetchProduct() -> DJIBaseProduct? {
        guard let product = DJISDKManager.product() else {
            return nil
        }
        return product
    }
    
    func fetchRemoteController() -> DJIRemoteController? {
        guard let product = fetchProduct() else {
            return nil
        }
        if product is DJIAircraft {
            let remoteController = (product as! DJIAircraft).remoteController
            return remoteController
        }
        return nil
    }
}

extension RemoteControllerViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView == listMasterTableView {
            return masterList.count
        } else {
            return slaveList.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if tableView == listMasterTableView {
            let cell = tableView.dequeueReusableCell(withIdentifier: "masterCell", for: indexPath) as UITableViewCell
            cell.textLabel?.text = masterList[indexPath.row]
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "slaveCell", for: indexPath) as UITableViewCell
            cell.textLabel?.text = slaveList[indexPath.row]
            return cell
        }
    }
}

extension RemoteControllerViewController: DJIRemoteControllerDelegate {
    func remoteController(_ rc: DJIRemoteController, didUpdate gpsData: DJIRCGPSData) {
    }
    
    func remoteController(_ rc: DJIRemoteController, didUpdate state: DJIRCHardwareState) {
    }
    
    func remoteController(_ rc: DJIRemoteController, didUpdate action: DJIRCButtonAction) {
    }
    
    func remoteController(_ rc: DJIRemoteController, didUpdate progress: DJIRCCalibrationProgress) {
    }
    
    func remoteController(_ rc: DJIRemoteController, didUpdate state: DJIRCMasterSlaveState) {
        let currentContent = debugTextView.text ?? ""
        if state.mode == .master {
            self.debugTextView.text = currentContent + "\n2.Index 0 - Master"
        } else if state.mode == .slave {
            self.debugTextView.text = currentContent + "\n2.Index 0 - Slave"
        } else {
            self.debugTextView.text = currentContent + "\n2.Index 0 - \(state.mode == .normal ? "Normal" : "Unknow")"
        }
    }
    
    func remoteController(_ rc: DJIRemoteController, didUpdateRTKChannelEnabled enabled: Bool) {
    }
    
    func remoteController(_ rc: DJIRemoteController, didUpdate batteryState: DJIRCBatteryState) {
    }
    
    func remoteController(_ rc: DJIRemoteController, didUpdate state: DJIRCFocusControllerState) {
    }
    
    func remoteController(_ rc: DJIRemoteController, didReceiveGimbalControlRequestFromSlave information: DJIRCInformation) {
        let currentContent = debugTextView.text ?? ""
        debugTextView.text = currentContent + "\ndidReceiveGimbalControlRequestFromSlave"
    }
    
    func remoteController(_ rc: DJIRemoteController, didUpdateMultiDevicePairingState state: DJIRCMultiDeviceAggregationState) {
    }
}
