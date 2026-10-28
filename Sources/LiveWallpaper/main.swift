import AppKit
import AVFoundation
import IOKit.ps
import ServiceManagement
import UniformTypeIdentifiers

// MARK: - Окно обоев (уровень рабочего стола, под иконками)

final class WallpaperWindow: NSWindow {
    let playerLayer = AVPlayerLayer()

    init(screen: NSScreen, player: AVPlayer, gravity: AVLayerVideoGravity) {
        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        setFrame(screen.frame, display: false)
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        ignoresMouseEvents = true
        isOpaque = true
        hasShadow = false
        backgroundColor = .black
        isReleasedWhenClosed = false

        let view = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
        view.wantsLayer = true
        playerLayer.player = player
        playerLayer.videoGravity = gravity
        playerLayer.frame = view.bounds
        playerLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        playerLayer.backgroundColor = NSColor.black.cgColor
        view.layer?.addSublayer(playerLayer)
        contentView = view
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

// MARK: - Приложение

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let player = AVQueuePlayer()
    private var looper: AVPlayerLooper?
    private var windows: [WallpaperWindow] = []
    private let defaults = UserDefaults.standard

    private var userPaused = false
    private var screensAsleep = false
    private var screenLocked = false

    // Пункты меню
    private let pauseItem = NSMenuItem(title: "Пауза", action: #selector(togglePause), keyEquivalent: "p")
    private let soundItem = NSMenuItem(title: "Звук", action: #selector(toggleSound), keyEquivalent: "")
    private let fitItem = NSMenuItem(title: "Вписать без обрезки", action: #selector(toggleFit), keyEquivalent: "")
    private let batteryItem = NSMenuItem(title: "Пауза от батареи", action: #selector(toggleBattery), keyEquivalent: "")
    private let loginItem = NSMenuItem(title: "Запускать при входе", action: #selector(toggleLogin), keyEquivalent: "")
    private let currentItem = NSMenuItem(title: "Видео не выбрано", action: nil, keyEquivalent: "")

    private var gravity: AVLayerVideoGravity { defaults.bool(forKey: "fit") ? .resizeAspect : .resizeAspectFill }
    private var pauseOnBattery: Bool { defaults.object(forKey: "pauseOnBattery") as? Bool ?? true }

    func applicationDidFinishLaunching(_ notification: Notification) {
        player.isMuted = !defaults.bool(forKey: "sound")
        player.preventsDisplaySleepDuringVideoPlayback = false   // не мешаем маку гасить экран
        player.actionAtItemEnd = .advance

        setupStatusItem()
        rebuildWindows()
        setupObservers()

        if let path = defaults.string(forKey: "videoPath"), FileManager.default.fileExists(atPath: path) {
            load(URL(fileURLWithPath: path))
        } else {
            chooseVideo()
        }
    }

    // MARK: Меню

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "play.rectangle.fill", accessibilityDescription: "Живые обои")

        let menu = NSMenu()
        menu.delegate = self
        currentItem.isEnabled = false
        menu.addItem(currentItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Выбрать видео…", action: #selector(chooseVideo), keyEquivalent: "o"))
        menu.addItem(pauseItem)
        menu.addItem(soundItem)
        menu.addItem(fitItem)
        menu.addItem(.separator())
        menu.addItem(batteryItem)
        menu.addItem(loginItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Выйти", action: #selector(quit), keyEquivalent: "q"))
        for item in menu.items { item.target = self }
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        pauseItem.title = userPaused ? "Продолжить" : "Пауза"
        soundItem.state = player.isMuted ? .off : .on
        fitItem.state = defaults.bool(forKey: "fit") ? .on : .off
        batteryItem.state = pauseOnBattery ? .on : .off
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        if let path = defaults.string(forKey: "videoPath") {
            currentItem.title = (path as NSString).lastPathComponent
        }
    }

    // MARK: Видео

    @objc private func chooseVideo() {
        let panel = NSOpenPanel()
        panel.title = "Выбери видео для обоев"
        panel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url {
            load(url)
        }
    }

    private func load(_ url: URL) {
        looper?.disableLooping()
        looper = nil
        player.removeAllItems()
        let item = AVPlayerItem(url: url)
        looper = AVPlayerLooper(player: player, templateItem: item)
        defaults.set(url.path, forKey: "videoPath")
        updatePlayback()
    }

    // MARK: Окна на всех мониторах

    @objc private func rebuildWindows() {
        windows.forEach { $0.orderOut(nil) }
        windows = NSScreen.screens.map { screen in
            let w = WallpaperWindow(screen: screen, player: player, gravity: gravity)
            w.orderFront(nil)
            return w
        }
        updatePlayback()
    }

    // MARK: Когда играть, а когда экономить батарею

    private var onBattery: Bool {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let type = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() else { return false }
        return (type as String) == kIOPSBatteryPowerValue
    }

    private var anyWindowVisible: Bool {
        windows.contains { $0.occlusionState.contains(.visible) }
    }

    @objc private func updatePlayback() {
        let shouldPlay = looper != nil
            && !userPaused
            && !screensAsleep
            && !screenLocked
            && anyWindowVisible
            && !(pauseOnBattery && onBattery)
        if shouldPlay {
            if player.rate == 0 { player.play() }
        } else if player.rate != 0 {
            player.pause()
        }
    }

    private func setupObservers() {
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(rebuildWindows),
                       name: NSApplication.didChangeScreenParametersNotification, object: nil)
        nc.addObserver(self, selector: #selector(updatePlayback),
                       name: NSWindow.didChangeOcclusionStateNotification, object: nil)

        let ws = NSWorkspace.shared.notificationCenter
        ws.addObserver(self, selector: #selector(screensSlept), name: NSWorkspace.screensDidSleepNotification, object: nil)
        ws.addObserver(self, selector: #selector(screensWoke), name: NSWorkspace.screensDidWakeNotification, object: nil)
        ws.addObserver(self, selector: #selector(screensSlept), name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        ws.addObserver(self, selector: #selector(screensWoke), name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)

        let dnc = DistributedNotificationCenter.default()
        dnc.addObserver(self, selector: #selector(locked), name: .init("com.apple.screenIsLocked"), object: nil)
        dnc.addObserver(self, selector: #selector(unlocked), name: .init("com.apple.screenIsUnlocked"), object: nil)

        // Проверка питания раз в 20 секунд
        let t = Timer(timeInterval: 20, target: self, selector: #selector(updatePlayback), userInfo: nil, repeats: true)
        RunLoop.main.add(t, forMode: .common)
    }

    @objc private func screensSlept() { screensAsleep = true; updatePlayback() }
    @objc private func screensWoke() { screensAsleep = false; updatePlayback() }
    @objc private func locked() { screenLocked = true; updatePlayback() }
    @objc private func unlocked() { screenLocked = false; updatePlayback() }

    // MARK: Действия меню

    @objc private func togglePause() { userPaused.toggle(); updatePlayback() }

    @objc private func toggleSound() {
        player.isMuted.toggle()
        defaults.set(!player.isMuted, forKey: "sound")
    }

    @objc private func toggleFit() {
        defaults.set(!defaults.bool(forKey: "fit"), forKey: "fit")
        windows.forEach { $0.playerLayer.videoGravity = gravity }
    }

    @objc private func toggleBattery() {
        defaults.set(!pauseOnBattery, forKey: "pauseOnBattery")
        updatePlayback()
    }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Не получилось изменить автозапуск"
            alert.informativeText = error.localizedDescription
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }

    @objc private func quit() { NSApp.terminate(nil) }
}

// MARK: - Точка входа

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
