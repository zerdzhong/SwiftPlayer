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
    case horizontal
    case vertical
}

struct PlayerPanInfo {
    var startPoint: CGPoint = CGPoint.zero
    var panDirection: PlayerPanDirection = .horizontal
    var changedTime: TimeInterval = 0.0
    var seekProgress: Float = 0.0
}

class PlayerControlView: UIView {
    
    var playerControl: PlayerControllable?
    var playerItemInfo: PlayerItemInfo?
    
    var videoSlider = UISlider()
    
    var startBtn = PlayButton()
    var lockBtn = UIButton()
    var fullScreenBtn = UIButton()
    var currentTimeLabel = UILabel()
    var totalTimeLabel = UILabel()
    var progressView = UIProgressView()
    
    lazy var horizontalLable: UILabel = {
       let tempLabel = UILabel()
        tempLabel.backgroundColor = UIColor.black
        tempLabel.isHidden = true
        tempLabel.textColor = UIColor.white
        
        return tempLabel
    }()
    
    lazy var bottomView: UIView = {
        let tempView = UIView()
        tempView.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.5)
        
        let bottomLayer = CAGradientLayer()
        bottomLayer.startPoint = CGPoint.zero
        bottomLayer.endPoint = CGPoint(x: 0,y: 1)
        bottomLayer.colors = [UIColor.clear.cgColor,UIColor.black.cgColor]
        bottomLayer.locations = [0.0,1.0]
        
