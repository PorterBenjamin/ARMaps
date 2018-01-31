//
//  CustomPolyline.swift
//  ARMaps
//
//  Created by Ben Porter on 1/30/18.
//  Copyright © 2018 Ben Porter. All rights reserved.
//
import MapKit

class CustomPolyline: MKPolylineRenderer {
    
    override func applyStrokeProperties(to context: CGContext, atZoomScale zoomScale: MKZoomScale) {
        super.applyStrokeProperties(to: context, atZoomScale: zoomScale)
        UIGraphicsPushContext(context)
        if let ctx = UIGraphicsGetCurrentContext() {
            ctx.setLineWidth(self.lineWidth)
        }
    }
}
