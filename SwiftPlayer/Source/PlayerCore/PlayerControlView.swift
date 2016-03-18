//
//  PlayerControlView.swift
//  SwiftPlayer
//
//  Created by zhongzhendong on 16/3/16.
//  Copyright © 2016年 zhongzhendong. All rights reserved.
//

import UIKit
import SnapKit

class PlayerControlView: UIView {
    
    weak var playerControl: PlayerControlInterface?
    
    var videoSlider = UISlider()
    
    var startBtn = UIButton()
    var lockBtn = UIButton()
    var fullScreenBtn = UIButton()
    var currentTimeLabel = UILabel()
    var totalTimeLabel = UILabel()
    var progressView = UIProgressView()
    
    lazy var bottomView: UIView = {
        let tempView = UIView()
        
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
        
        let topLayer = CAGradientLayer()
        topLayer.startPoint = CGPointMake(1,0)
        topLayer.endPoint = CGPointMake(1,1)
        topLayer.colors = [UIColor.blackColor().CGColor,UIColor.clearColor().CGColor]
        topLayer.locations = [0.0,1.0]
        
        tempView.layer.addSublayer(topLayer)
        
        return tempView
    }()
    
    //MARK:- life cycle
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        for subLayer in topView.layer.sublayers! {
            subLayer.frame = topView.bounds
        }
        
        for subLayer in bottomView.layer.sublayers! {
            subLayer.frame = bottomView.bounds
        }
    }
    
    //MARK:- commonInit
    private func commonInit() {
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
        
        startBtn.setImage(UIImage(named: "kr-video-player-pause"), forState: .Normal)
        startBtn.addTarget(self, action: "clickStartBtn:", forControlEvents: .TouchUpInside)
        bottomView.addSubview(startBtn)
        startBtn.snp_makeConstraints { (make) -> Void in
            make.width.height.equalTo(30)
            make.left.equalTo(bottomView).offset(10)
            make.centerY.equalTo(bottomView)
        }
        
        currentTimeLabel.text = "00:00"
        currentTimeLabel.textColor = UIColor.whiteColor()
        currentTimeLabel.font = UIFont.systemFontOfSize(12)
        bottomView.addSubview(currentTimeLabel)
        
        currentTimeLabel.snp_makeConstraints { (make) -> Void in
            make.centerY.equalTo(bottomView)
            make.left.equalTo(startBtn.snp_right).offset(2)
        }
        
        fullScreenBtn.setImage(UIImage(named: "kr-video-player-fullscreen"), forState: .Normal)
        fullScreenBtn.addTarget(self, action: "clickFullScreenBtn", forControlEvents: .TouchUpInside)
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
        
        videoSlider.addTarget(self, action: "progressSliderTouchBegan:", forControlEvents: .TouchDown)
        videoSlider.addTarget(self, action: "progressSliderValueChanged:", forControlEvents: .ValueChanged)
        videoSlider.addTarget(self, action: "progressSliderTouchEnd:", forControlEvents: .TouchUpInside)
        
        bottomView.addSubview(videoSlider)
        videoSlider.snp_makeConstraints { (make) -> Void in
            make.left.right.equalTo(progressView)
            make.centerY.equalTo(bottomView)
        }

    }
}

extension PlayerControlView
{
    
    func clickStartBtn(btn: UIButton) {
        
        if btn.selected {
            if let control = playerControl {
                control.play()
            }
            
            btn.setImage(UIImage(named: "kr-video-player-pause"), forState: .Normal)
        }else {
            if let control = playerControl {
                control.pause()
            }
            
            btn.setImage(UIImage(named: "kr-video-player-play"), forState: .Normal)
        }
        
        btn.selected = !btn.selected
        
    }
    
    func clickFullScreenBtn() {
        
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
