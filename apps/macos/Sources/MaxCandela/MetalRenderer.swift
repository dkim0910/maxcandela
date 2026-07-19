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
    private var displayLink: CADisplayLink?

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

    /// Drive the render loop from the hosting view's display link (the modern
    /// replacement for CVDisplayLink, which Apple deprecated in macOS 15). The
    /// link is tied to the view's screen and paced to its refresh rate.
    func start(view: NSView) {
        guard displayLink == nil else { return }
        let link = view.displayLink(target: self, selector: #selector(step))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    /// CADisplayLink retains its target, so invalidate on teardown/dealloc to
    /// break the cycle and stop the loop.
    deinit {
        stop()
    }

    @objc private func step(_ sender: CADisplayLink) {
        renderFrame()
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
