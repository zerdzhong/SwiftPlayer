//
//  ViewController.swift
//  SwiftPlayer
//
//  Created by zhongzhendong on 16/3/10.
//  Copyright © 2016年 zhongzhendong. All rights reserved.
//

import UIKit

class ViewController: UITableViewController {
    
    var netDataSource: Array<NSURL>! = [NSURL(string: "http://baobab.wdjcdn.com/14562919706254.mp4")!,
                                       NSURL(string: "http://baobab.wdjcdn.com/1456117847747a_x264.mp4")!,
                                       NSURL(string: "http://baobab.wdjcdn.com/14525705791193.mp4")!,
                                       NSURL(string: "http://baobab.wdjcdn.com/1456459181808howtoloseweight_x264.mp4")!,
                                       NSURL(string: "http://baobab.wdjcdn.com/1455968234865481297704.mp4")!,
                                       NSURL(string: "http://baobab.wdjcdn.com/1455782903700jy.mp4")!,
                                       NSURL(string: "http://baobab.wdjcdn.com/14564977406580.mp4")!]
    
    var localDataSource: Array<NSURL>! = [NSBundle.mainBundle().URLForResource("150511_JiveBike", withExtension: "mov")!]

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Refresh, target: self, action: #selector(ViewController.loadDocumentVideo))
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Add, target: self, action: #selector(ViewController.addRemoteVideo))
        
        loadDocumentVideo()
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
            let url = netDataSource[indexPath!.row]
            movieVC.videoURL = url
        }
    }
    
    func addRemoteVideo() {
        
        let alert = UIAlertController(title: "输入视频URL", message: nil, preferredStyle: .Alert)
        
        alert.addTextFieldWithConfigurationHandler({ (textField) -> Void in
            textField.text = "http://"
        })
        
        alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: { (action) -> Void in
            let textField = alert.textFields![0] as UITextField
            print("Text field: \(textField.text)")
            if let urlString = textField.text,let url = NSURL(string: urlString) {
                if !self.netDataSource.contains(url) {
                    self.netDataSource.append(url)
                    self.tableView.reloadData()
                }
            }
        }))
        
        self.presentViewController(alert, animated: true, completion: nil)
    }
    
    func loadDocumentVideo() {
        let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true) as NSArray
        let documentsDir = paths.firstObject as! String
        
        do {
            let videos = try NSFileManager.defaultManager().contentsOfDirectoryAtPath(documentsDir).flatMap { (itemString: String) -> NSURL? in
                if itemString.containsString("mp4") {
                    let itemPath = documentsDir + "/" + itemString
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

extension ViewController
{
    
    //MARL:- UITableViewDelegate
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        
        if indexPath.section == 0 {
            print("本地视频,\(localDataSource[indexPath.row])")
        }else if indexPath.section == 1 {
            print("网络视频,\(netDataSource[indexPath.row])")
        }
    }
    
    //MARK:- UITableViewDataSource
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 2
    }
    
    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return (section == 0) ? "本地视频" : "网络视频"
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return (section == 0) ? localDataSource.count : netDataSource.count
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("videoCell")!
        if indexPath.section == 0 {
            cell.textLabel?.text = localDataSource[indexPath.row].lastPathComponent
        }else if indexPath.section == 1 {
            cell.textLabel?.text = netDataSource[indexPath.row].lastPathComponent
        }
        
        return cell
    }
}

