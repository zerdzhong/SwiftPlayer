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
    
    override func viewDidLoad() {
        playerView.videoURL = videoURL
    }
    
}
