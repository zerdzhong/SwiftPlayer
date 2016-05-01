//
//  MovieViewController.swift
//  SwiftPlayer
//
//  Created by zhongzhendong on 16/3/10.
//  Copyright © 2016年 zhongzhendong. All rights reserved.
//

import UIKit

class MovieViewController: UIViewController {
    
    @IBOutlet weak var playerView: PlayerView!
    var videoURLString: String = ""
    
    override func viewDidLoad() {
        if videoURLString.containsString("http") {
            playerView.videoURL = NSURL(string: videoURLString)
        }else {
            playerView.videoURL = NSURL(fileURLWithPath: videoURLString)
        }
        
        if videoURLString.containsString("rmvb") {
            do {
                let decoder = PlayerDecoder()
                try decoder.openFile(videoURLString)
                
                decoder.asyncDecodeFrames(0.1)
            } catch {
                print("error")
            }
        }
        
        refreshNavigationBarHidden(view.bounds.size)
    }
    
    override func viewWillDisappear(animated: Bool) {
        self.navigationController?.navigationBar.hidden = false
    }
    
    override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        refreshNavigationBarHidden(size)
    }
    
    deinit {
        playerView.destoryPlayer()
    }
    
    func refreshNavigationBarHidden(size: CGSize) {
        if size.height < size.width {
            navigationController?.navigationBar.hidden = true
        }else {
            navigationController?.navigationBar.hidden = false
        }
    }
    
}
