//
//  AListViewController.swift
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
#if ALISTVIEWCONTROLLER_PULL || ALISTVIEWCONTROLLER_INFINITESCROLLING
    import ESPullToRefresh
#endif

typealias ListView = UIScrollView

open class AListViewController: UIViewController {
    
    internal var scrollView: ListView!
    internal var configureCellIdentifier: ((IndexPath,Any)->String)!
    internal var fetchSourceObjects: ((@escaping([[Any]],Bool) -> Void) -> Void)!
    internal var didSelectCell: ((IndexPath,Any) -> Void)?
    
    public var fetchSourceObjectsOnViewDidLoad: Bool = true
    public var rowAnimationEnabled: Bool = true
    
    internal var configureCellSize: ((IndexPath,Any)->CGSize)?

    open private (set) var isLoading: Bool = false
    private var isLoadingMore: Bool = false
    
    #if ALISTVIEWCONTROLLER_PULL
        public var pullToRefreshEnabled: Bool = false
    #endif
    
    #if ALISTVIEWCONTROLLER_INFINITESCROLLING
        public var infiniteScrollingEnabled: Bool = false
    #endif
    
    #if ALISTVIEWCONTROLLER_PULL || ALISTVIEWCONTROLLER_INFINITESCROLLING
        private var initRefresh: Bool = false
    #endif
    
    open private (set) var sourceObjects = [[Any]]()
    
    internal var _tableView: UITableView? {
        return scrollView as? UITableView
    }
    internal var _collectionView: UICollectionView? {
        return scrollView as? UICollectionView
    }
    
    internal var _rowAnimation: (delete:UITableViewRowAnimation,
        insert:UITableViewRowAnimation,
        reload:UITableViewRowAnimation) = (.fade,.top,.fade)
    
    public init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    #if ALISTVIEWCONTROLLER_PULL
    open func addPullToRefresh(_ animator: ESRefreshProtocol & ESRefreshAnimatorProtocol) {
        self.scrollView.es_addPullToRefresh(animator: animator) { [weak self] in
            self?.refreshData()
        }
    }
    #endif
    #if ALISTVIEWCONTROLLER_INFINITESCROLLING
    open func addInfiniteScrolling(_ animator: ESRefreshProtocol & ESRefreshAnimatorProtocol) {
        self.scrollView.es_addInfiniteScrolling(animator: animator) { [weak self] in
            if let _self = self, !_self.isLoading {
                _self.isLoadingMore = true
                _self.refreshData(reload: false)
            }
        }
    }
    #endif
    
    internal func customizeScrollView(_ scrollView: UIScrollView) { }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        if configureCellIdentifier == nil {
            fatalError("configureCellIdentifier need to be set programatically before super.viewDidLoad()")
        }
        if fetchSourceObjects == nil {
            fatalError("fetchSourceObjects need to be set programatically before super.viewDidLoad()")
        }
        if scrollView == nil {
            fatalError("scrollView need to be set programatically before super.viewDidLoad()")
        }
        self.customizeScrollView(self.scrollView)
        
