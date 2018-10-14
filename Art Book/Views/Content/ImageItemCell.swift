//
//  ImageItemCel.swift
//  Example
//
//  Created by Wes Byrne on 1/28/17.
//  Copyright © 2017 Noun Project. All rights reserved.
//

//import Foundation
import Cocoa
import CollectionView

class ImageItemCell: CollectionViewPreviewCell {
    
    @IBOutlet weak var imageView: NSImageView!
    @IBOutlet weak var textField: NSTextField!
    
    var url: URL?
    private var imageSource: CGImageSource?
    private var token: NSKeyValueObservation?
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
//    override var wantsUpdateLayer: Bool { return true }
    override func prepareForReuse() {
        super.prepareForReuse()
        loadImageOperation?.cancel()
        token?.invalidate()
        url = nil
        imageSource = nil
        previewImage = nil
        token = nil
        markWidth = 0
    }
    

    override class var defaultReuseIdentifier: String {
        return "ImageItemCell"
    }
    
    override class func register(in collectionView: CollectionView) {
        collectionView.register(nib: NSNib(nibNamed: "ImageItemCell", bundle: nil)!,
                                forCellWithReuseIdentifier: self.defaultReuseIdentifier)
    }
    

    

//    override func viewWillMove(toSuperview newSuperview: NSView?) {
//        super.viewWillMove(toSuperview: newSuperview)
//        self.layer?.borderColor = NSColor(white: 0.9, alpha: 1).cgColor
//    }

//     MARK: - Selection & Highlighting
//    -------------------------------------------------------------------------------
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        if selected {
            self.backgroundColor = NSColor.windowBackgroundColor
            self.layer?.cornerRadius = 5
        } else {
            self.backgroundColor = NSColor.clear
            self.layer?.cornerRadius = 0
        }
        self.needsDisplay = true
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)

        guard !self.selected else { return }
        
        if highlighted {
            self.backgroundColor = NSColor.windowBackgroundColor
            self.layer?.cornerRadius = 5
        } else {
            self.backgroundColor = NSColor.clear
            self.layer?.cornerRadius = 0
        }
        
        self.needsDisplay = true
    }
    

    var isDisplaying = false {
        willSet {
            if newValue {
                requestPreviewImage()
                token = imageView?.observe(\.frame) { [weak self] imageView, _ in
                    guard imageView.frame.width != 0, imageView.frame.height != 0 else { return }
                    self?.requestPreviewImage()
                }
            } else {
                loadImageOperation?.cancel()
                token?.invalidate()
            }
        }
    }
    
    var markWidth: CGFloat = 0
    
    
    func initUrl(_ url: URL) {
        self.url = url
        textField?.stringValue = url.lastPathComponent
    }
    
    
    
//    override var isSelected: Bool {
//        get {
//            return super.isSelected
//        }
//        set {
//            super.isSelected = newValue
//            backgroundBox.isHidden = newValue
//        }
//    }
    
    
    
    // NULL until metadata is loaded
    var previewImage: NSImage? {
        didSet {
            imageView.image = previewImage
        }
    }
    
    var loadImageOperation: BlockOperation?
    
    //MARK: Loading
    
    private func createImageSource() -> Bool {
        
        guard imageSource == nil, let sourceURL = self.url else { return true }
        
        guard let imageSource = CGImageSourceCreateWithURL(sourceURL as CFURL, nil) else {
            return false
        }
        
        guard let _ = CGImageSourceGetType(imageSource) else {
            return false
        }
        
        self.imageSource = imageSource
        return true
    }
    
    func requestPreviewImage() {
        
        guard markWidth != imageView.frame.width - 8 else { return }
        markWidth = imageView.frame.width - 8
        loadImageOperation?.cancel()
        
        
        guard let scale = NSScreen.main?.backingScaleFactor, let url = self.url else {
            return
        }
        
        let maxPixelSize = (Int(markWidth * scale / 100) + 1) * 100
        let cacheKey = "\(url.absoluteString) - \(maxPixelSize)"
        
        if let image = ImageCache.image(forKey: cacheKey) {
            previewImage = image
            return
        }
        
        loadImageOperation = BlockOperation()
        
        loadImageOperation?.addExecutionBlock { [weak self] in
            
            autoreleasepool {
                guard let re = self?.createImageSource(),
                    re,
                    let imageSource = self?.imageSource else { return }
                
                let options: [AnyHashable: Any] = [
                    // Ask ImageIO to create a thumbnail from the file's image data, if it can't find
                    // a suitable existing thumbnail image in the file.  We could comment out the following
                    // line if only existing thumbnails were desired for some reason (maybe to favor
                    // performance over being guaranteed a complete set of thumbnails).
                    kCGImageSourceCreateThumbnailFromImageAlways as AnyHashable: true,
                    kCGImageSourceThumbnailMaxPixelSize as AnyHashable: maxPixelSize
                ]
                
                
                guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {return}
                
                
                
                let image = NSImage(cgImage: thumbnail, size: NSZeroSize)
                ImageCache.setImage(image, forKey: cacheKey)
                OperationQueue.main.addOperation { [weak self] in
                    guard url == self?.url,
                        let newWidth = self?.imageView.frame.width,
                        self?.markWidth == newWidth - 8 else { return }
                    self?.previewImage = image
                }
                
                
            }
            
        }
        
        
        type(of: self).imageLoadingQueue.addOperation(loadImageOperation!)
    }
    
    private static var imageLoadingQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "CoverViewItem ImageView Loading Queue"
        queue.maxConcurrentOperationCount = 2
        return queue
    }()
    
    
}
