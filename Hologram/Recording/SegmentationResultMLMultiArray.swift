//
//  SegmentationResultMLMultiArray.swift
//  Hologram
//
//  Created by Nicholas Garfield on 3/20/20.
//  Copyright © 2020 Nicholas Garfield. All rights reserved.
//

import CoreML

class SegmentationResultMLMultiArray {
    let mlMultiArray: MLMultiArray
    let segmentationMapWidthSize: Int
    let segmentationMapHeightSize: Int
    
    init(mlMultiArray: MLMultiArray) {
        self.mlMultiArray = mlMultiArray
        self.segmentationMapWidthSize = mlMultiArray.shape[0].intValue
        self.segmentationMapHeightSize = mlMultiArray.shape[1].intValue
    }
    
    subscript(colunmIndex: Int, rowIndex: Int) -> NSNumber {
        let index = colunmIndex * (segmentationMapHeightSize) + rowIndex
        return mlMultiArray[index]
    }
}
