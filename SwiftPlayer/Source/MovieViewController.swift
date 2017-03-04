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
    
    override func viewDidLoad() {
        
        player.startPlayer(url: videoURLString, decodeType: .hardware)
        player.delegate = self
        
        if let playerView = player.playerView {
            playerContainer.addSubview(playerView)
            playerView.snp.makeConstraints({ (make) in
                make.edges.equalTo(playerContainer)
            })
        }
        
        let controllView = PlayerControlView()
        controllView.playerControl = player
        controllView.playerItemInfo = player
        playerContainer.addSubview(controllView)
        
        controllView.snp.makeConstraints { (make) in
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

extension MovieViewController: PlayerCallback {
    func player_playStart() {
        
    }
    func player_playFinish() {
        
    }
    func player_playFailed() {
        
    }
    func player_play() {
        
    }
    func player_pause() {
        
    }
    func player_stop() {
        
    }
    func player_seekTo(time: TimeInterval) {
        
    }
    func player_seek(fromTime: TimeInterval, loadedTime: TimeInterval, toTime: TimeInterval) {
        
    }
}
