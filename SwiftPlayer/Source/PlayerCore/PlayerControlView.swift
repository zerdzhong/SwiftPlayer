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
    
    var videoSlider = UISlider()
    
    var startBtn = UIButton()
    var lockBtn = UIButton()
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
        topLayer.colors = [UIColor.clearColor().CGColor,UIColor.blackColor().CGColor]
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
    }
}
