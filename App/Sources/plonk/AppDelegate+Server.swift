import AppKit

// The loopback control server and the Router behind it: what an agent reaches.

extension AppDelegate {
    func setupServer() {
        router = Router(store: store, windows: windows, awake: awake, active: active, agents: agents)
        router.changes.onEvent = { [weak self] rev, what in
            self?.eventBroadcaster.broadcast(rev: rev, what: what)
        }
        router.attachEvents = { [weak self] conn, rev in
            self?.eventBroadcaster.attach(conn, rev: rev)
        }
        // Every source of change funnels into the bus at its own choke point,
        // so no caller has to remember to announce itself. Config, the widest
        // of them, is wired in AppDelegate.watchConfig.
        windows.onDidPlace = { [weak self] in
            self?.router.changes.bump("windows")
            self?.markGettingStarted { $0.sawFirstSnap = true }
        }
        agents.onChange = { [weak self] in
            self?.refreshAgentModel()
            self?.router.changes.bump("agents")
        }
        // Only the part that is not a config change: an agent editing zones
        // shows them, so the user sees what it did.
        router.didChangeZones = { [weak self] in self?.dragSnap.previewZones() }
        setupShotRoutes()
        router.launchWorkspace = { [weak self] name, workspace, screen, done in
            guard let self else { return done([["ok": false, "error": "shutting down"]]) }
            launcher.launch(workspace, named: name, onScreen: screen, completion: done)
        }
        router.runAdapter = { [weak self] adapter, prompt in
            self?.launchAdapter(adapter, prompt: prompt)
        }

        let token = APIToken.loadOrCreate()
        if token == nil {
            model.apiWarning = String(localized: .warningNoToken(APIToken.url().path))
        }
        let server = ControlServer(token: token) { [weak self] request, respond in
            guard let self else { return respond(.failed("shutting down")) }
            router.handle(request, respond: respond)
        }
        server.onUnavailable = { [weak self] message in self?.model.apiWarning = message }
        do {
            try server.start()
        } catch {
            NSLog("Plonk: failed to start control server: \(error)")
            model.apiWarning = String(localized: .warningApiDidNotStart)
        }
        self.server = server
    }
}