        tempView.layer.addSublayer(bottomLayer)
        return tempView
    }()
    
    lazy var topView : UIView = {
        let tempView = UIView()
        tempView.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.5)
        
        let topLayer = CAGradientLayer()
        topLayer.startPoint = CGPoint(x: 1,y: 0)
        topLayer.endPoint = CGPoint(x: 1,y: 1)
        topLayer.colors = [UIColor.black.cgColor,UIColor.clear.cgColor]
        topLayer.locations = [0.0,1.0]
        
        tempView.layer.addSublayer(topLayer)
        
        return tempView
    }()
    
    var panInfo = PlayerPanInfo()
    
    fileprivate let delayHiddenTime = 4.0
    
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
    fileprivate func commonInit() {
        
        addSubview(horizontalLable)
        horizontalLable.snp.makeConstraints { (make) in
            make.center.equalTo(self)
        }
        
        addSubview(bottomView)
        bottomView.snp.makeConstraints { (make) -> Void in
            make.bottom.right.left.equalTo(self)
            make.height.equalTo(45)
        }
        
        addSubview(topView)
        topView.snp.makeConstraints { (make) -> Void in
            make.top.left.right.equalTo(self)
            make.height.equalTo(50)
        }
        
        startBtn.addTarget(self, action: #selector(PlayerControlView.clickStartBtn(_:)), for: .touchUpInside)
        startBtn.tintColor = UIColor.white
        startBtn.buttonState = .playing
        bottomView.addSubview(startBtn)
        startBtn.snp.makeConstraints { (make) -> Void in
            make.width.height.equalTo(15)
            make.left.equalTo(bottomView).offset(10)
            make.centerY.equalTo(bottomView)
        }
        
        currentTimeLabel.text = "00:00"
        currentTimeLabel.textColor = UIColor.white
        currentTimeLabel.font = UIFont.systemFont(ofSize: 12)
        bottomView.addSubview(currentTimeLabel)
        
        currentTimeLabel.snp.makeConstraints { (make) -> Void in
            make.centerY.equalTo(bottomView)
            make.left.equalTo(startBtn.snp.right).offset(5)
        }
        
        fullScreenBtn.setImage(UIImage(named: "kr-video-player-fullscreen"), for: UIControlState())
        fullScreenBtn.addTarget(self, action: #selector(PlayerControlView.clickFullScreenBtn), for: .touchUpInside)
        bottomView.addSubview(fullScreenBtn)
        fullScreenBtn.snp.makeConstraints { (make) -> Void in
            make.width.height.equalTo(30)
            make.right.equalTo(bottomView).offset(-10)
            make.centerY.equalTo(bottomView)
        }
        
        totalTimeLabel.text = "00:00"
        totalTimeLabel.textColor = UIColor.white
        totalTimeLabel.font = UIFont.systemFont(ofSize: 12)
        bottomView.addSubview(totalTimeLabel)
        totalTimeLabel.snp.makeConstraints { (make) -> Void in
            make.right.equalTo(fullScreenBtn.snp.left).offset(-2)
            make.centerY.equalTo(bottomView)
        }
        
        progressView.progressTintColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.3)
        progressView.trackTintColor = UIColor.clear
        bottomView.addSubview(progressView)
        
        progressView.snp.makeConstraints { (make) -> Void in
            make.left.equalTo(currentTimeLabel.snp.right).offset(10)
            make.right.equalTo(totalTimeLabel.snp.left).offset(-10)
            make.centerY.equalTo(bottomView)
        }
        
        videoSlider.setThumbImage(UIImage(named: "slider"), for: UIControlState())
        videoSlider.minimumTrackTintColor = UIColor.white
        videoSlider.maximumTrackTintColor = UIColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 0.3)
        
        videoSlider.addTarget(self, action: #selector(PlayerControlView.progressSliderTouchBegan(_:)), for: .touchDown)
        videoSlider.addTarget(self, action: #selector(PlayerControlView.progressSliderValueChanged(_:)), for: .valueChanged)
        videoSlider.addTarget(self, action: #selector(PlayerControlView.progressSliderTouchEnd(_:)), for: .touchUpInside)
        
        bottomView.addSubview(videoSlider)
        videoSlider.snp.makeConstraints { (make) -> Void in
            make.left.right.equalTo(progressView)
            make.centerY.equalTo(bottomView)
        }
        
        addDouleTapGesture()
        showControlView()
    }
    
    func dismissControlView() {
        print("control view dismiss")
        self.bottomView.isHidden = true
        self.topView.isHidden = true
    }
    
    func cancelDismissControlView() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(dismissControlView), object: nil)
    }
    
    func showControlView(delayDismiss isDelay: Bool = true) {
        self.bottomView.isHidden = false
        self.topView.isHidden = false
        
        if isDelay {
            perform(#selector(dismissControlView), with: nil, afterDelay: delayHiddenTime)
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
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
    
    internal func doubleTapGestureHandler(_ tapGes: UITapGestureRecognizer) {
        print("double taped")
        clickStartBtn(startBtn)
        switch tapGes.state {
        case .began:
            showControlView(delayDismiss: false)
        case .ended, .cancelled, .failed:
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
    
    func panGestureHandler(_ panGes: UIPanGestureRecognizer) {
        
        let point = panGes.location(in: self)
        let velocity = panGes.velocity(in: self)
        
        switch panGes.state {
        case .began:
            showControlView(delayDismiss: false)
            
            if fabs(velocity.x) > fabs(velocity.y) {
                panInfo.panDirection = .horizontal
            }else {
                panInfo.panDirection = .vertical
            }
            
            panInfo.startPoint = point
        case .changed:
            switch panInfo.panDirection {
            case .horizontal:
                horizontalMoved(velocity.x)
            case .vertical:
                verticalMoved(velocity.y)
            }
        case .ended:
            showControlView()
            panGestureEnded()
        default:
            break;
        }
    }
    
    func horizontalMoved(_ dtX :CGFloat) {
        
        let videoTotalTime = playerItemInfo?.duration
        let videoCurrenTime = playerItemInfo?.currentTime
        
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
            
            DispatchQueue.main.async(execute: { [unowned self] in
                self.horizontalLable.text = style + " " + self.durationStringWithTime(destinationTime) + "/" + self.durationStringWithTime(totalTime)
                self.horizontalLable.isHidden = false
                
                self.panInfo.seekProgress = Float(destinationTime/totalTime)
            })
        }
    }
    
    func verticalMoved(_ dtY: CGFloat)  {
        
        if panInfo.startPoint.x > bounds.size.width / 2 {
            //音量
            MPMusicPlayerController.applicationMusicPlayer()
            let volumeView = MPVolumeView()
            for view in volumeView.subviews {
                if let slider = view as? UISlider{
                    if type(of: slider).description() == "MPVolumeSlider" {
                        slider.value -= Float(dtY / 10000)
                    }
                }
            }
        }else {
            //亮度
            UIScreen.main.brightness -= dtY / 10000
            DispatchQueue.main.async(execute: { [unowned self] in
                self.horizontalLable.text = String(format: "亮度%.0f%%",UIScreen.main.brightness*100.0)
                self.horizontalLable.isHidden = false
            })
        }
    }
    
    func panGestureEnded() {
        
        self.horizontalLable.isHidden = true
        
        if panInfo.panDirection == .horizontal {
            self.playerControl?.seekTo(progress:panInfo.seekProgress)
        }
    }
    
    func durationStringWithTime(_ time: TimeInterval) -> String {
        
        if time.isNaN {
            return ""
        }
        
        let min = String(format: "%02d", Int(time / 60))
        let sec = String(format: "%02d", Int(time.truncatingRemainder(dividingBy: 60)))
        
        return min + ":" + sec
    }
}

//MARK:- 控制播放器
extension PlayerControlView
{
    
    func clickStartBtn(_ btn: PlayButton) {
        
        if btn.buttonState == .paused {
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
    
    func progressSliderTouchBegan(_ slider: UISlider) {
        
    }
    
    func progressSliderTouchEnd(_ slider: UISlider) {
        
    }
    
    func progressSliderValueChanged(_ slider: UISlider) {
        if let control = playerControl {
            control.seekTo(progress:slider.value)
        }
    }
}
