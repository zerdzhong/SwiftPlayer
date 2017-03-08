//
//  ViewController.swift
//  SwiftPlayer
//
//  Created by zhongzhendong on 16/3/10.
//  Copyright © 2016年 zhongzhendong. All rights reserved.
//

import UIKit

class ViewController: UITableViewController {
    
    var netDataSource: Array<String> = ["http://baobab.wdjcdn.com/14562919706254.mp4",
                                       "http://baobab.wdjcdn.com/1456117847747a_x264.mp4",
                                       "http://baobab.wdjcdn.com/14525705791193.mp4",
                                       "http://baobab.wdjcdn.com/1455968234865481297704.mp4",
                                       "http://baobab.wdjcdn.com/1455782903700jy.mp4",
                                       "http://baobab.wdjcdn.com/14564977406580.mp4"]
    
    
    var localDataSource: Array<String> = [Bundle.main.path(forResource: "150511_JiveBike", ofType: "mov")!,
                                          Bundle.main.path(forResource: "snsd", ofType: "mp4")!]

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(loadDocumentVideo))
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addRemoteVideo))
        
        loadDocumentVideo()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let movieVC = segue.destination as! MovieViewController
        let cell = sender as! UITableViewCell
        
        let indexPath = tableView.indexPath(for: cell)
        
        if indexPath!.section == 0 {
            let urlString = localDataSource[indexPath!.row]
            movieVC.videoURLString = urlString
        }else if indexPath!.section == 1 {
            let urlString = netDataSource[indexPath!.row]
            movieVC.videoURLString = urlString
        }
    }
    
    func addRemoteVideo() {
        
        let alert = UIAlertController(title: "输入视频URL", message: nil, preferredStyle: .alert)
        
        alert.addTextField(configurationHandler: { (textField) -> Void in
            textField.text = "http://"
        })
        
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (action) -> Void in
            let textField = alert.textFields![0] as UITextField
            print("Text field: \(textField.text)")

            if let urlString = textField.text {
                let url = URL(string: urlString)
                
                if url == nil {
                    return
                }
                
                if !self.netDataSource.contains(urlString) {
                    self.netDataSource.append(urlString)
                    self.tableView.reloadData()
                }
            }
        }))
        
        self.present(alert, animated: true, completion: nil)
    }
    
    func loadDocumentVideo() {
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true) as NSArray
        let documentsDir = paths.firstObject as! String
        
        do {
            let videos = try FileManager.default.contentsOfDirectory(atPath: documentsDir).flatMap { (itemString: String) -> String? in
                if itemString.contains("mp4")
                || itemString.contains("rmvb")
                || itemString.contains("mkv")
                    {
                    let itemPath = documentsDir + "/" + itemString
                    
                    return itemPath
                }else {
                    return nil
                }
            }
            
            videos.forEach({ (item: String) in
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
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if indexPath.section == 0 {
            print("本地视频,\(localDataSource[indexPath.row])")
        }else if indexPath.section == 1 {
            print("网络视频,\(netDataSource[indexPath.row])")
        }
    }
    
    //MARK:- UITableViewDataSource
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return (section == 0) ? "本地视频" : "网络视频"
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return (section == 0) ? localDataSource.count : netDataSource.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "videoCell")!
        if indexPath.section == 0 {
            cell.textLabel?.text = URL(fileURLWithPath: localDataSource[indexPath.row]).lastPathComponent
        }else if indexPath.section == 1 {
            cell.textLabel?.text = URL(string: netDataSource[indexPath.row])?.lastPathComponent
        }
        
        return cell
    }
}

