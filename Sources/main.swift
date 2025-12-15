import Cocoa
import CoreGraphics

class BigArrowApp: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var overlayWindow: NSWindow!
    var arrowView: ArrowView!
    
    var lastMousePosition: CGPoint = .zero
    var lastMouseTime: Date = Date()
    var velocityHistory: [CGFloat] = []
    var currentScale: CGFloat = 1.0
    var targetScale: CGFloat = 1.0
    var isShaking: Bool = false
    var displayLink: CVDisplayLink?
    var shakingDuration: TimeInterval = 0
    var lastShakeTime: Date = Date()
    
    let velocityThreshold: CGFloat = 800
    let maxHistorySize = 10
    let growthRate: CGFloat = 0.15
    let shrinkRate: CGFloat = 0.92
    let minScale: CGFloat = 1.0
    let maxScale: CGFloat = 50.0
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupOverlayWindow()
        startMouseTracking()
        startDisplayLink()
        
        NSCursor.hide()
    }
    
    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "🏹"
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Big Arrow Active", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }
    
    func setupOverlayWindow() {
        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        
        overlayWindow = NSWindow(
            contentRect: screenFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        
        overlayWindow.level = .screenSaver
        overlayWindow.backgroundColor = .clear
        overlayWindow.isOpaque = false
        overlayWindow.hasShadow = false
        overlayWindow.ignoresMouseEvents = true
        overlayWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        arrowView = ArrowView(frame: screenFrame)
        overlayWindow.contentView = arrowView
        overlayWindow.orderFrontRegardless()
    }
    
    func startMouseTracking() {
        NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]) { [weak self] event in
            self?.handleMouseMove(event)
        }
        
        NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]) { [weak self] event in
            self?.handleMouseMove(event)
            return event
        }
    }
    
    func handleMouseMove(_ event: NSEvent) {
        let currentPosition = NSEvent.mouseLocation
        let currentTime = Date()
        let timeDelta = currentTime.timeIntervalSince(lastMouseTime)
        
        if timeDelta > 0 {
            let distance = hypot(currentPosition.x - lastMousePosition.x, currentPosition.y - lastMousePosition.y)
            let velocity = distance / CGFloat(timeDelta)
            
            velocityHistory.append(velocity)
            if velocityHistory.count > maxHistorySize {
                velocityHistory.removeFirst()
            }
            
            let avgVelocity = velocityHistory.reduce(0, +) / CGFloat(velocityHistory.count)
            
            if avgVelocity > velocityThreshold {
                if !isShaking {
                    isShaking = true
                    shakingDuration = 0
                }
                lastShakeTime = currentTime
                shakingDuration += timeDelta
                
                let velocityMultiplier = min(avgVelocity / velocityThreshold, 5.0)
                let durationMultiplier = 1.0 + CGFloat(shakingDuration) * 0.5
                targetScale = min(currentScale + growthRate * velocityMultiplier * durationMultiplier, maxScale)
            } else {
                if isShaking && currentTime.timeIntervalSince(lastShakeTime) > 0.1 {
                    isShaking = false
                    shakingDuration = 0
                }
            }
        }
        
        lastMousePosition = currentPosition
        lastMouseTime = currentTime
        
        DispatchQueue.main.async { [weak self] in
            self?.arrowView.mousePosition = currentPosition
            self?.arrowView.needsDisplay = true
        }
    }
    
    func startDisplayLink() {
        Timer.scheduledTimer(withTimeInterval: 1.0/120.0, repeats: true) { [weak self] _ in
            self?.updateAnimation()
        }
    }
    
    func updateAnimation() {
        if isShaking {
            currentScale = currentScale + (targetScale - currentScale) * 0.3
        } else {
            currentScale = max(currentScale * shrinkRate, minScale)
            targetScale = minScale
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.arrowView.scale = self.currentScale
            self.arrowView.needsDisplay = true
        }
    }
}

class ArrowView: NSView {
    var mousePosition: CGPoint = .zero
    var scale: CGFloat = 1.0
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        context.clear(bounds)
        
        let flippedY = mousePosition.y
        
        context.saveGState()
        context.translateBy(x: mousePosition.x, y: flippedY)
        context.scaleBy(x: scale, y: scale)
        
        let arrowPath = CGMutablePath()
        arrowPath.move(to: CGPoint(x: 0, y: 0))
        arrowPath.addLine(to: CGPoint(x: 0, y: -17))
        arrowPath.addLine(to: CGPoint(x: 4, y: -13))
        arrowPath.addLine(to: CGPoint(x: 9, y: -22))
        arrowPath.addLine(to: CGPoint(x: 12, y: -20))
        arrowPath.addLine(to: CGPoint(x: 7, y: -11))
        arrowPath.addLine(to: CGPoint(x: 12, y: -11))
        arrowPath.closeSubpath()
        
        context.setLineWidth(1.5 / scale * 2)
        context.addPath(arrowPath)
        context.setStrokeColor(NSColor.black.cgColor)
        context.strokePath()
        
        context.addPath(arrowPath)
        context.setFillColor(NSColor.white.cgColor)
        context.fillPath()
        
        context.setLineWidth(0.5)
        context.addPath(arrowPath)
        context.setStrokeColor(NSColor.black.cgColor)
        context.strokePath()
        
        context.restoreGState()
    }
}

let app = NSApplication.shared
let delegate = BigArrowApp()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()

