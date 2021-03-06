//
//  ATableViewController.swift
//
//  Created by Arnaud Dorgans on 03/08/2017.
//  Copyright © 2017 AListViewController (https://github.com/Arnoymous/AListViewController)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import UIKit

open class ATableViewController: AListViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet open var tableView: UITableView!
    private var configureCell: ((IndexPath,Any,UITableViewCell) -> Void)!
    
    public var rowAnimation: (delete: UITableViewRowAnimation, insert: UITableViewRowAnimation, reload: UITableViewRowAnimation) {
        get {return _rowAnimation}
        set {_rowAnimation = newValue}
    }

    public func configure(cellIdentifier: @escaping (IndexPath, Any) -> String,
                    cellUpdate: @escaping (IndexPath,Any,UITableViewCell) -> Void,
                    cellHeight: ((IndexPath, Any) -> CGFloat)? = nil,
                    sourceObjects: @escaping ((@escaping ([[Any]], Bool) -> Void) -> Void),
                    didSelectCell: ((IndexPath, Any) -> Void)? = nil) {
        self.configureCell = cellUpdate
        var cellSize: ((IndexPath, Any) -> CGSize)?
        if let cellHeight = cellHeight {
            cellSize = { indexPath,object in
                return CGSize(width:0,height:cellHeight(indexPath,object))
            }
        }
        super.configure(cellIdentifier: cellIdentifier, cellSize: cellSize, sourceObjects: sourceObjects, didSelectCell: didSelectCell)
    }
    
    open func customizeTableView(_ tableView: UITableView) { }
    
    override func customizeScrollView(_ scrollView: UIScrollView) {
        self.customizeTableView(tableView)
    }
    
    open override func viewDidLoad() {
        if let tableView = tableView {
            self.scrollView = tableView
        } else {
            fatalError("tableView need to be set before super.viewDidLoad()")
        }
        if configureCell == nil {
            fatalError("configureCell need to be set programatically before super.viewDidLoad()")
        }
        super.viewDidLoad()
        self.tableView.delegate = self
        self.tableView.dataSource = self
    }
    
    public func numberOfSections(in tableView: UITableView) -> Int {
        return numberOfSections
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return numberOfItems(inSection: section)
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        didSelectCell?(indexPath,object(atIndexPath: indexPath))
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier(atIndexPath: indexPath), for: indexPath)
        configureCell(indexPath,object(atIndexPath: indexPath),cell)
        return cell
    }
    
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return self.configureCellSize?(indexPath,object(atIndexPath: indexPath)).height ?? self.tableView.rowHeight
    }
    
    deinit {
        self.tableView = nil
        self.configureCell = nil
    }
}
