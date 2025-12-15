import Cocoa
import CoreGraphics

class BigCursorApp: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var overlayWindows: [NSWindow] = []
    var cursorViews: [CursorView] = []
    
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
    var isDarkMode: Bool = true
    
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
        cursorViews.removeAll()
        setupOverlayWindows()
    }
    
    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "🖱️"
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.target = self
        }
    }
    
    @objc func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!
        
        if event.type == .rightMouseUp {
            let menu = NSMenu()
            let modeTitle = isDarkMode ? "Mode: Dark (click icon to toggle)" : "Mode: Light (click icon to toggle)"
            menu.addItem(NSMenuItem(title: modeTitle, action: nil, keyEquivalent: ""))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            toggleMode()
        }
    }
    
    @objc func toggleMode() {
        isDarkMode.toggle()
        for cursorView in cursorViews {
            cursorView.isDarkMode = isDarkMode
            cursorView.needsDisplay = true
        }
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
            
            let cursorView = CursorView(frame: NSRect(origin: .zero, size: screen.frame.size))
            cursorView.screenFrame = screen.frame
            window.contentView = cursorView
            window.setFrame(screen.frame, display: true)
            window.orderFrontRegardless()
            
            overlayWindows.append(window)
            cursorViews.append(cursorView)
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
            for cursorView in self.cursorViews {
                cursorView.globalMousePosition = currentPosition
                cursorView.needsDisplay = true
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
            for cursorView in self.cursorViews {
                cursorView.scale = self.currentScale
                cursorView.isVisible = isVisible
                cursorView.needsDisplay = true
            }
        }
    }
}

class CursorView: NSView {
    var globalMousePosition: CGPoint = .zero
    var screenFrame: NSRect = .zero
    var scale: CGFloat = 1.0
    var isVisible: Bool = false
    var isDarkMode: Bool = true
    
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
        
        let cursorPath = CGMutablePath()
        cursorPath.move(to: CGPoint(x: 0, y: 0))
        cursorPath.addLine(to: CGPoint(x: 0, y: -17))
        cursorPath.addLine(to: CGPoint(x: 4, y: -13))
        cursorPath.addLine(to: CGPoint(x: 9, y: -22))
        cursorPath.addLine(to: CGPoint(x: 12, y: -20))
        cursorPath.addLine(to: CGPoint(x: 7, y: -11))
        cursorPath.addLine(to: CGPoint(x: 12, y: -11))
        cursorPath.closeSubpath()
        
        let fillColor = isDarkMode ? NSColor.black.cgColor : NSColor.white.cgColor
        let strokeColor = isDarkMode ? NSColor.white.cgColor : NSColor.black.cgColor
        
        context.setLineWidth(2.0 / scale * 2)
        context.addPath(cursorPath)
        context.setStrokeColor(strokeColor)
        context.strokePath()
        
        context.addPath(cursorPath)
        context.setFillColor(fillColor)
        context.fillPath()
        
        context.restoreGState()
    }
}

let app = NSApplication.shared
let delegate = BigCursorApp()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
