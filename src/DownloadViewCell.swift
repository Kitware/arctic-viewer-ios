//
//  DownloadViewCell.swift
//  ArcticViewer
//
//  Created by Tristan on 7/21/15.
//  Copyright (c) 2015 Kitware. All rights reserved.
//

/*
*   Cell for grid on DownloadViewController
*
*/

import UIKit

class DownloadViewCell: UICollectionViewCell {
    @IBOutlet weak var downloadedTag: UIImageView!
    @IBOutlet weak var thumbnail: UIImageView!

    var url:String = ""

    override var isSelected:Bool {
        didSet {
            self.setNeedsDisplay()
        }
    }

    override func draw(_ rect: CGRect) {
        self.contentView.layer.cornerRadius = 6.0
        self.contentView.layer.masksToBounds = true

        if !self.isSelected {
            self.contentView.layer.borderWidth = 2.0
            self.contentView.layer.borderColor = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [0.3,0.3,0.3,0.25])
        }
        else {
            self.contentView.layer.borderWidth = 4.0
            self.contentView.layer.borderColor = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [0,0.3,0.8,0.8])
        }
    }
}
