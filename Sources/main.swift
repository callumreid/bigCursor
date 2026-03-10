import Cocoa
import CoreGraphics

struct CursorClone {
    var offset: CGPoint = .zero
    var velocity: CGPoint = .zero
    var angle: CGFloat
    var angularVelocity: CGFloat
    var opacity: CGFloat = 0.0
}

struct RenderCursor {
    var position: CGPoint
    var opacity: CGFloat
}

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
    var averageVelocity: CGFloat = 0.0
    var cursorClones: [CursorClone] = []
    var targetCloneCount = 0
    var lastAnimationTime: Date = Date()
    
    let velocityThreshold: CGFloat = 800
    let multiplicationVelocityThreshold: CGFloat = 1800
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
            averageVelocity = avgVelocity
            
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
                    targetCloneCount = cloneTarget(for: avgVelocity, growthDuration: growthDuration)
                }
            } else {
                if isShaking && currentTime.timeIntervalSince(lastShakeTime) > 0.1 {
                    isShaking = false
                    isGrowing = false
                    shakeStartTime = nil
                    targetCloneCount = 0
                }
            }
        }
        
        lastMousePosition = currentPosition
        lastMouseTime = currentTime
    }
    
    func startDisplayLink() {
        Timer.scheduledTimer(withTimeInterval: 1.0/120.0, repeats: true) { [weak self] _ in
            self?.updateAnimation()
        }
    }
    
    func cloneTarget(for avgVelocity: CGFloat, growthDuration: TimeInterval) -> Int {
        let multiplicationRatio = max(0, avgVelocity / multiplicationVelocityThreshold - 1.0)
        guard multiplicationRatio > 0 else { return 0 }
        let speedContribution = pow(multiplicationRatio, 1.35) * 6.0
        let durationContribution = CGFloat(growthDuration) * multiplicationRatio * 4.0
        return Int(speedContribution + durationContribution)
    }
    
    func makeClone() -> CursorClone {
        let angle = CGFloat.random(in: 0...(2 * .pi))
        let launchSpeed = CGFloat.random(in: 900...2400)
        let launchVelocity = CGPoint(
            x: cos(angle) * launchSpeed,
            y: sin(angle) * launchSpeed
        )
        
        return CursorClone(
            offset: .zero,
            velocity: launchVelocity,
            angle: angle,
            angularVelocity: CGFloat.random(in: -3.6...3.6),
            opacity: 0.0
        )
    }
    
    func synchronizeClonePool() {
        while cursorClones.count < targetCloneCount {
            cursorClones.append(makeClone())
        }
    }
    
    func updateAnimation() {
        let now = Date()
        let rawDelta = now.timeIntervalSince(lastAnimationTime)
        let deltaTime = max(1.0 / 240.0, min(rawDelta, 1.0 / 30.0))
        lastAnimationTime = now
        let wasVisible = currentScale > minScale + 0.01
        
        if isGrowing {
            currentScale = currentScale + (targetScale - currentScale) * 0.3
        } else {
            currentScale = max(currentScale * shrinkRate, minScale)
            targetScale = minScale
            targetCloneCount = max(0, cursorClones.count - 1)
        }
        
        synchronizeClonePool()
        updateClones(deltaTime: CGFloat(deltaTime))
        
        let isVisible = currentScale > minScale + 0.01
        let renderCursors = [RenderCursor(position: lastMousePosition, opacity: 1.0)] + cursorClones.map {
            RenderCursor(
                position: CGPoint(x: lastMousePosition.x + $0.offset.x, y: lastMousePosition.y + $0.offset.y),
                opacity: $0.opacity
            )
        }
        
        if isVisible && !wasVisible {
            hideSystemCursor()
        } else if !isVisible && wasVisible {
            showSystemCursor()
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            for cursorView in self.cursorViews {
                cursorView.cursors = renderCursors
                cursorView.scale = self.currentScale
                cursorView.isVisible = isVisible
                cursorView.needsDisplay = true
            }
        }
    }
    
    func updateClones(deltaTime: CGFloat) {
        guard !cursorClones.isEmpty else { return }
        
        let growthProgress = max(0, currentScale - minScale)
        let velocityRatio = max(0, averageVelocity / multiplicationVelocityThreshold)
        
        for index in cursorClones.indices {
            var clone = cursorClones[index]
            let shouldStayExpanded = isGrowing && index < targetCloneCount
            let ring = CGFloat(index / 10)
            let slot = CGFloat(index % 10)
            let ringRadius = 24 + min(growthProgress * 0.18, 220) + velocityRatio * 26 + ring * 22
            
            if shouldStayExpanded {
                clone.angle += clone.angularVelocity * deltaTime
                let slotJitter = (slot / 10.0) * (.pi / 2.5)
                let targetOffset = CGPoint(
                    x: cos(clone.angle + slotJitter) * ringRadius,
                    y: sin(clone.angle + slotJitter) * ringRadius
                )
                let spring = 10.0 + velocityRatio * 2.0
                clone.velocity.x += (targetOffset.x - clone.offset.x) * spring * deltaTime
                clone.velocity.y += (targetOffset.y - clone.offset.y) * spring * deltaTime
                clone.velocity.x *= 0.88
                clone.velocity.y *= 0.88
                clone.opacity = min(clone.opacity + deltaTime * 4.0, 1.0)
            } else {
                clone.velocity.x += -clone.offset.x * 12.0 * deltaTime
                clone.velocity.y += -clone.offset.y * 12.0 * deltaTime
                clone.velocity.x *= 0.76
                clone.velocity.y *= 0.76
                clone.opacity = max(clone.opacity - deltaTime * 3.6, 0.0)
            }
            
            clone.offset.x += clone.velocity.x * deltaTime
            clone.offset.y += clone.velocity.y * deltaTime
            cursorClones[index] = clone
        }
        
        cursorClones.removeAll { clone in
            !isGrowing && clone.opacity <= 0.02 && hypot(clone.offset.x, clone.offset.y) < 1.5
        }
    }
}

class CursorView: NSView {
    var cursors: [RenderCursor] = []
    var screenFrame: NSRect = .zero
    var scale: CGFloat = 1.0
    var isVisible: Bool = false
    var isDarkMode: Bool = true
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        context.clear(bounds)
        
        guard isVisible else { return }

        for cursor in cursors where cursor.opacity > 0.01 {
            drawCursor(at: cursor.position, opacity: cursor.opacity, in: context)
        }
    }
    
    func drawCursor(at globalPosition: CGPoint, opacity: CGFloat, in context: CGContext) {
        let localX = globalPosition.x - screenFrame.origin.x
        let localY = globalPosition.y - screenFrame.origin.y
        
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
        
        let fillColor = (isDarkMode ? NSColor.black : NSColor.white).withAlphaComponent(opacity).cgColor
        let strokeColor = (isDarkMode ? NSColor.white : NSColor.black).withAlphaComponent(opacity).cgColor
        
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
