//
//  SongListViewController.swift
//  AudioReverser
//
//  Created by Chris Adamson on 2/15/17.
//  Copyright © 2017 Subsequently & Furthermore, Inc. All rights reserved.
//

import UIKit

class SongListViewController: UITableViewController {

    var detailViewController: ReversedPlayerViewController? = nil
    var songs: [SongFile] = []


    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

        do {
            try loadDocuments()
        } catch let error {
            NSLog ("failed to load documents: \(error)")
        }
        
        if let split = self.splitViewController {
            let controllers = split.viewControllers
            self.detailViewController = (controllers[controllers.count-1] as! UINavigationController).topViewController as? ReversedPlayerViewController
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        self.clearsSelectionOnViewWillAppear = self.splitViewController!.isCollapsed
        super.viewWillAppear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Segues

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let destNav = segue.destination as? UINavigationController,
            let playerVC = destNav.topViewController as? ReversedPlayerViewController {
            if let indexPath = self.tableView.indexPathForSelectedRow {
                let songFile = songs[indexPath.row]
                playerVC.songFile = songFile
            }
        }
    }

    // MARK: - Table View

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return songs.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SongCell", for: indexPath)

        let song = songs[indexPath.row]
        cell.textLabel?.text = song.title
        cell.detailTextLabel?.text = song.artist
        if let albumArt = song.albumArt {
            cell.imageView?.image = albumArt
        }
        return cell
    }

    // MARK: - utils
    private func loadDocuments() throws {
        let fileManager = FileManager.default
        let docDirURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        NSLog ("documents dir at: \(docDirURL)")
        
        let contents = try fileManager.contentsOfDirectory(atPath: docDirURL.path)
        for fileName in contents {
            let file = docDirURL.appendingPathComponent(fileName)
            if let songFile = SongFile(fileURL: file) {
                songs.append(songFile)
            }
        }
    }
    
}

