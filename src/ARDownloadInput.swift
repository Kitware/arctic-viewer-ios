//
//  DownloadInput.swift
//  DownloadInput
//
//  Created by Tristan on 7/20/15.
//  Copyright (c) 2015 Kitware. All rights reserved.
//

/*
*   ARDownloadInput
*   A UITextfield with a progressbar background. Public settings related to this progress bar are `barColor` and `progress`
*   ```
*   let progressInput:ARDownloadInput = ARDownloadInput()
*   progressInput.progress = 0.2 //sets progress to 20%
*   ```
*/

import UIKit

open class ARDownloadInput: UITextField {
    
    fileprivate let progressBar:CALayer = CALayer()
    
    open var barColor:CGColor = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [0, 0.4784, 1.0, 1])! {
        didSet {
            self.progressBar.backgroundColor = self.barColor
        }
    }
    
    open var progress:Float = 0 {
        didSet {
            self.progress = min(max(0, self.progress), 1.0)
            self.updateProgressBar()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.commonInit()
    }

    required public init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
        self.commonInit()
    }
    
    fileprivate func commonInit() {
        self.progressBar.frame = CGRect(origin: CGPoint.zero, size: CGSize(width: 0, height: self.frame.height))
        self.progressBar.backgroundColor = self.barColor
        self.progressBar.cornerRadius = 4.0
        
        self.layer.masksToBounds = true
        self.layer.addSublayer(self.progressBar)
    }
    
    override open func draw(_ rect: CGRect) {
       //let frame = CGRect(origin: CGPointZero, size: CGSize(width: rect.size.width, height: rect.size.height))
    }
    
    fileprivate func updateProgressBar() {
        let edgeOffset:CGFloat = self.progress > 0 ? 2.0 : 0.0
        let newSize:CGSize = CGSize(width: CGFloat(self.progress) * self.frame.width - edgeOffset, height: self.frame.height - edgeOffset )
        self.progressBar.frame = CGRect(origin: CGPoint(x: 1, y: 1), size: newSize)
    }
}
