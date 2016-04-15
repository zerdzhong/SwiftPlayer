//
//  ViewController.swift
//  SwiftPlayer
//
//  Created by zhongzhendong on 16/3/10.
//  Copyright © 2016年 zhongzhendong. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    
    var netDataSource: Array<String>!
    var localDataSource: Array<NSURL>!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        navigationController?.interactivePopGestureRecognizer?.enabled = true
        
        netDataSource = ["http://baobab.wdjcdn.com/14562919706254.mp4",
                      "http://baobab.wdjcdn.com/1456117847747a_x264.mp4",
                      "http://baobab.wdjcdn.com/14525705791193.mp4",
                      "http://baobab.wdjcdn.com/1456459181808howtoloseweight_x264.mp4",
                      "http://baobab.wdjcdn.com/1455968234865481297704.mp4",
                      "http://baobab.wdjcdn.com/1455782903700jy.mp4",
                      "http://baobab.wdjcdn.com/14564977406580.mp4"]
        
        
        localDataSource = Array<NSURL>()
        localDataSource.append(NSBundle.mainBundle().URLForResource("150511_JiveBike", withExtension: "mov")!)
        loadDocumentVideo()
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Refresh, target: self, action: #selector(ViewController.loadDocumentVideo))
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        let movieVC = segue.destinationViewController as! MovieViewController
        let cell = sender as! UITableViewCell
        
        let indexPath = tableView.indexPathForCell(cell)
        
        if indexPath!.section == 0 {
            let url = localDataSource[indexPath!.row]
            movieVC.videoURL = url
        }else if indexPath!.section == 1 {
            let url = NSURL(string: netDataSource[indexPath!.row])
            movieVC.videoURL = url
        }
    }
    
    func loadDocumentVideo() {
        let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true) as NSArray
        let documentsDir = paths.firstObject as! String
        
        do {
            let videos = try NSFileManager.defaultManager().contentsOfDirectoryAtPath(documentsDir).flatMap { (itemString: String) -> NSURL? in
                if itemString.containsString("mp4") {
                    let itemPath = documentsDir + itemString
                    return NSURL(fileURLWithPath: itemPath)
                }else {
                    return nil
                }
            }
            
            videos.forEach({ (item: NSURL) in
                if !localDataSource.contains(item) {
                    localDataSource.append(item)
                }
            })
            
            tableView.reloadData()
        } catch let error as NSError {
            print(error)
        }
        
    }
}

extension ViewController: UITableViewDelegate, UITableViewDataSource
{
    //MARL:- UITableViewDelegate
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        
        if indexPath.section == 0 {
            print("本地视频,\(localDataSource[indexPath.row])")
        }else if indexPath.section == 1 {
            print("网络视频,\(netDataSource[indexPath.row])")
        }
    }
    
    //MARK:- UITableViewDataSource
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return (section == 0) ? "本地视频" : "网络视频"
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return (section == 0) ? localDataSource.count : netDataSource.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell: UITableViewCell!
        if indexPath.section == 0 {
            cell = tableView.dequeueReusableCellWithIdentifier("localVideoCell")
            cell.textLabel?.text = localDataSource[indexPath.row].lastPathComponent
        }else if indexPath.section == 1 {
            cell = tableView.dequeueReusableCellWithIdentifier("netVideoCell")
        }
        
        return cell
    }
}

