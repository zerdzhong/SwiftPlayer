//
//  MovieViewController.swift
//  SwiftPlayer
//
//  Created by zhongzhendong on 16/3/10.
//  Copyright © 2016年 zhongzhendong. All rights reserved.
//

import UIKit

class MovieViewController: UIViewController {
    
    @IBOutlet weak var playerContainer: UIView!
    var videoURLString: String = ""
    var player = PlayerEngine()
    var playerControlView = PlayerControlView()
    
    override func viewDidLoad() {
        
        player.startPlayer(url: videoURLString, decodeType: .software)
        player.delegate = self
        
        if let playerView = player.playerView {
            playerContainer.addSubview(playerView)
            playerView.snp.makeConstraints({ (make) in
                make.edges.equalTo(playerContainer)
            })
        }
        
        
        playerControlView.playerControl = player
        playerControlView.playerItemInfo = player
        playerContainer.addSubview(playerControlView)
        
        playerControlView.snp.makeConstraints { (make) in
            make.edges.equalTo(playerContainer)
        }
        
        refreshNavigationBarHidden(view.bounds.size)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        self.navigationController?.navigationBar.isHidden = false
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        refreshNavigationBarHidden(size)
    }
    
    deinit {
        player.destoryPlayer()
    }
    
    func refreshNavigationBarHidden(_ size: CGSize) {
        if size.height < size.width {
            navigationController?.navigationBar.isHidden = true
        }else {
            navigationController?.navigationBar.isHidden = false
        }
    }
    
}

extension MovieViewController: PlayerCallbackDelegate {
    func playerReadPlay() {
        
    }
    func playerLoadFailed() {
        
    }
    func playerBufferEmpty() {
        
    }
    func playerKeepToPlay() {
        
    }
    func playerPlayEnd(reason: PlayerEndReason) {
        
    }
    func playerObserver() {
        
        guard player.duration != 0 && !player.duration.isNaN else {
            return
        }
        
        let timeProgress = player.currentTime / player.duration
        
        playerControlView.videoSlider.maximumValue = 1
        playerControlView.videoSlider.value = Float(timeProgress)
        
        let currentMin = player.currentTime / 60
        let currentSec = player.currentTime.truncatingRemainder(dividingBy: 60)
        
        playerControlView.currentTimeLabel.text = String(format: "%02ld:%02ld", Int(currentMin), Int(currentSec))
        
        let totalMin = player.duration / 60
        let totalSec = player.duration.truncatingRemainder(dividingBy: 60)
        
        playerControlView.totalTimeLabel.text = String(format: "%02ld:%02ld", Int(totalMin), Int(totalSec))
    }
}
