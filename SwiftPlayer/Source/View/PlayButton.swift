
//
//  PlayButton.swift
//  SwiftPlayer
//
//  Created by zhongzhendong on 16/3/25.
//  Copyright © 2016年 zhongzhendong. All rights reserved.
//

import UIKit

enum PlayButtonState: CGFloat {
    case paused = 1.0
    case playing = 0.0
}

prefix func ~(state: PlayButtonState) -> PlayButtonState {
    switch state {
    case .paused:
        return PlayButtonState.playing
    case .playing:
        return PlayButtonState.paused
    }
}

class PlayButton: UIControl {

    var buttonState = PlayButtonState.paused {
        didSet{
            setButtonState(buttonState, animated: false)
        }
    }
    
    override var tintColor: UIColor! {
        didSet{
            shapeLayer.fillColor = tintColor.cgColor
        }
    }
    
    fileprivate var shapeLayer = CAShapeLayer()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    func commonInit() {
        backgroundColor = UIColor.clear
        layer.addSublayer(shapeLayer)
        
        shapeLayer.fillColor = tintColor.cgColor
    }
    
    override func layoutSubviews() {
        shapeLayer.frame = bounds
        shapeLayer.path = shapePathWithState(buttonState)
        super.layoutSubviews()
    }
    
    func setButtonState(_ buttonState: PlayButtonState, animated: Bool) {
        if self.buttonState == buttonState {
            return
        }
        
        let beforeButtonState = self.buttonState
        self.buttonState = buttonState
        
        let morphAnimationKey = "morphAnimationKey"
        
        if animated {
            
            let timimgFunction = CAMediaTimingFunction(name:kCAMediaTimingFunctionEaseInEaseOut)
            
            let morphAnimation = CABasicAnimation(keyPath:"path")
            morphAnimation.timingFunction = timimgFunction
            
            morphAnimation.isRemovedOnCompletion = false
            morphAnimation.fillMode = kCAFillModeForwards
            
            morphAnimation.duration = 0.3
            morphAnimation.fromValue = shapePathWithState(beforeButtonState)
            morphAnimation.toValue = shapePathWithState(buttonState)
            
            shapeLayer.add(morphAnimation, forKey: morphAnimationKey)
        }else {
            shapeLayer.removeAnimation(forKey: morphAnimationKey)
            shapeLayer.path = shapePathWithState(buttonState)
        }
    }
    
    func shapePathWithState(_ buttonState: PlayButtonState) -> CGPath {
        
        let height = bounds.height
        let minWidth = bounds.width * 0.4
        
        let dtWidth = (bounds.width / 2.0 - minWidth) * buttonState.rawValue
        let width = minWidth + dtWidth
        
        let h1 = height / 4.0 * buttonState.rawValue
        let h2 = height / 2.0 * buttonState.rawValue
        
        let path = UIBezierPath()
        
        path.move(to: CGPoint(x: 0.0, y: 0.0))
        path.addLine(to: CGPoint(x: width, y: h1))
        path.addLine(to: CGPoint(x: width, y: height - h1))
        path.addLine(to: CGPoint(x: 0.0, y: height))
        path.close()
        
        path.move(to: CGPoint(x: bounds.width - width, y: h1))
        path.addLine(to: CGPoint(x: bounds.width, y: h2))
        path.addLine(to: CGPoint(x: bounds.width, y: height - h2))
        path.addLine(to: CGPoint(x: bounds.width - width, y: height - h1))
        path.close()
        
        return path.cgPath
    }
    
    deinit {
        print("PlayButton deinit")
    }
}
