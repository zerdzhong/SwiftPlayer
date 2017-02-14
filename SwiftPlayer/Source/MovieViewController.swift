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

        if videoURLString.contains("http") {
            playerView.videoURL = URL(string: videoURLString)
        }else {
            playerView.videoURL = URL(fileURLWithPath: videoURLString)
        }
        
////        if videoURLString.containsString("rmvb") || videoURLString.containsString("mkv") {
//        let glView = PlayerGLView(frame: self.view.bounds, fileURL: videoURLString)
//        glView.contentMode = .scaleAspectFit
//            self.view.addSubview(glView)
//            glView.play()
////        }
        
        refreshNavigationBarHidden(view.bounds.size)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        self.navigationController?.navigationBar.isHidden = false
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        refreshNavigationBarHidden(size)
    }
    
    deinit {
        playerView.destoryPlayer()
    }
    
    func refreshNavigationBarHidden(_ size: CGSize) {
        if size.height < size.width {
            navigationController?.navigationBar.isHidden = true
        }else {
            navigationController?.navigationBar.isHidden = false
        }
    }
    
}
