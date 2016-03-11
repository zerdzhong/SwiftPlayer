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
            startPlayer()
        }
    }
    
    internal lazy var player: AVPlayer? = {
        if let videoURL = self.videoURL {
            let playerItem = AVPlayerItem(URL: videoURL)
            let player = AVPlayer(playerItem: playerItem)
            
            return player
        }else {
            return nil
        }
    }()
    
    internal lazy var playerLayer: AVPlayerLayer? = {
        if let player = self.player{
            let playerLayer = AVPlayerLayer(player: player)
            return playerLayer
        }else {
            return nil
        }
    }()
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if let playerLayer = playerLayer {
            playerLayer.frame = self.bounds
        }
    }
    
    //MARK:- private func
    
    func startPlayer() {
        if let playerLayer = playerLayer, let player = player {
            layer.addSublayer(playerLayer)
            player.play()
            
            NSNotificationCenter.defaultCenter().addObserver(self, selector: "videoDidPlayEnd:", name: AVPlayerItemDidPlayToEndTimeNotification, object: nil)
        }
    }
}

extension PlayerView {
    internal func videoDidPlayEnd(noti :NSNotification) {
        
    }
}
