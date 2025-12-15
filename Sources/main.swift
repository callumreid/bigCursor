import Cocoa
import CoreGraphics

class BigArrowApp: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var overlayWindows: [NSWindow] = []
    var arrowViews: [ArrowView] = []
    
    var lastMousePosition: CGPoint = .zero
    var lastMouseTime: Date = Date()
    var velocityHistory: [CGFloat] = []
    var currentScale: CGFloat = 1.0
    var targetScale: CGFloat = 1.0
    var isShaking: Bool = false
    var isGrowing: Bool = false
    var cursorHidden: Bool = false
    var shakeStartTime: Date?
    var lastShakeTime: Date = Date()
    
    let velocityThreshold: CGFloat = 800
    let maxHistorySize = 10
    let growthRate: CGFloat = 0.15
    let shrinkRate: CGFloat = 0.92
    let minScale: CGFloat = 1.0
    let maxScale: CGFloat = 500.0
    let warmupDuration: TimeInterval = 1.5
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupOverlayWindows()
        startMouseTracking()
        startDisplayLink()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }
    
    @objc func screensChanged() {
        for window in overlayWindows {
            window.orderOut(nil)
        }
        overlayWindows.removeAll()
        arrowViews.removeAll()
        setupOverlayWindows()
    }
    
    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "🏹"
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Big Arrow Active", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem.menu = menu
    }
    
    @objc func quitApp() {
        showSystemCursor()
        NSApplication.shared.terminate(nil)
    }
    
    func hideSystemCursor() {
        if !cursorHidden {
            CGDisplayHideCursor(CGMainDisplayID())
            cursorHidden = true
        }
    }
    
    func showSystemCursor() {
        if cursorHidden {
            CGDisplayShowCursor(CGMainDisplayID())
            cursorHidden = false
        }
    }
    
    func setupOverlayWindows() {
        for screen in NSScreen.screens {
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            
            window.level = .screenSaver
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = false
            window.ignoresMouseEvents = true
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            
            let arrowView = ArrowView(frame: NSRect(origin: .zero, size: screen.frame.size))
            arrowView.screenFrame = screen.frame
            window.contentView = arrowView
            window.setFrame(screen.frame, display: true)
            window.orderFrontRegardless()
            
            overlayWindows.append(window)
            arrowViews.append(arrowView)
        }
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
                    shakeStartTime = currentTime
                }
                lastShakeTime = currentTime
                
                let shakingDuration = currentTime.timeIntervalSince(shakeStartTime ?? currentTime)
                
                if shakingDuration >= warmupDuration {
                    isGrowing = true
                    let velocityMultiplier = min(avgVelocity / velocityThreshold, 5.0)
                    let growthDuration = shakingDuration - warmupDuration
                    let durationMultiplier = 1.0 + CGFloat(growthDuration) * 0.5
                    targetScale = min(currentScale + growthRate * velocityMultiplier * durationMultiplier, maxScale)
                }
            } else {
                if isShaking && currentTime.timeIntervalSince(lastShakeTime) > 0.1 {
                    isShaking = false
                    isGrowing = false
                    shakeStartTime = nil
                }
            }
        }
        
        lastMousePosition = currentPosition
        lastMouseTime = currentTime
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            for arrowView in self.arrowViews {
                arrowView.globalMousePosition = currentPosition
                arrowView.needsDisplay = true
            }
        }
    }
    
    func startDisplayLink() {
        Timer.scheduledTimer(withTimeInterval: 1.0/120.0, repeats: true) { [weak self] _ in
            self?.updateAnimation()
        }
    }
    
    func updateAnimation() {
        let wasVisible = currentScale > minScale + 0.01
        
        if isGrowing {
            currentScale = currentScale + (targetScale - currentScale) * 0.3
        } else {
            currentScale = max(currentScale * shrinkRate, minScale)
            targetScale = minScale
        }
        
        let isVisible = currentScale > minScale + 0.01
        
        if isVisible && !wasVisible {
            hideSystemCursor()
        } else if !isVisible && wasVisible {
            showSystemCursor()
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            for arrowView in self.arrowViews {
                arrowView.scale = self.currentScale
                arrowView.isVisible = isVisible
                arrowView.needsDisplay = true
            }
        }
    }
}

class ArrowView: NSView {
    var globalMousePosition: CGPoint = .zero
    var screenFrame: NSRect = .zero
    var scale: CGFloat = 1.0
    var isVisible: Bool = false
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        context.clear(bounds)
        
        guard isVisible else { return }
        
        let localX = globalMousePosition.x - screenFrame.origin.x
        let localY = globalMousePosition.y - screenFrame.origin.y
        
        let isOnThisScreen = localX >= 0 && localX <= screenFrame.width &&
                             localY >= 0 && localY <= screenFrame.height
        
        guard isOnThisScreen else { return }
        
        context.saveGState()
        context.translateBy(x: localX, y: localY)
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
