//
//  CameraFPVViewController.swift
//  DJISDKSwiftDemo
//
//  Created by DJI on 2019/1/15.
//  Copyright © 2019 DJI. All rights reserved.
//

import UIKit
import DJISDK

class CameraFPVViewController: UIViewController {

    @IBOutlet weak var decodeModeSeg: UISegmentedControl!
    @IBOutlet weak var tempSwitch: UISwitch!
    @IBOutlet weak var tempLabel: UILabel!
    @IBOutlet weak var fpvView: UIView!
    @IBOutlet weak var missionState: UILabel!
    @IBOutlet weak var missionActionsState: UILabel!
    
    var adapter: VideoPreviewerAdapter?
    var needToSetMode = false
    var operatorV2: DJIWaypointV2MissionOperator?
    var waypointActionsV2 = [DJIWaypointV2Action]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let camera = fetchCamera()
        camera?.delegate = self
        
        needToSetMode = true
        
        DJIVideoPreviewer.instance()?.start()
        
        adapter = VideoPreviewerAdapter.init()
        adapter?.start()
        
        assignSourceChannel { [weak self] in
            self?.adapter?.setupFrameControlHandler()
        }
    }
    
    private func assignSourceChannel(_ completion: (() -> ())? = nil) {
        guard let product = DJISDKManager.product() as? DJIAircraft,
              let listCamera = product.cameras,
              let airLink = product.airLink else { return }
        if product.model == DJIAircraftModelNameMatrice300RTK {
            if airLink.isOcuSyncLinkSupported, let ocuSyncLink = airLink.ocuSyncLink {
                if listCamera.count == 0 {
                    ocuSyncLink.assignSource(toPrimaryChannel: .fpvCamera, secondaryChannel: .rightCamera) { (error) in
                        if error != nil {
                            print("assignSource Failed - 1", error!.localizedDescription)
                        } else {
                            completion?()
                        }
                    }
                } else {
                    ocuSyncLink.assignSource(toPrimaryChannel: .leftCamera, secondaryChannel: .fpvCamera) { (error) in
                        if error != nil {
                            print("assignSource Failed - 2", error!.localizedDescription)
                        } else {
                            completion?()
                        }
                    }
                }
            }
        } else {
            if product.camera?.displayName == DJICameraDisplayNameMavic2ZoomCamera
                || product.camera?.displayName == DJICameraDisplayNameMavic2ProCamera {
                completion?()
            } else { return }
        }
    }

    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        DJIVideoPreviewer.instance()?.setView(fpvView)
        updateThermalCameraUI()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        prepareWaypointV2MissionForM300 { [unowned self] (preparedMission) in
            if preparedMission != nil {
                self.operatorV2 = preparedMission
            } else {
                print("aaaa: preparedMission has error!!")
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Call unSetView during exiting to release the memory.
        DJIVideoPreviewer.instance()?.unSetView()
        
        if adapter != nil {
            adapter?.stop()
            adapter = nil
        }
    }
    
    @IBAction func onSwitchValueChanged(_ sender: UISwitch) {
        guard let camera = fetchCamera() else { return }
        
        let mode: DJICameraThermalMeasurementMode = sender.isOn ? .spotMetering : .disabled
        camera.setThermalMeasurementMode(mode) { [weak self] (error) in
            if error != nil {
                self?.tempSwitch.setOn(false, animated: true)

                let alert = UIAlertController(title: nil, message: String(format: "Failed to set the measurement mode: %@", error?.localizedDescription ?? "unknown"), preferredStyle: .alert)
                
                alert.addAction(UIAlertAction(title: "ok", style: .cancel, handler: nil))
                
                self?.present(alert, animated: true)
            }
        }
        
    }
    
    /**
     *  DJIVideoPreviewer is used to decode the video data and display the decoded frame on the view. DJIVideoPreviewer provides both software
     *  decoding and hardware decoding. When using hardware decoding, for different products, the decoding protocols are different and the hardware decoding is only supported by some products.
     */
    @IBAction func onSegmentControlValueChanged(_ sender: UISegmentedControl) {
        DJIVideoPreviewer.instance()?.enableHardwareDecode = sender.selectedSegmentIndex == 1
    }
    
    fileprivate func updateThermalCameraUI() {
        guard let camera = fetchCamera(),
        camera.isThermalCamera()
        else {
            tempSwitch.setOn(false, animated: false)
            return
        }
        
        camera.getThermalMeasurementMode { [weak self] (mode, error) in
            if error != nil {
                let alert = UIAlertController(title: nil, message: String(format: "Failed to set the measurement mode: %@", error?.localizedDescription ?? "unknown"), preferredStyle: .alert)

                alert.addAction(UIAlertAction(title: "ok", style: .cancel, handler: nil))
                
                self?.present(alert, animated: true)
                
            } else {
                let enabled = mode != .disabled
                self?.tempSwitch.setOn(enabled, animated: true)
                
            }
        }
    }
    
    @IBAction func uploadMissionBtnDidTap(sender: UIButton) {
        guard operatorV2 != nil else {
            print("operatorV2 is nil")
            return
        }
        
        operatorV2!.uploadMission(completion: { (error) in
            if error == nil {
                print("aaaa: Upload mission to drone success!!!")
            } else {
                print("aaaa: Upload mission to drone failed!!!")
            }
        })
    }
    
    @IBAction func uploadMissionActionsBtnDidTap(sender: UIButton) {
        guard operatorV2 != nil else {
            print("operatorV2 is nil")
            return
        }
        
        operatorV2!.uploadWaypointActions(waypointActionsV2) { (error) in
            if error == nil {
                print("aaaa: Upload mission actions to drone success!!!")
            } else {
                print("aaaa: Upload mission actions to drone failed!!!")
            }
        }
    }
    
    @IBAction func startMissionBtnDidTap(sender: UIButton) {
        guard operatorV2 != nil else {
            print("operatorV2 is nil")
            return
        }
        
        operatorV2!.startMission { (error) in
            if error == nil {
                print("aaaa: Start mission success!!!")
            } else {
                print("aaaa: Start mission failed!!!")
            }
        }
    }
    
    func prepareWaypointV2MissionForM300(completion: @escaping (DJIWaypointV2MissionOperator?) -> ()) {
        let operatorV2 = DJIWaypointV2MissionOperator()
        let listCoords = [
            CLLocationCoordinate2D(latitude: 36.290506, longitude: 139.455655),
            CLLocationCoordinate2D(latitude: 36.290384, longitude: 139.455753),
            CLLocationCoordinate2D(latitude: 36.290231, longitude: 139.455541),
            CLLocationCoordinate2D(latitude: 36.290256, longitude: 139.455245),
            CLLocationCoordinate2D(latitude: 36.290482, longitude: 139.455128),
            CLLocationCoordinate2D(latitude: 36.290662, longitude: 139.455346),
            CLLocationCoordinate2D(latitude: 36.290679, longitude: 139.455793),
        ]
        var actionIndex = 0
        
        // Rotate gimbal pitch & take photo at 0, -20, -45 + Rotate aircraft heading
        func createActionComboForEachWaypoint(waypointIndex: Int, heading: Int) -> [DJIWaypointV2Action] {
            var result = [DJIWaypointV2Action]()
            
            // MARK: - First Action
            // Trigger Param
            let firstTriggerParam = DJIWaypointV2ReachPointTriggerParam()
            firstTriggerParam.startIndex = UInt(waypointIndex)
            firstTriggerParam.waypointCountToTerminate = UInt(waypointIndex)

            let firstTrigger = DJIWaypointV2Trigger()
            firstTrigger.actionTriggerType = .reachPoint
            firstTrigger.reachPointTriggerParam = firstTriggerParam

            // Actuator Param
            let flyControlParam = DJIWaypointV2AircraftControlFlyingParam()
            flyControlParam.isStartFlying = false
            let firstActuatorParam = DJIWaypointV2AircraftControlParam()
            firstActuatorParam.operationType = .flyingControl
            firstActuatorParam.flyControlParam = flyControlParam
            let firstActuator = DJIWaypointV2Actuator()
            firstActuator.type = .aircraftControl
            firstActuator.aircraftControlActuatorParam = firstActuatorParam

            // Combine Trigger & Actuator
            if actionIndex != 0 {
                actionIndex += 1
            }
            let firstAction = DJIWaypointV2Action()
            firstAction.actionId = UInt(actionIndex)
            firstAction.trigger = firstTrigger
            firstAction.actuator = firstActuator

            // Add to action list
            result.append(firstAction)

            // MARK: - Second Action
            // trigger
            let secondTriggerParam = DJIWaypointV2AssociateTriggerParam()
            secondTriggerParam.actionIdAssociated = UInt(actionIndex)
            secondTriggerParam.actionAssociatedType = .afterFinished
            secondTriggerParam.waitingTime = UInt(0)

            let secondTrigger = DJIWaypointV2Trigger()
            secondTrigger.actionTriggerType = .actionAssociated
            secondTrigger.associateTriggerParam = secondTriggerParam

            // actuator
            let secondActuatorParam = DJIWaypointV2GimbalActuatorParam()
            secondActuatorParam.operationType = .rotateGimbal
            secondActuatorParam.rotation = DJIGimbalRotation(pitchValue: 0,
                                                                   rollValue: nil,
                                                                   yawValue: nil,
                                                                   time: 3.0,
                                                                   mode: .absoluteAngle,
                                                                   ignore: true)
            let secondActuator = DJIWaypointV2Actuator()
            secondActuator.type = .gimbal
            secondActuator.gimbalActuatorParam = secondActuatorParam

            // combine
            actionIndex += 1

            let secondAction = DJIWaypointV2Action()
            secondAction.actionId = UInt(actionIndex)
            secondAction.trigger = secondTrigger
            secondAction.actuator = secondActuator

            result.append(secondAction)
            
            // MARK: - Third Action
            // trigger
            let thirdTriggerParam = DJIWaypointV2AssociateTriggerParam()
            thirdTriggerParam.actionIdAssociated = UInt(actionIndex)
            thirdTriggerParam.actionAssociatedType = .afterFinished
            thirdTriggerParam.waitingTime = UInt(3)

            let thirdTrigger = DJIWaypointV2Trigger()
            thirdTrigger.actionTriggerType = .actionAssociated
            thirdTrigger.associateTriggerParam = thirdTriggerParam

            // actuator
            let thirdActuatorParam = DJIWaypointV2CameraActuatorParam()
            thirdActuatorParam.operationType = .takePhoto
            let thidActuator = DJIWaypointV2Actuator()
            thidActuator.type = .camera
            thidActuator.cameraActuatorParam = thirdActuatorParam

            // combine
            actionIndex += 1

            let thirdAction = DJIWaypointV2Action()
            thirdAction.actionId = UInt(actionIndex)
            thirdAction.trigger = thirdTrigger
            thirdAction.actuator = thidActuator

            result.append(thirdAction)
            
            // MARK: - Forth Action
            // trigger
            let forthTriggerParam = DJIWaypointV2AssociateTriggerParam()
            forthTriggerParam.actionIdAssociated = UInt(actionIndex)
            forthTriggerParam.actionAssociatedType = .afterFinished
            forthTriggerParam.waitingTime = UInt(3)

            let forthTrigger = DJIWaypointV2Trigger()
            forthTrigger.actionTriggerType = .actionAssociated
            forthTrigger.associateTriggerParam = forthTriggerParam

            // actuator
            let forthActuatorParam = DJIWaypointV2GimbalActuatorParam()
            forthActuatorParam.operationType = .rotateGimbal
            forthActuatorParam.rotation = DJIGimbalRotation(pitchValue: -20,
                                                                   rollValue: nil,
                                                                   yawValue: nil,
                                                                   time: 3.0,
                                                                   mode: .absoluteAngle,
                                                                   ignore: true)
            let forthActuator = DJIWaypointV2Actuator()
            forthActuator.type = .gimbal
            forthActuator.gimbalActuatorParam = forthActuatorParam

            // combine
            actionIndex += 1

            let forthAction = DJIWaypointV2Action()
            forthAction.actionId = UInt(actionIndex)
            forthAction.trigger = forthTrigger
            forthAction.actuator = forthActuator

            result.append(forthAction)

            // MARK: - Fifth Action
            // trigger
            let fifthTriggerParam = DJIWaypointV2AssociateTriggerParam()
            fifthTriggerParam.actionIdAssociated = UInt(actionIndex)
            fifthTriggerParam.actionAssociatedType = .afterFinished
            fifthTriggerParam.waitingTime = UInt(3)

            let fifthTrigger = DJIWaypointV2Trigger()
            fifthTrigger.actionTriggerType = .actionAssociated
            fifthTrigger.associateTriggerParam = fifthTriggerParam
            
            // actuator
            let fifthActuatorParam = DJIWaypointV2CameraActuatorParam()
            fifthActuatorParam.operationType = .takePhoto
            let fifthActuator = DJIWaypointV2Actuator()
            fifthActuator.type = .camera
            fifthActuator.cameraActuatorParam = fifthActuatorParam

            // combine
            actionIndex += 1

            let fifthAction = DJIWaypointV2Action()
            fifthAction.actionId = UInt(actionIndex)
            fifthAction.trigger = forthTrigger
            fifthAction.actuator = fifthActuator

            result.append(fifthAction)
            
            // MARK: - Sixth Action
            // trigger
            let sixthTriggerParam = DJIWaypointV2AssociateTriggerParam()
            sixthTriggerParam.actionIdAssociated = UInt(actionIndex)
            sixthTriggerParam.actionAssociatedType = .afterFinished
            sixthTriggerParam.waitingTime = UInt(3)

            let sixthTrigger = DJIWaypointV2Trigger()
            sixthTrigger.actionTriggerType = .actionAssociated
            sixthTrigger.associateTriggerParam = sixthTriggerParam

            // actuator
            let sixthActuatorParam = DJIWaypointV2GimbalActuatorParam()
            sixthActuatorParam.operationType = .rotateGimbal
            sixthActuatorParam.rotation = DJIGimbalRotation(pitchValue: -45,
                                                                   rollValue: nil,
                                                                   yawValue: nil,
                                                                   time: 3.0,
                                                                   mode: .absoluteAngle,
                                                                   ignore: true)
            let sixthActuator = DJIWaypointV2Actuator()
            sixthActuator.type = .gimbal
            sixthActuator.gimbalActuatorParam = sixthActuatorParam

            // combine
            actionIndex += 1

            let sixthAction = DJIWaypointV2Action()
            sixthAction.actionId = UInt(actionIndex)
            sixthAction.trigger = sixthTrigger
            sixthAction.actuator = sixthActuator

            result.append(sixthAction)
            
            // MARK: - Seventh Action
            // trigger
            let seventhTriggerParam = DJIWaypointV2AssociateTriggerParam()
            seventhTriggerParam.actionIdAssociated = UInt(actionIndex)
            seventhTriggerParam.actionAssociatedType = .afterFinished
            seventhTriggerParam.waitingTime = UInt(3)

            let seventhTrigger = DJIWaypointV2Trigger()
            seventhTrigger.actionTriggerType = .actionAssociated
            seventhTrigger.associateTriggerParam = seventhTriggerParam
            
            // actuator
            let seventhActuatorParam = DJIWaypointV2CameraActuatorParam()
            seventhActuatorParam.operationType = .takePhoto
            let seventhActuator = DJIWaypointV2Actuator()
            seventhActuator.type = .camera
            seventhActuator.cameraActuatorParam = seventhActuatorParam

            // combine
            actionIndex += 1

            let seventhAction = DJIWaypointV2Action()
            seventhAction.actionId = UInt(actionIndex)
            seventhAction.trigger = sixthTrigger
            seventhAction.actuator = seventhActuator

            result.append(seventhAction)
            
            // MARK: - Eighth Action
            // trigger
            let eighthTriggerParam = DJIWaypointV2AssociateTriggerParam()
            eighthTriggerParam.actionIdAssociated = UInt(actionIndex)
            eighthTriggerParam.actionAssociatedType = .afterFinished
            eighthTriggerParam.waitingTime = UInt(3)

            let eighthTrigger = DJIWaypointV2Trigger()
            eighthTrigger.actionTriggerType = .actionAssociated
            eighthTrigger.associateTriggerParam = eighthTriggerParam

            // actuator
            let flyControlParam1 = DJIWaypointV2AircraftControlFlyingParam()
            flyControlParam1.isStartFlying = true
            let eighthActuatorParam = DJIWaypointV2AircraftControlParam()
            eighthActuatorParam.operationType = .flyingControl
            eighthActuatorParam.flyControlParam = flyControlParam1

            let eighthActuator = DJIWaypointV2Actuator()
            eighthActuator.type = .aircraftControl
            eighthActuator.aircraftControlActuatorParam = eighthActuatorParam

            // combine
            actionIndex += 1

            let eighthAction = DJIWaypointV2Action()
            eighthAction.actionId = UInt(actionIndex)
            eighthAction.trigger = eighthTrigger
            eighthAction.actuator = eighthActuator

            result.append(eighthAction)
            
            return result
        }
        
        var listWaypoints = [DJIWaypointV2]()
        listCoords.enumerated().forEach { (index, loc) in
            let waypoint = DJIWaypointV2()
            waypoint.altitude = Float(30)
            waypoint.autoFlightSpeed = Float(3)
            waypoint.maxFlightSpeed = Float(5)
            waypoint.flightPathMode = .goToPointInAStraightLineAndStop
            waypoint.headingMode = .auto
            waypoint.coordinate = loc
            
            listWaypoints.append(waypoint)
            
            let comboAction = createActionComboForEachWaypoint(waypointIndex: index, heading: 90)
            if comboAction.count > 0 {
                waypointActionsV2.append(contentsOf: comboAction)
            }
        }
        
        let waypointV2Mission = DJIMutableWaypointV2Mission()
        waypointV2Mission.missionID = UInt.random(in: 1..<UInt.max)
        waypointV2Mission.maxFlightSpeed = Float(5)
        waypointV2Mission.autoFlightSpeed = Float(3)
        waypointV2Mission.finishedAction = .noAction
        waypointV2Mission.gotoFirstWaypointMode = .safely
        waypointV2Mission.exitMissionOnRCSignalLost = true
        waypointV2Mission.repeatTimes = 1
        waypointV2Mission.addWaypoints(listWaypoints)
        
        let currentMissionV2 = DJIWaypointV2Mission(mission: waypointV2Mission)
        
        operatorV2.load(currentMissionV2) { (error) in
            if error == nil {
                // MARK: - Set up listener
                // MARK: - Mission V2 listener toUploadEvent
                operatorV2.addListener(toUploadEvent: self, with: DispatchQueue.main, andBlock: { [weak self] (event) in
                    if event.error != nil {
                        let errCode = String((event.error! as NSError).code)
                        print("aaaa: Upload V2 failed: \(errCode) - \(event.error.debugDescription)")
                    }

                    if event.previousState == .uploading
                        && event.currentState == .readyToExecute {
                        print("aaaa: Upload Mission V2 success!!")
                    }
                    
                    if event.progress != nil {
                        if let progress = event.progress {
                            if progress.totalWaypointCount != 0
                                && progress.totalWaypointCount <= waypointV2Mission.waypointCount {
                                print("aaaa: Progress-1: \(progress.lastUploadedWaypointIndex)/\(progress.totalWaypointCount)")
                            }
                            print("aaaa: Progress-2: \(progress.lastUploadedWaypointIndex)/\(progress.totalWaypointCount)")
                        }
                    }
                    
                    if event.progress == nil {
                        print("aaaa: currentState: \(event.currentState) - previousState: \(event.previousState)")
                    }
                })

                // MARK: - Mission's Waypoint Actions V2 listener toActionUploadEvent
                operatorV2.addListener(toActionUploadEvent: self, with: DispatchQueue.main, andBlock: { [weak self] (event) in
                    guard let this = self else { return }
                    if event.error != nil {
                        let errCode = String((event.error! as NSError).code)
                        print("aaaa: Upload Action V2 failed: \(event.error.debugDescription)")
                    }
                    
                    if event.currentState == .readyToUpload {
                        operatorV2.uploadWaypointActions(this.waypointActionsV2, withCompletion: { (error) in
                            if error == nil {
                                print("aaaa: Upload Action V2 success!!")
                            } else {
                                let errCode = String((error! as NSError).code)
                                print("aaaa: Error code: \(errCode) - \(error!.localizedDescription) - Upload Action Error")
                            }
                        })
                    }
                        
                    if event.progress != nil {
                        if let progress = event.progress {
                            if progress.totalActionCount != 0
                                && progress.totalActionCount <= this.waypointActionsV2.count {
                                print("aaaa: Progress: \(progress.lastUploadedActionIndex)/\(progress.totalActionCount)")
                            }
                            print("aaaa: Progress: \(progress.lastUploadedActionIndex)/\(progress.totalActionCount)")
                        }
                    }
                    
                    if event.progress == nil {
                        print("aaaa: currentState action: \(event.currentState) - previousState action: \(event.previousState)")
                    }
                    
                    if event.previousState == .uploading
                        && event.currentState == .readyToExecute {
                        print("aaaa: Mission V2 ready to EXECUTE")
                    }
                })

                // MARK: - Mission V2 listener toExecutionEvent
                operatorV2.addListener(toExecutionEvent: self, with: DispatchQueue.main) { [weak self] (event) in
                    if event.error != nil {
                        let errCode = String((event.error! as NSError).code)
                        print("aaaa: Error code: \(errCode) - \(event.error.debugDescription)")
                        print("aaaa: Execution event failed: \(errCode) \(event.error.debugDescription)")
                    } else {
                        if event.progress != nil {
                            print("aaaa: Mission is \(event.currentState)")
                        }
                    }
                }

                // MARK: - Mission V2 listener toActionExecutionEvent
                operatorV2.addListener(toActionExecutionEvent: self, with: DispatchQueue.main) { (event) in
                    if event.error != nil {
                        let errCode = String((event.error! as NSError).code)
                        print("aaaa: Error code: \(errCode) - \(event.error.debugDescription)")
                    }
                    if event.progress != nil {
                        print("aaaa: toActionExecutionEvent progress \(event.progress!.actionId)")
                    }
                }

                // MARK: - Mission V2 listener toStopped
                operatorV2.addListener(toStopped: self, with: DispatchQueue.main, andBlock: { [weak self] (error) in
                    if error != nil {
                        let errCode = String((error! as NSError).code)
                        print("aaaa: Stop V2 mission failed: \(errCode) - \(error.debugDescription)")
                    } else {
                        print("aaaa: Stop V2 mission success!!")
                    }
                })

                // MARK: - Mission V2 listener toFinished
                operatorV2.addListener(toFinished: self, with: DispatchQueue.main) { [weak self] (error) in
                    if error != nil {
                        let errCode = String((error! as NSError).code)
                        print("aaaa: Error code: \(errCode) - \(error!.localizedDescription)")
                    } else {
                        print("aaaa: Mission Finished")
                    }
                }

                // MARK: - Mission V2 listener toStarted
                operatorV2.addListener(toStarted: self, with: DispatchQueue.main) { [weak self] in
                    print("aaaa: Mission Started")
                }
                
                if let errorParam = operatorV2.loadedMission?.checkParameters() {
                    let errCode = String((errorParam as NSError).code)
                    print("aaaa: Error \(errCode) - \(errorParam.localizedDescription)")
                    completion(nil)
                    return
                }
                
                operatorV2.downloadMission(completion: { (error) in
                    if error == nil {
                        if let downloadedMission = operatorV2.loadedMission {
                            let missionValidity = downloadedMission.checkParameters()
                            if missionValidity != nil {
                                print("aaaa: Error \(missionValidity!)")
                            }
                        }
                    }
                })
                
                // MARK: - Upload mission to drone
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
                    if operatorV2.currentState == .readyToUpload {
                        operatorV2.uploadMission { (error) in
                            if error == nil {
                                completion(operatorV2)
                            } else {
                                completion(nil)
                            }
                        }
                    } else {
                        completion(nil)
                    }
                }
            } else {
                completion(nil)
            }
        }
    }
}

/**
 *  DJICamera will send the live stream only when the mode is in DJICameraModeShootPhoto or DJICameraModeRecordVideo. Therefore, in order
 *  to demonstrate the FPV (first person view), we need to switch to mode to one of them.
 */
extension CameraFPVViewController: DJICameraDelegate {
    func camera(_ camera: DJICamera, didUpdate systemState: DJICameraSystemState) {
        if systemState.mode != .recordVideo && systemState.mode != .shootPhoto {
            return
        }
        if needToSetMode == false {
            return
        }
        needToSetMode = false
        camera.setMode(.shootPhoto) { [weak self] (error) in
            if error != nil {
                self?.needToSetMode = true
            }
        }
        
    }
    
    func camera(_ camera: DJICamera, didUpdateTemperatureData temperature: Float) {
        tempLabel.text = String(format: "%f", temperature)
    }
    
}

extension CameraFPVViewController {
    fileprivate func fetchCamera() -> DJICamera? {
        guard let product = DJISDKManager.product() else {
            return nil
        }
        
        if product is DJIAircraft || product is DJIHandheld {
            return product.camera
        }
        return nil
    }
}