        if fetchSourceObjectsOnViewDidLoad {
            self.refreshData(reload: true, immediately: true)
        }
    }
    
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        #if ALISTVIEWCONTROLLER_PULL || ALISTVIEWCONTROLLER_INFINITESCROLLING
            if !initRefresh {
                initRefresh = true
                #if ALISTVIEWCONTROLLER_PULL
                    if pullToRefreshEnabled {
                        self.addPullToRefresh(ESRefreshHeaderAnimator())
                    }
                #endif
                #if ALISTVIEWCONTROLLER_INFINITESCROLLING
                    if infiniteScrollingEnabled {
                        self.addInfiniteScrolling(ESRefreshFooterAnimator())
                    }
                #endif
            }
        #endif
    }
    
    internal func configure(cellIdentifier:@escaping (IndexPath,Any)->String,
                   cellSize: ((IndexPath,Any)->CGSize)? = nil,
                   sourceObjects: @escaping ((@escaping([[Any]],Bool) -> Void) -> Void),
                   didSelectCell:((IndexPath,Any) -> Void)? = nil) {
        self.configureCellIdentifier = cellIdentifier
        self.configureCellSize = cellSize
        self.fetchSourceObjects = sourceObjects
        self.didSelectCell = didSelectCell
    }
    
    public func registerCellClass(_ `class`:AnyClass,withIdentifier identifier: String) {
        self._tableView?.register(`class`, forCellReuseIdentifier: identifier)
        self._collectionView?.register(`class`, forCellWithReuseIdentifier: identifier)
    }
    
    public func registerCellNib(_ nib: UINib,withIdentifier identifier: String) {
        self._tableView?.register(nib, forCellReuseIdentifier: identifier)
        self._collectionView?.register(nib, forCellWithReuseIdentifier: identifier)
    }
    
    public func insertSection(withObject objects:[Any]...,at index: Int? = nil) {
        insertSections(withObjects: Array(objects),at: index)
    }
    
    public func insertSections(withObjects objects:[[Any]],at index: Int? = nil) {
        let currentCount = index ?? self.sourceObjects.count
        for index in 0..<objects.count {
            self.sourceObjects.insert(objects[index], at: currentCount + index)
        }
        let sections = IndexSet(integersIn: currentCount..<currentCount+objects.count)
        self.performAnimation(){
            self._tableView?.insertSections(sections, with: self._rowAnimation.insert)
            self._collectionView?.insertSections(sections)
        }
    }
    
    public func insertRow(withObject object:Any,at indexPath:IndexPath? = nil) {
        let section = (self._tableView?.numberOfSections ?? self._collectionView?.numberOfSections)! - 1
        let row = (self._tableView?.numberOfRows(inSection: section) ?? self._collectionView?.numberOfItems(inSection: section))!
        let index = indexPath ?? IndexPath(item: row, section: section)
        self.insertRows(withObjects: [object], at: [index])
    }
    
    public func insertRows(withObjects objects:[Any],at indexPaths:[IndexPath]) {
        for index in 0..<objects.count {
            let object = objects[index]
            let index = indexPaths[index]
            self.sourceObjects[index.section].insert(object, at: index.row)
        }
        self.performAnimation(){
            self._tableView?.insertRows(at: indexPaths, with: self._rowAnimation.insert)
            self._collectionView?.insertItems(at: indexPaths)
        }
    }
    
    public func deleteRow(withIndex indexs: IndexPath...) {
        deleteRows(withIndexs: Array(indexs))
    }
    
    public func deleteRows(withIndexs indexs: [IndexPath]) {
        let indexs = indexs.sorted { (a, b) -> Bool in
            if a.section == b.section {
                return a.row < b.row
            }
            return a.section < b.section
            }.reversed() as [IndexPath]
        for index in indexs {
            self.sourceObjects[index.section].remove(at: index.row)
        }
        self.performAnimation(){
            self._tableView?.deleteRows(at: indexs, with: self._rowAnimation.delete)
            self._collectionView?.deleteItems(at: indexs)
        }
    }
    
    public func deleteSection(withIndex indexs:Int...) {
        deleteSections(withIndexs: Array(indexs))
    }
    
    public func deleteSections(withIndexs indexs:[Int]? = nil) {
        let indexs = (indexs ?? Array(0..<sourceObjects.count)).sorted().reversed()
        for index in indexs {
            self.sourceObjects.remove(at: index)
        }
        self.performAnimation(){
            self._tableView?.deleteSections(IndexSet(indexs), with: self._rowAnimation.delete)
            self._collectionView?.deleteSections(IndexSet(indexs))
        }
    }
    
    public func reloadSection(withIndex indexs:Int...) {
        self.reloadSections(withIndexs: Array(indexs))
    }
    
    public func reloadSections(withIndexs indexs:[Int]? = nil) {
        let indexs = indexs ?? Array(0..<self.sourceObjects.count)
        let sections = IndexSet(indexs)
        self.performAnimation(){
            self._tableView?.reloadSections(sections, with: self._rowAnimation.reload)
            self._collectionView?.reloadSections(sections)
        }
    }
    
    public func reloadRow(withIndex indexs:IndexPath...) {
        self.reloadRows(withIndexs: Array(indexs))
    }
    
    public func reloadRows(withIndexs indexs:[IndexPath]? = nil) {
        if let indexs = indexs {
            self.performAnimation() {
                self._tableView?.reloadRows(at: indexs, with: self._rowAnimation.reload)
                self._collectionView?.reloadItems(at: indexs)
            }
        } else {
            self.reloadSections()
        }
    }
    
    open func refreshData(reload: Bool = true, immediately: Bool = false) {
        if !isLoading {
            #if ALISTVIEWCONTROLLER_INFINITESCROLLING
            if self.infiniteScrollingEnabled && reload {
                self.scrollView.es_resetNoMoreData()
            }
            #endif
            func reset() {
                self.deleteSections(withIndexs: Array(0..<sourceObjects.count))
            }
            if reload && immediately {
                reset()
            }
            isLoading = true
            fetchSourceObjects({ [weak self] objects,noMoreData in
                if let _self = self {
                    func update() {
                            _self._tableView?.beginUpdates()
                            let currentCount = _self.sourceObjects.count
                            var ignoredSections = [Int]()
                            if objects.count > currentCount {
                                var news = [[Any]]()
                                for index in currentCount..<objects.count {
                                    ignoredSections.append(index)
                                    news.append(objects[index])
                                }
                                _self.insertSections(withObjects: news)
                            } else if objects.count < currentCount {
                                _self.deleteSections(withIndexs: Array(objects.count..<currentCount))
                            }
                            var reloadRows = [IndexPath]()
                            for section in 0..<objects.count {
                                let news = objects[section]
                                var currents = _self.sourceObjects[section]
                                var ignoredRows = [Int]()
                                if news.count > (reload ? currents.count : 0) && !ignoredSections.contains(section) {
                                    var values: ([IndexPath],[Any]) = ([],[])
                                    let addIndex = (reload ? 0 : currents.count)
                                    for index in currents.count..<(news.count + addIndex) {
                                        ignoredRows.append(index)
                                        values.0.append(IndexPath(item: index, section: section))
                                        values.1.append(news[index - addIndex])
                                    }
                                    _self.insertRows(withObjects: values.1, at: values.0)
                                } else if news.count < currents.count && reload {
                                    var values = [IndexPath]()
                                    for index in news.count..<currents.count {
                                        values.append(IndexPath(item: index, section: section))
                                    }
                                    _self.deleteRows(withIndexs: values)
                                }
                                currents = _self.sourceObjects[section]
                                if reload && !ignoredSections.contains(section) {
                                    for index in 0..<currents.count where !ignoredRows.contains(index) {
                                        reloadRows.append(IndexPath(item: index, section: section))
                                    }
                                }
                            }
                            if reload {
                                for index in reloadRows {
                                    _self.sourceObjects[index.section][index.row] = objects[index.section][index.row]
                                }
                                _self.reloadRows(withIndexs: reloadRows)
                            }
                            _self._tableView?.endUpdates()
                    }
                    
                    func end() {
                        #if ALISTVIEWCONTROLLER_PULL
                        if _self.pullToRefreshEnabled {
                            _self.scrollView.es_stopPullToRefresh()
                        }
                        #endif
                        #if ALISTVIEWCONTROLLER_INFINITESCROLLING
                        if _self.infiniteScrollingEnabled {
                            _self.scrollView.es_stopLoadingMore()
                            if noMoreData {
                                _self.scrollView.es_noticeNoMoreData()
                            } else {
                                DispatchQueue.main.asyncAfter(deadline: .now(), execute: {
                                    if let footerOrigin = _self.scrollView.es_footer?.frame.origin.y,
                                        footerOrigin <=  _self.scrollView.contentOffset.y + _self.scrollView.frame.height {
                                        _self.refreshData(reload: false)
                                    }
                                })
                            }
                        }
                        #endif
                        _self.isLoading = false
                    }
                    DispatchQueue.main.async {
                        if _self.isLoadingMore {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: end)
                        } else {
                            end()
                        }
                        _self.performAnimation(update)
                        _self.isLoadingMore = false
                    }
                }
            })
        }
    }
    
    public func object(atIndexPath indexPath: IndexPath) -> Any {
        return sourceObjects[indexPath.section][indexPath.row]
    }
    
    internal func cellIdentifier(atIndexPath indexPath: IndexPath) -> String {
        return configureCellIdentifier(indexPath,object(atIndexPath: indexPath))
    }
    
    internal var numberOfSections: Int {
        return sourceObjects.count
    }
    
    internal func numberOfItems(inSection section: Int) -> Int {
        return sourceObjects[section].count
    }
    
    private func performAnimation(_ block:()->Void) {
        if self.rowAnimationEnabled {
            block()
        } else {
            UIView.performWithoutAnimation(block)
        }
    }
    
    deinit {
        self.configureCellIdentifier = nil
        self.configureCellSize = nil
        self.fetchSourceObjects = nil
        self.didSelectCell = nil
        self._tableView?.dataSource = nil
        self._tableView?.delegate = nil
        self._collectionView?.dataSource = nil
        self._collectionView?.delegate = nil
    }
}
