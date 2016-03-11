//
//  PlayerView.swift
//  SwiftPlayer
//
//  Created by zhongzhendong on 16/3/10.
//  Copyright © 2016年 zhongzhendong. All rights reserved.
//

import UIKit
import AVFoundation

typealias PlayerBackBlock = () -> ()

class PlayerView: UIView {
    
    var videoURL: NSURL? {
        didSet{
            if let url = videoURL {
                setupPlayer(url)
            }
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = UIColor.blackColor()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.backgroundColor = UIColor.blackColor()
    }
    
    //MARK:- private func
    
    func setupPlayer(url: NSURL!) {
        let playerItem = AVPlayerItem(URL: url)
        let player = AVPlayer(playerItem: playerItem)
        let playerLayer = AVPlayerLayer(player: player)
        
        layer.insertSublayer(playerLayer, atIndex: 0)
        player.play()
    }
}
