//
//  ContentViewController.swift
//  Art Book
//
//  Created by xjbeta on 2018/10/1.
//  Copyright © 2018 xjbeta. All rights reserved.
//

import Cocoa
import CollectionView

class ContentViewController: NSViewController {

    @IBOutlet weak var collectionView: CollectionView!
    
    @IBOutlet var collectionMenu: NSMenu!
    var frameObserve: NSKeyValueObservation?
    
    var fileWatcher: FileWatcher?
    var fileNode: FileNode? = nil {
        didSet {
            filesObserver()
        }
    }
    
    let useCollectionView = true
    var baseWidth: CGFloat = 160
    var itemSizeScale: CGFloat = 1
    
    var viewMode: ViewMode = .column
    
    var layout: CollectionViewLayout {
        get {
            switch viewMode {
            case .column:
                let layout = CollectionViewColumnLayout()
                layout.layoutStrategy = .shortestFirst
                return layout
            case .flow:
                let layout = CollectionViewFlowLayout()
                layout.defaultRowTransform = .center
                return layout
            case .list:
                let layout = CollectionViewListLayout()
                return layout
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        collectionView.collectionViewLayout = layout
        collectionView.allowsMultipleSelection = false
        collectionView.dataSource = self
        collectionView.delegate = self
        
        updateScale(false)
        
        frameObserve = collectionView.observe(\.frame) { view, _ in
            if view.collectionViewLayout is CollectionViewColumnLayout {
                self.updateScale(false)
            }
        }

        collectionView.register(nib: NSNib(nibNamed: "ImageItemCell", bundle: nil)!, forCellWithReuseIdentifier: "ImageItemCell")
        
        NotificationCenter.default.addObserver(forName: .sidebarSelectionDidChange, object: nil, queue: .main) {
            if let userInfo = $0.userInfo as? [String: FileNode],
                let node = userInfo["node"] {
                self.fileNode = node
                self.collectionView.reloadData()
            }
        }
        
        NotificationCenter.default.addObserver(forName: .viewModeDidChange, object: nil, queue: .main) {
            if let userInfo = $0.userInfo as? [String: ViewMode],
                let viewMode = userInfo["viewMode"] {
                self.viewMode = viewMode
                self.collectionView.collectionViewLayout = self.layout
                self.updateScale(true)
            }
        }
        
        NotificationCenter.default.addObserver(forName: .scaleDidChange, object: nil, queue: .main) { _ in
            self.updateScale(false)
        }
        
        // check scrollView Magnification limit
//        NotificationCenter.default.addObserver(forName: NSScrollView.didEndLiveMagnifyNotification, object: nil, queue: .main) { _ in
//            guard let scrollView = self.scrollView else { return }
//            if scrollView.magnification < scrollView.minMagnification {
//                scrollView.setMagnification(scrollView.minMagnification, centeredAt: NSZeroPoint)
//            } else if scrollView.magnification > scrollView.maxMagnification {
//                scrollView.setMagnification(scrollView.maxMagnification, centeredAt: NSZeroPoint)
//            } else {
//
//                let size = self.imageBrowser.cellSize()
//
//                print(self.imageBrowser.zoomValue())
//                self.imageBrowser.setZoomValue(2)
//
////                std::exp(magnification)
//                self.imageBrowser.needsDisplay = true
//
//                print(self.imageBrowser.frame)
//                self.imageBrowser.setFrameSize(self.scrollView!.frame.size)
//                print(self.imageBrowser.frame)
//
////                guard !self.singleMode else { return }
////                self.fileCollectionView.visibleItems().forEach { item in
////                    guard let coverViewItem = item as? CoverViewItem else {
////                        return
////                    }
////                    coverViewItem.updateImage(magnification: scrol#imageLiteral(resourceName: "02_001.jpg")lView.magnification)
////                }
//            }
//        }
    }
    
    

    
    func updateScale(_ animated: Bool) {
        let scale = CGFloat(Preferences.shared.scales(for: viewMode))
        let width = baseWidth * CGFloat(scale + 0.2) * 2.5
        let layout = collectionView.collectionViewLayout
        
        if let l = layout as? CollectionViewColumnLayout {
            l.columnCount = Int(collectionView.frame.width / baseWidth / (1 + scale))
            self.collectionView.reloadLayout(animated)
        } else if let l = layout as? CollectionViewFlowLayout {
            l.defaultItemStyle = .flow(NSSize(width: width, height: width))
            self.collectionView.reloadLayout(animated)
        } else if let l = layout as? CollectionViewListLayout {
            let width = self.collectionView.frame.width * (0.5 - scale / 2) / 2
            l.sectionInsets = NSEdgeInsets(top: 0, left: width, bottom: 0, right: width)
            self.collectionView.reloadLayout(animated, scrollPosition: CollectionViewScrollPosition.centered) { _ in }
        }
    }
    
    func filesObserver() {
        guard let path = fileNode?.url?.path else { return }
        fileWatcher?.stop()
        fileWatcher = nil
        fileWatcher = FileWatcher([path]) { [weak self] event in
            // check is hidden url
            let url = URL(fileURLWithPath: event.path)
            guard !url.lastPathComponent.starts(with: ".") else { return }
            
            // check is child of observed folder
            guard url.path.isChildItem(of: path) else { return }
            
            // check url is Directory
            // The doesn't exist file will skip Directory checker
            var isDirectory = ObjCBool(false)
            let exists = FileManager.default.fileExists(atPath: event.path, isDirectory: &isDirectory)
            guard !isDirectory.boolValue else { return }
            
            if !exists {
                // deleted file/path
                guard let index = self?.fileNode?.childrenImages.enumerated().filter ({
                    $0.element.name == url.lastPathComponent
                }).map ({
                    $0.offset
                }).first else { return }
                self?.fileNode?.childrenImages.remove(at: index)
                self?.collectionView.deleteItems(at: [IndexPath(item: index, section: 0)], animated: true)
                return
            }
            
            if event.fileCreated || event.fileRenamed {
                
                guard let index = self?.fileNode?.childrenImages.enumerated().filter ({
                    $0.element.name == url.lastPathComponent
                }).map ({
                    $0.offset
                }).first else {
                    let newNode = FileNode(url: url)
                    if let index = self?.fileNode?.childrenImages.index(where: { $0.name > newNode.name }) {
                        self?.fileNode?.childrenImages.insert(newNode, at: index)
                        self?.collectionView.insertItems(at: [IndexPath(item: index, section: 0)], animated: true)
                    }
                    return
                }
                
                let indexPath = IndexPath(item: index, section: 0)
                self?.collectionView.reloadItems(at: [indexPath], animated: false)
                if let cell = self?.collectionView.cellForItem(at: indexPath) as? ImageItemCell {
                    cell.requestPreviewImage(true)
                }
            } else if event.fileModified {
                print("fileModified")
            } else if event.fileRemoved {
                print("fileRemoved")
            } else if event.dirRemoved || event.dirModified || event.dirChange || event.dirCreated || event.dirRenamed {
                return
            } else {
                print("Unknown file watcher event.")
                print(event.description)
            }
        }
        
        fileWatcher?.start()
    }
    
    deinit {
        frameObserve?.invalidate()
        fileWatcher?.stop()
        fileWatcher = nil
    }
}




//#pragma mark search
//
///*
// this code filters the "images" array depending on the current search field value. All items that are filtered-out are kept in the
// "filteredOutImages" array (and corresponding indexes are kept in "filteredOutIndexes" in order to restore these indexes when the search field is cleared
// */
//
//- (BOOL) keyword:(NSString *) aKeyword matchSearch:(NSString *) search
//{
//    NSRange r = [aKeyword rangeOfString:search options:NSCaseInsensitiveSearch];
//    return (r.length>0 && r.location>=0);
//    }
//
//    - (IBAction) searchFieldChanged:(id) sender
//{
//    if(filteredOutImages == nil){
//        //first time we use the search field
//        filteredOutImages = [[NSMutableArray alloc] init];
//        filteredOutIndexes = [[NSMutableIndexSet alloc] init];
//    }
//    else{
//        //restore the original datasource, and restore the initial ordering if possible
//
//        NSUInteger lastIndex = [filteredOutIndexes lastIndex];
//        if(lastIndex >= [images count] + [filteredOutImages count]){
//            //can't restore previous indexes, just insert filtered items at the beginning
//            [images insertObjects:filteredOutImages atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [filteredOutImages count])]];
//        }
//        else
//        [images insertObjects:filteredOutImages atIndexes:filteredOutIndexes];
//
//        [filteredOutImages removeAllObjects];
//        [filteredOutIndexes removeAllIndexes];
//    }
//
//    //add filtered images to the filteredOut array
//    NSString *searchString = [sender stringValue];
//
//    if(searchString != nil && [searchString length] > 0){
//        int i, n;
//
//        n = [images count];
//
//        for(i=0; i<n; i++){
//            MyImageObject *anItem = [images objectAtIndex:i];
//
//            if([self keyword:[anItem imageTitle] matchSearch:searchString] == NO){
//                [filteredOutImages addObject:anItem];
//                [filteredOutIndexes addIndex:i];
//            }
//        }
//    }
//
//    //remove filtered-out images from the datasource array
//    [images removeObjectsInArray:filteredOutImages];
//
//    //reflect changes in the browser
//    [imageBrowser reloadData];
//}



extension ContentViewController: CollectionViewDelegate, CollectionViewDataSource, CollectionViewDelegateColumnLayout, CollectionViewDelegateListLayout {
    func collectionView(_ collectionView: CollectionView, cellForItemAt indexPath: IndexPath) -> CollectionViewCell {
        
//        // If no child,
//        guard let child = self.child(at: indexPath) else {
//            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "EmptyCell", for: indexPath) as! ListCell
//            cell.style = .basic
//            cell.titleLabel.alignment = .center
//            cell.titleLabel.textColor = NSColor.lightGray
//            cell.titleLabel.font = NSFont.boldSystemFont(ofSize: 24)
//            cell.disableHighlight = true
//            cell.titleLabel.stringValue = provider.showEmptyState ? "No data" : "Empty Section"
//            return cell
//        }
        
        
        let cell = ImageItemCell.deque(for: indexPath, in: collectionView) as! ImageItemCell
        guard let url = fileNode?.childrenImages[indexPath.item].url else { return cell }
        cell.initUrl(url)
        return cell
    }

    func numberOfSections(in collectionView: CollectionView) -> Int {
        if let c = fileNode?.childrenImages.count, c > 0 {
            return 1
        }
        return 0
    }
    
    
    func collectionView(_ collectionView: CollectionView, numberOfItemsInSection section: Int) -> Int {
        return fileNode?.childrenImages.count ?? 0
    }
    
    
    func collectionView(_ collectionView: CollectionView, layout collectionViewLayout: CollectionViewLayout, heightForItemAt indexPath: IndexPath) -> CGFloat {
//        print(layout)
        
        guard let imageRatio = fileNode?.childrenImages[indexPath.item].imageRatio else { return 0 }
        
        if let l = collectionView.collectionViewLayout as? CollectionViewColumnLayout {
            let width = (collectionView.frame.width
                - CGFloat(l.columnCount - 1) * l.interitemSpacing
                - l.sectionInset.left
                - l.sectionInset.right) / CGFloat(l.columnCount)
                - 16
            return width / imageRatio + 52
        }
        else if let l = collectionView.collectionViewLayout as? CollectionViewListLayout {
            let width = (collectionView.frame.width
                - l.sectionInsets.left
                - l.sectionInsets.right)
                - 16
            return width / imageRatio + 52
        }
        return 0
    }
    
    func collectionView(_ collectionView: CollectionView, willDisplayCell cell: CollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let cell = cell as? ImageItemCell else { return }
        cell.isDisplaying = true
    }

    func collectionView(_ collectionView: CollectionView, didEndDisplayingCell cell: CollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let cell = cell as? ImageItemCell else { return }
        cell.isDisplaying = false
    }
}
