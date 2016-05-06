//
//  PlayerControlView.swift
//  SwiftPlayer
//
//  Created by zhongzhendong on 16/3/16.
//  Copyright © 2016年 zhongzhendong. All rights reserved.
//

import UIKit
import MediaPlayer
import SnapKit

enum PlayerPanDirection {
    case Horizontal
    case Vertical
}

struct PlayerPanInfo {
    var startPoint: CGPoint = CGPointZero
    var panDirection: PlayerPanDirection = .Horizontal
    var changedTime: NSTimeInterval = 0.0
    var seekProgress: Float = 0.0
}

class PlayerControlView: UIView {
    
    weak var playerControl: PlayerControlProtocol?
    weak var playerItemInfo: PlayerItemInfoProtocol?
    
    var videoSlider = UISlider()
    
    var startBtn = PlayButton()
    var lockBtn = UIButton()
    var fullScreenBtn = UIButton()
    var currentTimeLabel = UILabel()
    var totalTimeLabel = UILabel()
    var progressView = UIProgressView()
    
    lazy var horizontalLable: UILabel = {
       let tempLabel = UILabel()
        tempLabel.backgroundColor = UIColor.blackColor()
        tempLabel.hidden = true
        tempLabel.textColor = UIColor.whiteColor()
        
        return tempLabel
    }()
    
    lazy var bottomView: UIView = {
        let tempView = UIView()
        tempView.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.5)
        
        let bottomLayer = CAGradientLayer()
        bottomLayer.startPoint = CGPointZero
        bottomLayer.endPoint = CGPointMake(0,1)
        bottomLayer.colors = [UIColor.clearColor().CGColor,UIColor.blackColor().CGColor]
        bottomLayer.locations = [0.0,1.0]
        
