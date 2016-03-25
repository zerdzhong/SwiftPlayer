
//
//  PlayButton.swift
//  SwiftPlayer
//
//  Created by zhongzhendong on 16/3/25.
//  Copyright © 2016年 zhongzhendong. All rights reserved.
//

import UIKit

enum PlayButtonState: CGFloat {
    case Paused = 1.0
    case Playing = 0.0
}

prefix func ~(state: PlayButtonState) -> PlayButtonState {
    switch state {
    case .Paused:
        return PlayButtonState.Playing
    case .Playing:
        return PlayButtonState.Paused
    }
}

class PlayButton: UIControl {

    var buttonState = PlayButtonState.Paused
    
    override var tintColor: UIColor! {
        didSet{
            shapeLayer.fillColor = tintColor.CGColor
        }
    }
    
    
    private var shapeLayer = CAShapeLayer()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    func commonInit() {
        backgroundColor = UIColor.clearColor()
        layer.addSublayer(shapeLayer)
        
        shapeLayer.fillColor = tintColor.CGColor
    }
    
    override func layoutSubviews() {
        shapeLayer.frame = bounds
        shapeLayer.path = shapePathWithButtonState(buttonState)
        super.layoutSubviews()
    }
    
    func setButtonState(buttonState: PlayButtonState, animated: Bool) {
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
            
            morphAnimation.removedOnCompletion = false
            morphAnimation.fillMode = kCAFillModeForwards
            
            morphAnimation.duration = 0.3
            morphAnimation.fromValue = shapePathWithButtonState(beforeButtonState)
            morphAnimation.toValue = shapePathWithButtonState(buttonState)
            
            shapeLayer.addAnimation(morphAnimation, forKey: morphAnimationKey)
        }else {
            shapeLayer.removeAnimationForKey(morphAnimationKey)
            shapeLayer.path = shapePathWithButtonState(buttonState)
        }
    }
    
    func shapePathWithButtonState(buttonState: PlayButtonState) -> CGPath{
        
        let height = bounds.height
        let minWidth = bounds.width * 0.32
        
        let dtWidth = (bounds.width / 2.0 - minWidth) * buttonState.rawValue
        let width = minWidth + dtWidth
        
        let h1 = height / 4.0 * buttonState.rawValue
        let h2 = height / 2.0 * buttonState.rawValue
        
        let path = UIBezierPath()
        
        path.moveToPoint(CGPointMake(0.0, 0.0))
        path.addLineToPoint(CGPointMake(width, h1))
        path.addLineToPoint(CGPointMake(width, height - h1))
        path.addLineToPoint(CGPointMake(0.0, height))
        path.closePath()
        
        path.moveToPoint(CGPointMake(bounds.width - width, h1))
        path.addLineToPoint(CGPointMake(bounds.width, h2))
        path.addLineToPoint(CGPointMake(bounds.width, height - h2))
        path.addLineToPoint(CGPointMake(bounds.width - width, height - h1))
        path.closePath()
        
        return path.CGPath
    }
}
