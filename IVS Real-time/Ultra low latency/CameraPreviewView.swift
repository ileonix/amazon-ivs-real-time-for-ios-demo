//
//  CameraPreviewView.swift
//  IVS Real-time
//
//  Created by Chanon Purananunak on 10/11/2568 BE.
//

import SwiftUI
import AmazonIVSBroadcast

struct CameraPreviewView: UIViewRepresentable {
    let camera: IVSDevice?
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .black
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Remove existing preview
        uiView.subviews.forEach { $0.removeFromSuperview() }
        
        // Add new preview if camera exists
        if let camera = camera as? IVSImageDevice,
           let previewView = try? camera.previewView(with: .fill) {
            uiView.addSubview(previewView)
            previewView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                previewView.topAnchor.constraint(equalTo: uiView.topAnchor),
                previewView.leadingAnchor.constraint(equalTo: uiView.leadingAnchor),
                previewView.trailingAnchor.constraint(equalTo: uiView.trailingAnchor),
                previewView.bottomAnchor.constraint(equalTo: uiView.bottomAnchor)
            ])
        }
    }
}
