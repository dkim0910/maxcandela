import AppKit
import Metal
import QuartzCore

/// Owns a `CAMetalLayer` configured for EDR output and drives its render loop.
///
/// The layer is filled every frame with EDR "white" scaled by `boost`. A value
/// of 1.0 is SDR white (no visible effect); values above 1.0 push into the EDR
/// headroom and drive the backlight brighter. See the "boost mechanism" section
/// in CLAUDE.md.
///
/// NOTE (MVP): this fills the whole layer with a flat EDR value. The overlay
/// window keeps a low alpha so it primes headroom rather than painting an opaque
/// white sheet. The higher-quality capture-and-remap path (v2) is tracked in
/// CLAUDE.md and would replace the clear color below with a remapped capture.
final class MetalRenderer {
    let metalLayer = CAMetalLayer()

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var displayLink: CVDisplayLink?

    /// Live boost multiplier. Clamped by BrightnessController before it lands
    /// here, so we render exactly what we're told.
    var boost: CGFloat = 1.0

    /// Fails if the machine has no usable Metal device. Callers must degrade
    /// gracefully rather than force-unwrap — see CLAUDE.md conventions.
    init?() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else {
            return nil
        }
        self.device = device
        self.commandQueue = queue
        configureLayer()
    }

    private func configureLayer() {
        metalLayer.device = device
        metalLayer.isOpaque = false
        // EDR requires BOTH a float pixel format and an extended-linear
        // colorspace; miss either and values >1.0 just clip to white.
        metalLayer.pixelFormat = .rgba16Float
        metalLayer.wantsExtendedDynamicRangeContent = true
        metalLayer.colorspace = CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3)
        metalLayer.framebufferOnly = true
    }

    // MARK: - Render loop

    func start() {
        guard displayLink == nil else { return }
        var link: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&link)
        guard let link else { return }

        let context = Unmanaged.passUnretained(self).toOpaque()
        CVDisplayLinkSetOutputCallback(link, { (_, _, _, _, _, userInfo) -> CVReturn in
            let renderer = Unmanaged<MetalRenderer>.fromOpaque(userInfo!).takeUnretainedValue()
            renderer.renderFrame()
            return kCVReturnSuccess
        }, context)

        CVDisplayLinkStart(link)
        displayLink = link
    }

    func stop() {
        if let link = displayLink {
            CVDisplayLinkStop(link)
        }
        displayLink = nil
    }

    private func renderFrame() {
        guard let drawable = metalLayer.nextDrawable(),
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }

        // Fill with EDR white × boost. In an extended-linear colorspace, values
        // above 1.0 are legal and map into the panel's HDR headroom.
        let level = Double(boost)
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = drawable.texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColor(red: level, green: level, blue: level, alpha: 1.0)

        if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) {
            encoder.endEncoding()
        }
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