        tempView.layer.addSublayer(bottomLayer)
        return tempView
    }()
    
    lazy var topView : UIView = {
        let tempView = UIView()
        tempView.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.5)
        
        let topLayer = CAGradientLayer()
        topLayer.startPoint = CGPointMake(1,0)
        topLayer.endPoint = CGPointMake(1,1)
        topLayer.colors = [UIColor.blackColor().CGColor,UIColor.clearColor().CGColor]
        topLayer.locations = [0.0,1.0]
        
        tempView.layer.addSublayer(topLayer)
        
        return tempView
    }()
    
    var panInfo = PlayerPanInfo()
    
    private let delayHiddenTime = 4.0
    
    //MARK:- life cycle
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    deinit {
        print("deinit")
    }
    
    //MARK:- commonInit
    private func commonInit() {
        
        addSubview(horizontalLable)
        horizontalLable.snp_makeConstraints { (make) in
            make.center.equalTo(self)
        }
        
        addSubview(bottomView)
        bottomView.snp_makeConstraints { (make) -> Void in
            make.bottom.right.left.equalTo(self)
            make.height.equalTo(45)
        }
        
        addSubview(topView)
        topView.snp_makeConstraints { (make) -> Void in
            make.top.left.right.equalTo(self)
            make.height.equalTo(50)
        }
        
        startBtn.addTarget(self, action: #selector(PlayerControlView.clickStartBtn(_:)), forControlEvents: .TouchUpInside)
        startBtn.tintColor = UIColor.whiteColor()
        startBtn.buttonState = .Playing
        bottomView.addSubview(startBtn)
        startBtn.snp_makeConstraints { (make) -> Void in
            make.width.height.equalTo(15)
            make.left.equalTo(bottomView).offset(10)
            make.centerY.equalTo(bottomView)
        }
        
        currentTimeLabel.text = "00:00"
        currentTimeLabel.textColor = UIColor.whiteColor()
        currentTimeLabel.font = UIFont.systemFontOfSize(12)
        bottomView.addSubview(currentTimeLabel)
        
        currentTimeLabel.snp_makeConstraints { (make) -> Void in
            make.centerY.equalTo(bottomView)
            make.left.equalTo(startBtn.snp_right).offset(5)
        }
        
        fullScreenBtn.setImage(UIImage(named: "kr-video-player-fullscreen"), forState: .Normal)
        fullScreenBtn.addTarget(self, action: #selector(PlayerControlView.clickFullScreenBtn), forControlEvents: .TouchUpInside)
        bottomView.addSubview(fullScreenBtn)
        fullScreenBtn.snp_makeConstraints { (make) -> Void in
            make.width.height.equalTo(30)
            make.right.equalTo(bottomView).offset(-10)
            make.centerY.equalTo(bottomView)
        }
        
        totalTimeLabel.text = "00:00"
        totalTimeLabel.textColor = UIColor.whiteColor()
        totalTimeLabel.font = UIFont.systemFontOfSize(12)
        bottomView.addSubview(totalTimeLabel)
        totalTimeLabel.snp_makeConstraints { (make) -> Void in
            make.right.equalTo(fullScreenBtn.snp_left).offset(-2)
            make.centerY.equalTo(bottomView)
        }
        
        progressView.progressTintColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.3)
        progressView.trackTintColor = UIColor.clearColor()
        bottomView.addSubview(progressView)
        
        progressView.snp_makeConstraints { (make) -> Void in
            make.left.equalTo(currentTimeLabel.snp_right).offset(10)
            make.right.equalTo(totalTimeLabel.snp_left).offset(-10)
            make.centerY.equalTo(bottomView)
        }
        
        videoSlider.setThumbImage(UIImage(named: "slider"), forState: .Normal)
        videoSlider.minimumTrackTintColor = UIColor.whiteColor()
        videoSlider.maximumTrackTintColor = UIColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 0.3)
        
        videoSlider.addTarget(self, action: #selector(PlayerControlView.progressSliderTouchBegan(_:)), forControlEvents: .TouchDown)
        videoSlider.addTarget(self, action: #selector(PlayerControlView.progressSliderValueChanged(_:)), forControlEvents: .ValueChanged)
        videoSlider.addTarget(self, action: #selector(PlayerControlView.progressSliderTouchEnd(_:)), forControlEvents: .TouchUpInside)
        
        bottomView.addSubview(videoSlider)
        videoSlider.snp_makeConstraints { (make) -> Void in
            make.left.right.equalTo(progressView)
            make.centerY.equalTo(bottomView)
        }
        
        addDouleTapGesture()
        showControlView()
    }
    
    func dismissControlView() {
        print("control view dismiss")
        self.bottomView.hidden = true
        self.topView.hidden = true
    }
    
    func cancelDismissControlView() {
        NSObject.cancelPreviousPerformRequestsWithTarget(self, selector: #selector(dismissControlView), object: nil)
    }
    
    func showControlView(delayDismiss isDelay: Bool = true) {
        self.bottomView.hidden = false
        self.topView.hidden = false
        
        if isDelay {
            performSelector(#selector(dismissControlView), withObject: nil, afterDelay: delayHiddenTime)
        }
    }
    
    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        showControlView()
    }
}

//MARK:- 手势操作
extension PlayerControlView: UIGestureRecognizerDelegate {
    
    internal func addDouleTapGesture() {
        let doubleTapGes = UITapGestureRecognizer(target: self, action: #selector(doubleTapGestureHandler(_:)))
        doubleTapGes.delegate = self
        doubleTapGes.numberOfTapsRequired = 2
        self.addGestureRecognizer(doubleTapGes)
    }
    
    internal func doubleTapGestureHandler(tapGes: UITapGestureRecognizer) {
        print("double taped")
        clickStartBtn(startBtn)
        switch tapGes.state {
        case .Began:
            showControlView(delayDismiss: false)
        case .Ended, .Cancelled, .Failed:
            showControlView()
        default:
            break
        }
    }
    
    func addPanGesture() {
        let panGesture = UIPanGestureRecognizer(target: self, action:#selector(PlayerControlView.panGestureHandler(_:)))
        panGesture.delegate = self
        self.addGestureRecognizer(panGesture)
    }
    
    func panGestureHandler(panGes: UIPanGestureRecognizer) {
        
        let point = panGes.locationInView(self)
        let velocity = panGes.velocityInView(self)
        
        switch panGes.state {
        case .Began:
            showControlView(delayDismiss: false)
            
            if fabs(velocity.x) > fabs(velocity.y) {
                panInfo.panDirection = .Horizontal
            }else {
                panInfo.panDirection = .Vertical
            }
            
            panInfo.startPoint = point
        case .Changed:
            switch panInfo.panDirection {
            case .Horizontal:
                horizontalMoved(velocity.x)
            case .Vertical:
                verticalMoved(velocity.y)
            }
        case .Ended:
            showControlView()
            panGestureEnded()
        default:
            break;
        }
    }
    
    func horizontalMoved(dtX :CGFloat) {
        
        let videoTotalTime = playerItemInfo?.totalTime()
        let videoCurrenTime = playerItemInfo?.currentTime()
        
        if let totalTime = videoTotalTime, let currenTime = videoCurrenTime {
            var style = ""
            if dtX < 0 {
                style = "<<"
            }else {
                style = ">>"
            }
            
            panInfo.changedTime += Double(dtX) / 200.0
            
            var destinationTime = panInfo.changedTime + currenTime
            
            if destinationTime > totalTime {
                destinationTime = totalTime
            }else if destinationTime < 0 {
                destinationTime = 0
            }
            
            dispatch_async(dispatch_get_main_queue(), { [unowned self] in
                self.horizontalLable.text = style + " " + self.durationStringWithTime(destinationTime) + "/" + self.durationStringWithTime(totalTime)
                self.horizontalLable.hidden = false
                
                self.panInfo.seekProgress = Float(destinationTime/totalTime)
            })
        }
    }
    
    func verticalMoved(dtY: CGFloat)  {
        
        if panInfo.startPoint.x > bounds.size.width / 2 {
            //音量
            MPMusicPlayerController.applicationMusicPlayer()
            let volumeView = MPVolumeView()
            for view in volumeView.subviews {
                if let slider = view as? UISlider{
                    if slider.dynamicType.description() == "MPVolumeSlider" {
                        slider.value -= Float(dtY / 10000)
                    }
                }
            }
        }else {
            //亮度
            UIScreen.mainScreen().brightness -= dtY / 10000
            dispatch_async(dispatch_get_main_queue(), { [unowned self] in
                self.horizontalLable.text = String(format: "亮度%.0f%%",UIScreen.mainScreen().brightness*100.0)
                self.horizontalLable.hidden = false
            })
        }
    }
    
    func panGestureEnded() {
        
        self.horizontalLable.hidden = true
        
        if panInfo.panDirection == .Horizontal {
            self.playerControl?.seekToProgress(panInfo.seekProgress)
        }
    }
    
    func durationStringWithTime(time: NSTimeInterval) -> String {
        
        if time.isNaN {
            return ""
        }
        
        let min = String(format: "%02d", Int(time / 60))
        let sec = String(format: "%02d", Int(time % 60))
        
        return min + ":" + sec
    }
}

//MARK:- 控制播放器
extension PlayerControlView
{
    
    func clickStartBtn(btn: PlayButton) {
        
        if btn.buttonState == .Paused {
            if let control = playerControl {
                control.play()
            }
        }else {
            if let control = playerControl {
                control.pause()
            }
        }
        
        btn.setButtonState(~btn.buttonState, animated: true)
    }
    
    func clickFullScreenBtn() {
        if let control = playerControl {
            control.switchFullScreen()
        }
    }
    
    func progressSliderTouchBegan(slider: UISlider) {
        
    }
    
    func progressSliderTouchEnd(slider: UISlider) {
        
    }
    
    func progressSliderValueChanged(slider: UISlider) {
        if let control = playerControl {
            control.seekToProgress(slider.value)
        }
    }
}
