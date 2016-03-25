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
    var videoURL: NSURL?
    var playButton = PlayButton()
    
    override func viewDidLoad() {
        playerView.videoURL = videoURL
        refreshNavigationBarHidden(view.bounds.size)
    }
    
    override func viewWillDisappear(animated: Bool) {
        self.navigationController?.navigationBar.hidden = false
    }
    
    override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        refreshNavigationBarHidden(size)
    }
    
    func refreshNavigationBarHidden(size: CGSize) {
        if size.height < size.width {
            navigationController?.navigationBar.hidden = true
        }else {
            navigationController?.navigationBar.hidden = false
        }
    }
    
}
