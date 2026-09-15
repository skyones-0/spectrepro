import Foundation
import Testing
@testable import SpectrePro

@MainActor
struct EnterpriseSessionsTests {

    // MARK: - 1. SavedSession & Connect Command Generation Tests

    @Test func testSavedSessionBasicSSH() {
        let session = SavedSession(name: "Basic Server", host: "192.168.1.100")
        let cmd = session.buildConnectCommand()
        #expect(cmd.contains("ssh"))
        #expect(cmd.contains("-o ControlMaster=auto"))
        #expect(cmd.contains("-o ControlPath=/tmp/spectre-ssh-%C.sock"))
        #expect(cmd.contains("-o ControlPersist=10m"))
        #expect(cmd.contains("192.168.1.100"))
        #expect(!cmd.contains("-p"))
        #expect(!cmd.contains("@"))
    }

    @Test func testSSHProcessSpecKeepsArgumentsSeparated() throws {
        let session = SavedSession(
            name: "Production; touch /tmp/should-not-run",
            host: "server.example.com",
            user: "operator",
            initialCommand: "printf 'safe; text'"
        )

        let spec = try session.buildProcessSpec()
        #expect(spec.executable == "/usr/bin/ssh")
        #expect(spec.arguments.contains("operator@server.example.com"))
        #expect(spec.arguments.contains("printf 'safe; text'"))
        #expect(!spec.arguments.joined(separator: " ").contains("&&"))
    }

    @Test func testLegacySessionDefaultsToAutomaticAuthentication() throws {
        let data = #"{"name":"Legacy","host":"server.example.com"}"#.data(using: .utf8)!
        let session = try JSONDecoder().decode(SavedSession.self, from: data)

        #expect(session.sshAuthentication == .automatic)
        #expect(session.pkcs11Provider == nil)
    }

    @Test func testPIVProviderIsPassedToSSH() throws {
        let session = SavedSession(
            name: "YubiKey Server",
            host: "server.example.com",
            sshAuthentication: .yubikeyPIV,
            pkcs11Provider: "/Library/Application Support/Yubico/libykcs11.dylib"
        )

        let spec = try session.buildProcessSpec()

        #expect(spec.arguments.contains("-I"))
        #expect(spec.arguments.contains("/Library/Application Support/Yubico/libykcs11.dylib"))
        #expect(!spec.arguments.contains("-i"))
    }

    @Test func testInvalidPKCS11ProviderIsRejected() {
        let session = SavedSession(
            name: "Invalid YubiKey",
            host: "server.example.com",
            sshAuthentication: .yubikeyPIV,
            pkcs11Provider: "-unsafe-provider"
        )

        #expect(SessionValidator.validate(session).contains(.invalidPKCS11Provider))
    }

    @Test func testPIVProviderIsPassedToFileTransfers() {
        let context = ActiveSSHContext(
            host: "server.example.com",
            sshAuthentication: .yubikeyPIV,
            pkcs11Provider: "/opt/homebrew/lib/libykcs11.dylib"
        )

        #expect(context.buildBaseSCPArguments().contains("-I"))
        #expect(context.buildBaseSCPArguments().contains("/opt/homebrew/lib/libykcs11.dylib"))
        #expect(context.buildBaseSFTPArguments().contains("-I"))
        #expect(context.buildBaseSFTPArguments().contains("/opt/homebrew/lib/libykcs11.dylib"))
        #expect(context.scpExecutable.hasSuffix("/scp"))
        #expect(context.sftpExecutable.hasSuffix("/sftp"))
    }

    @Test func testSessionValidatorRejectsShellSyntax() {
        let invalid = SavedSession(name: "Test", host: "server.example.com; touch /tmp/x")
        #expect(SessionValidator.validate(invalid).contains(.invalidHost))

        let invalidUser = SavedSession(name: "Test", host: "server.example.com", user: "admin;rm")
        #expect(SessionValidator.validate(invalidUser).contains(.invalidUser))
    }

    @Test func testSessionRuntimeOwnsIndependentComponents() {
        let first = SessionRuntimeRegistry.shared.runtime(for: UUID())
        let second = SessionRuntimeRegistry.shared.runtime(for: UUID())
        #expect(first.logger !== second.logger)
        #expect(first.automation !== second.automation)
        #expect(first.transfers !== second.transfers)
    }

    @Test func testSavedSessionDoesNotPersistCredentialSecret() throws {
        let secret = "Never write this password to disk"
        let session = SavedSession(
            name: "Protected Server",
            host: "server.example.com",
            credentialReference: CredentialReference()
        )

        let encoded = try String(decoding: JSONEncoder().encode(session), as: UTF8.self)
        #expect(encoded.contains(session.credentialReference!.id.uuidString))
        #expect(!encoded.contains(secret))
        #expect(!encoded.localizedCaseInsensitiveContains("password"))
    }

    @Test func testRuntimeResetStopsSessionState() {
        let surfaceID = UUID()
        let runtime = SessionRuntimeRegistry.shared.runtime(for: surfaceID)
        runtime.attach(SavedSession(name: "Reset Me", host: "server.example.com"))
        #expect(runtime.session != nil)

        runtime.reset()

        #expect(runtime.session == nil)
        #expect(!runtime.transfers.hasActiveSSHContext(for: surfaceID))
        SessionRuntimeRegistry.shared.remove(surfaceID: surfaceID)
    }

    @Test func testSSHReconnectUsesBoundedBackoff() {
        let controller = SSHReconnectController(maximumAttempts: 3)
        #expect(controller.disconnected() == 1)
        #expect(controller.disconnected() == 2)
        #expect(controller.disconnected() == 4)
        #expect(controller.disconnected() == nil)
        #expect(controller.state == .exhausted)

        controller.connected()
        #expect(controller.state == .connected)
        #expect(controller.disconnected() == 1)
    }

    @Test func testAutomationPolicyRequiresDeclaredPermissions() {
        let script = AutomationScript(
            name: "Production deploy",
            source: "deploy",
            permissions: [.network, .production]
        )
        let policy = AutomationPolicy(grantedPermissions: [.network, .production])
        #expect(throws: AutomationPolicyError.productionConfirmationRequired) {
            try policy.authorize(script)
        }
        #expect(throws: Never.self) {
            try policy.authorize(script, productionConfirmed: true)
        }
    }

    @Test func testAutomationExecutorReportsEachTarget() async {
        let firstTarget = UUID()
        let secondTarget = UUID()
        let script = AutomationScript(
            name: "Safe check",
            source: "health check",
            permissions: [.network],
            targetSessionIDs: [firstTarget, secondTarget]
        )
        let plan = AutomationPlan(
            script: script,
            steps: [AutomationStep(command: "uptime")]
        )
        let executor = AutomationExecutor()
        var sent: [(UUID, String)] = []
        executor.run(plan: plan, policy: AutomationPolicy(grantedPermissions: [.network])) { targetID, command in
            sent.append((targetID, command))
            return true
        }
        for _ in 0..<20 where executor.isRunning {
            try? await Task.sleep(for: .milliseconds(10))
        }
        #expect(sent.count == 2)
        #expect(executor.results.count == 2)
        #expect(executor.results.allSatisfy { !$0.failed && $0.sentSteps == 1 })
    }

    @Test func testSavedSessionFullParameters() {
        let forwards = [
            PortForwardRule(type: .local, localPort: 8080, remoteHost: "127.0.0.1", remotePort: 80),
            PortForwardRule(type: .remote, localPort: 3000, remoteHost: "localhost", remotePort: 9000),
            PortForwardRule(type: .dynamic, localPort: 1080)
        ]

        let session = SavedSession(
            name: "Core Router",
            host: "router.corp.internal",
            user: "admin",
            port: 2222,
            identityFile: "~/.ssh/id_ed25519",
            jumpHost: "bastion.corp.internal",
            forwardAgent: true,
            compression: true,
            keepAliveInterval: 45,
            initialCommand: "show ip route",
            environmentBadge: "PROD",
            portForwards: forwards
        )

        let cmd = session.buildConnectCommand()

        #expect(cmd.contains("admin@router.corp.internal"))
        #expect(cmd.contains("-p 2222"))
        #expect(cmd.contains("-i "))
        #expect(cmd.contains("id_ed25519"))
        #expect(cmd.contains("-J \"bastion.corp.internal\""))
        #expect(cmd.contains("-A"))
        #expect(cmd.contains("-C"))
        #expect(cmd.contains("-o ServerAliveInterval=45"))
        #expect(cmd.contains("-L 8080:127.0.0.1:80"))
        #expect(cmd.contains("-R 9000:localhost:3000"))
        #expect(cmd.contains("-D 1080"))
        #expect(cmd.contains("-t \"show ip route\""))
        #expect(session.environmentBadge == "PROD")
    }

    @Test func testSavedSessionTelnetAndConsole() {
        let telnet = SavedSession(name: "Legacy Switch", host: "10.0.0.1", port: 2323, sessionType: "telnet")
        #expect(telnet.buildConnectCommand() == "telnet 10.0.0.1 2323")

        let serial = SavedSession(name: "Cisco Console", host: "/dev/cu.usbserial-0001", port: 9600, sessionType: "console")
        #expect(serial.buildConnectCommand() == "screen /dev/cu.usbserial-0001 9600")
    }

    @Test func testSavedSessionCodableRoundTrip() throws {
        let original = SavedSession(
            name: "Database Cluster",
            folder: "Databases/Postgres",
            host: "db1.prod",
            user: "postgres",
            port: 54322,
            environmentBadge: "PROD",
            portForwards: [PortForwardRule(type: .local, localPort: 5432, remoteHost: "127.0.0.1", remotePort: 5432)]
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SavedSession.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.name == "Database Cluster")
        #expect(decoded.folder == "Databases/Postgres")
        #expect(decoded.host == "db1.prod")
        #expect(decoded.user == "postgres")
        #expect(decoded.port == 54322)
        #expect(decoded.environmentBadge == "PROD")
        #expect(decoded.portForwards.count == 1)
        #expect(decoded.portForwards[0].sshArgument == "-L 5432:127.0.0.1:5432")
    }

    // MARK: - 2. ActiveSSHContext & SSHTransferManager Tests

    @Test func testActiveSSHContext() {
        let context = ActiveSSHContext(
            host: "server.example.com",
            user: "deployer",
            port: 2200,
            identityFile: "~/.ssh/id_rsa",
            jumpHost: "jump.example.com"
        )

        #expect(context.targetSpec == "deployer@server.example.com")
        let args = context.buildBaseSCPArguments()
        #expect(args.contains("-o"))
        #expect(args.contains("ControlMaster=auto"))
        #expect(args.contains("ControlPath=/tmp/spectre-ssh-%C.sock"))
        #expect(args.contains("-P"))
        #expect(args.contains("2200"))
        #expect(args.contains("-J"))
        #expect(args.contains("jump.example.com"))
        #expect(args.contains("StrictHostKeyChecking=ask"))
        #expect(args.contains("ServerAliveCountMax=3"))
        #expect(args.contains("ConnectionAttempts=3"))

        let sftpArgs = context.buildBaseSFTPArguments()
        #expect(sftpArgs.contains("ProxyJump=jump.example.com"))
        #expect(sftpArgs.last == "deployer@server.example.com")
    }

    @Test func testSFTPDirectoryEntryIdentity() {
        let entry = SFTPDirectoryEntry(name: "logs", path: "/var/logs", isDirectory: true)
        #expect(entry.id == "/var/logs")
        #expect(entry.isDirectory)
    }

    @Test func testSSHTransferManagerRegistration() {
        let manager = SSHTransferManager.shared
        let surfaceId = UUID()
        let session = SavedSession(
            name: "Cloud Node",
            host: "node.cloud.io",
            user: "ubuntu",
            port: 22
        )

        manager.registerContext(for: surfaceId, session: session)
        #expect(manager.hasActiveSSHContext(for: surfaceId) == true)
        let ctx = manager.context(for: surfaceId)
        #expect(ctx != nil)
        #expect(ctx?.host == "node.cloud.io")
        #expect(ctx?.user == "ubuntu")
        #expect(ctx?.targetSpec == "ubuntu@node.cloud.io")
    }

    // MARK: - 3. Keyword Highlighter Engine Tests

    @Test func testKeywordHighlighterDetection() {
        let highlighter = KeywordHighlighter.shared
        highlighter.isEnabled = true

        let sampleTerminalOutput = """
        [12:00:01] Interface GigabitEthernet0/1 is UP, line protocol is UP
        [12:00:02] Connected to 192.168.10.254 via MAC 00:1A:2B:3C:4D:5E
        [12:00:03] BGP neighbor 10.0.0.1 state is ESTABLISHED
        [12:00:04] ERROR: Authentication failed for user guest - DENIED
        [12:00:05] WARNING: CPU temperature high, TIMEOUT detected on node 172.16.0.50
        [12:00:06] CRITICAL: Power supply 2 is DOWN, system PANIC avoided
        """

        highlighter.scan(text: sampleTerminalOutput)

        #expect(highlighter.totalMatchesCount > 0)

        let words = highlighter.detectedMatches.map { $0.text.uppercased() }

        // Validate Error matches
        #expect(words.contains("ERROR"))
        #expect(words.contains("DENIED"))
        #expect(words.contains("CRITICAL"))
        #expect(words.contains("DOWN"))
        #expect(words.contains("PANIC"))

        // Validate Success / Up matches
        #expect(words.contains("UP"))
        #expect(words.contains("ESTABLISHED"))

        // Validate Warning matches
        #expect(words.contains("WARNING"))
        #expect(words.contains("TIMEOUT"))

        // Validate Network IP matches
        let ips = highlighter.detectedMatches.filter { $0.category == .networkIP }.map { $0.text }
        #expect(ips.contains("192.168.10.254"))
        #expect(ips.contains("10.0.0.1"))
        #expect(ips.contains("172.16.0.50"))

        // Validate MAC address matches
        let macs = highlighter.detectedMatches.filter { $0.category == .networkMAC }.map { $0.text }
        #expect(macs.contains("00:1A:2B:3C:4D:5E"))
    }

    @Test func testKeywordHighlighterToggle() {
        let highlighter = KeywordHighlighter.shared
        highlighter.isEnabled = false
        highlighter.scan(text: "ERROR DOWN CRITICAL 192.168.1.1")
        #expect(highlighter.detectedMatches.isEmpty)
        #expect(highlighter.totalMatchesCount == 0)
        highlighter.isEnabled = true
    }

    // MARK: - 4. Forensic Session Logger Tests

    @Test func testSessionLoggerCreationAndANSIStripping() throws {
        let logger = SessionLogger.shared
        let testSessionName = "UnitTest_Logging_\(UUID().uuidString.prefix(6))"

        logger.prependTimestamps = true
        logger.stripANSI = true

        logger.startRecording(sessionName: testSessionName)
        #expect(logger.isRecording == true)
        #expect(logger.currentLogURL != nil)

        // Log ANSI colorized text
        let coloredMessage = "\u{1B}[31m[ERROR]\u{1B}[0m Connection reset by \u{1B}[32m192.168.1.50\u{1B}[0m\n"
        logger.log(text: coloredMessage)

        let logURL = logger.stopRecording()
        #expect(logger.isRecording == false)
        #expect(logURL != nil)

        // Read recorded file
        let fileContent = try String(contentsOf: logURL!, encoding: .utf8)

        // Assert header exists
        #expect(fileContent.contains("=== Spectre Pro Session Log: \(testSessionName) ==="))
        #expect(fileContent.contains("=== Session Ended:"))

        // Assert ANSI sequence was stripped
        #expect(!fileContent.contains("\u{1B}[31m"))
        #expect(!fileContent.contains("\u{1B}[0m"))
        #expect(fileContent.contains("[ERROR] Connection reset by 192.168.1.50"))

        // Assert timestamps were prepended
        #expect(fileContent.contains("[202"))

        // Clean up test log file
        try? FileManager.default.removeItem(at: logURL!)
    }

    // MARK: - 5. ExpectSendEngine Rule Validation Tests

    @Test func testExpectSendEngineRuleDefinition() {
        let rule1 = ExpectSendRule(expect: "Username:", send: "admin")
        let rule2 = ExpectSendRule(expect: "Password:", send: "SecretPass123")
        let rule3 = ExpectSendRule(expect: "Router>", send: "enable")

        #expect(rule1.expect == "Username:")
        #expect(rule1.send == "admin")
        #expect(rule2.expect == "Password:")
        #expect(rule3.send == "enable")

        let engine = ExpectSendEngine.shared
        #expect(engine.isRunning == false)
    }

    // MARK: - 6. Serial Hardware Tools & Throttling Tests

    @Test func testSerialConnectionConfig() {
        let standardConfig = SerialConnectionConfig.default(for: "/dev/cu.usbserial-A101", name: "Switch Console")
        #expect(standardConfig.devicePath == "/dev/cu.usbserial-A101")
        #expect(standardConfig.baudRate == 115200)
        #expect(standardConfig.dataBits == 8)
        #expect(standardConfig.parity == "None")
        #expect(standardConfig.buildLaunchCommand() == "screen /dev/cu.usbserial-A101 115200")

        var ciscoConfig = SerialConnectionConfig.default(for: "/dev/cu.usbserial-0001", name: "Cisco Catalyst")
        ciscoConfig.baudRate = 9600
        ciscoConfig.lineDelayMs = 50
        ciscoConfig.charDelayMs = 2

        #expect(ciscoConfig.buildLaunchCommand() == "screen /dev/cu.usbserial-0001 9600")
        #expect(ciscoConfig.lineDelayMs == 50)
        #expect(ciscoConfig.charDelayMs == 2)
    }

    @Test func testSerialSettingsReachNativeSurfaceConfiguration() {
        var config = SerialConnectionConfig.default(for: "/dev/cu.usbserial-A101")
        config.baudRate = 9600
        config.dataBits = 7
        config.parity = "Even"
        config.stopBits = 2
        config.flowControl = "Software"
        let surfaceConfiguration = SpectrePro.SurfaceConfiguration(serial: config)

        #expect(surfaceConfiguration.serialDevice == "/dev/cu.usbserial-A101")
        #expect(surfaceConfiguration.serialBaudRate == 9600)
        #expect(surfaceConfiguration.serialDataBits == 7)
        #expect(surfaceConfiguration.serialParity == 2)
        #expect(surfaceConfiguration.serialStopBits == 2)
        #expect(surfaceConfiguration.serialFlowControl == 2)
    }

    @Test func testSerialConfigurationMapsToNativeBackend() {
        var config = SerialConnectionConfig.default(for: "/dev/cu.usbserial-A101")
        config.baudRate = 9600
        config.dataBits = 7
        config.parity = "Odd"
        config.stopBits = 2
        config.flowControl = "Hardware"

        let surfaceConfiguration = SpectrePro.SurfaceConfiguration(serial: config)
        #expect(surfaceConfiguration.serialDevice == "/dev/cu.usbserial-A101")
        #expect(surfaceConfiguration.serialBaudRate == 9600)
        #expect(surfaceConfiguration.serialDataBits == 7)
        #expect(surfaceConfiguration.serialParity == 1)
        #expect(surfaceConfiguration.serialStopBits == 2)
        #expect(surfaceConfiguration.serialFlowControl == 1)
    }

    @Test func testSerialDisconnectUsesNormalTerminalConfiguration() {
        var serialConfig = SerialConnectionConfig.default(for: "/dev/cu.usbserial-A101")
        serialConfig.baudRate = 230400
        let serialSurface = SpectrePro.SurfaceConfiguration(serial: serialConfig)
        let disconnectedSurface = SpectrePro.SurfaceConfiguration()

        #expect(serialSurface.serialDevice != nil)
        #expect(disconnectedSurface.serialDevice == nil)
        #expect(disconnectedSurface.serialBaudRate == 115200)
        #expect(serialSurface.serialParity == 0)
        #expect(serialSurface.serialStopBits == 1)
        #expect(serialSurface.serialFlowControl == 0)
    }

    @Test func testSerialRescanPreservesConfigurationForSameDevice() {
        #expect(SerialInspectorSelection.requiresConfigurationReset(
            previousPath: "/dev/cu.usbserial-A101",
            newPath: "/dev/cu.usbserial-A101"
        ) == false)
        #expect(SerialInspectorSelection.requiresConfigurationReset(
            previousPath: "/dev/cu.usbserial-A101",
            newPath: "/dev/cu.usbserial-B202"
        ) == true)
        #expect(SerialInspectorSelection.requiresConfigurationReset(
            previousPath: nil,
            newPath: "/dev/cu.usbserial-A101"
        ) == true)
    }

    @Test func testSerialPasteEngineUsesConfiguredDelays() async throws {
        actor Recorder {
            var sent: [String] = []
            var sleeps: [UInt64] = []

            func recordText(_ text: String) {
                sent.append(text)
            }

            func recordSleep(_ nanoseconds: UInt64) {
                sleeps.append(nanoseconds)
            }
        }

        let recorder = Recorder()
        try await SerialPasteEngine.paste(
            "ab\ncd",
            lineDelayMs: 50,
            charDelayMs: 2,
            sendText: { text in await recorder.recordText(text) },
            sleep: { nanoseconds in await recorder.recordSleep(nanoseconds) }
        )

        #expect(await recorder.sent == ["a", "b", "\n", "c", "d", "\n"])
        #expect(await recorder.sleeps == [2_000_000, 2_000_000, 50_000_000, 2_000_000, 2_000_000])
    }

    @Test func testSerialPasteEngineDoesNotSleepWhenDelaysAreDisabled() async throws {
        actor Recorder {
            var sleeps = 0

            func recordSleep() {
                sleeps += 1
            }
        }

        let recorder = Recorder()
        try await SerialPasteEngine.paste(
            "a\nb",
            lineDelayMs: 0,
            charDelayMs: 0,
            sendText: { _ in },
            sleep: { _ in await recorder.recordSleep() }
        )

        #expect(await recorder.sleeps == 0)
    }

    // MARK: - 7. High-Throughput, Concurrency & Stress Benchmark Tests

    @Test func testKeywordHighlighterStressThroughput() {
        let highlighter = KeywordHighlighter.shared
        highlighter.isEnabled = true

        // Generate 10,000 lines of simulated log stream with high frequency of IPs, errors, and statuses
        var buffer = ""
        buffer.reserveCapacity(2_000_000)
        for i in 1...10_000 {
            let status = (i % 5 == 0) ? "ERROR" : ((i % 3 == 0) ? "UP" : "OK")
            let ip = "10.\(i % 256).\(i % 128).1"
            let mac = String(format: "%02X:%02X:%02X:%02X:%02X:%02X", i % 256, (i+1)%256, (i+2)%256, 10, 20, 30)
            buffer += "Line \(i): Node \(mac) status=\(status) addr=\(ip) - Process completed\n"
        }

        let start = DispatchTime.now()
        highlighter.scan(text: buffer)
        let end = DispatchTime.now()

        let nanoTime = end.uptimeNanoseconds - start.uptimeNanoseconds
        let timeIntervalMs = Double(nanoTime) / 1_000_000

        #expect(highlighter.totalMatchesCount >= 20_000)
        // High throughput requirement: scanning 10,000 lines must complete in under 500ms
        print("Stress Benchmark: Scanned 10,000 lines (\(buffer.count) chars) in \(timeIntervalMs) ms")
        #expect(timeIntervalMs < 500.0)
    }

    @Test func testSessionLoggerStressThroughput() throws {
        let logger = SessionLogger.shared
        let stressSessionName = "StressLog_\(UUID().uuidString.prefix(6))"

        logger.prependTimestamps = false // High speed pure raw write benchmark
        logger.stripANSI = true

        logger.startRecording(sessionName: stressSessionName)
        let start = DispatchTime.now()

        for i in 1...5_000 {
            logger.log(text: "\u{1B}[32m[INFO]\u{1B}[0m Packet #\(i) received from 172.16.1.\(i % 255): checksum valid\n")
        }

        let end = DispatchTime.now()
        let logURL = logger.stopRecording()

        let nanoTime = end.uptimeNanoseconds - start.uptimeNanoseconds
        let timeIntervalMs = Double(nanoTime) / 1_000_000

        print("SessionLogger Benchmark: Flushed 5,000 log events in \(timeIntervalMs) ms")
        #expect(timeIntervalMs < 1000.0)
        #expect(logURL != nil)

        if let url = logURL {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let size = attributes[.size] as? Int64 ?? 0
            #expect(size > 100_000) // Over 100KB of cleanly written logs
            try? FileManager.default.removeItem(at: url)
        }
    }

    @Test func testConcurrentSessionContextsLoad() {
        let manager = SSHTransferManager.shared

        // Register 100 concurrent session contexts
        var uuids: [UUID] = []
        for i in 1...100 {
            let id = UUID()
            uuids.append(id)
            let s = SavedSession(
                name: "Router-\(i)",
                host: "10.10.\(i).1",
                user: "admin\(i)",
                port: 2200 + i
            )
            manager.registerContext(for: id, session: s)
        }

        // Validate all 100 contexts resolve accurately without collisions
        for (idx, id) in uuids.enumerated() {
            let i = idx + 1
            #expect(manager.hasActiveSSHContext(for: id) == true)
            let ctx = manager.context(for: id)
            #expect(ctx?.host == "10.10.\(i).1")
            #expect(ctx?.user == "admin\(i)")
            #expect(ctx?.port == 2200 + i)
        }
    }

    // MARK: - 8. Phase 0 Security & Isolation Verification Tests

    @Test func testExpectSendRuleWithCredentialReference() throws {
        let credRef = CredentialReference()
        let rule = ExpectSendRule(
            expect: "Password:",
            send: "",
            credentialReference: credRef
        )

        #expect(rule.credentialReference == credRef)
        #expect(rule.send.isEmpty)

        // Ensure serialization includes credential reference and does not contain plain text password
        let data = try JSONEncoder().encode(rule)
        let jsonString = String(decoding: data, as: UTF8.self)
        #expect(jsonString.contains(credRef.id.uuidString))

        let decoded = try JSONDecoder().decode(ExpectSendRule.self, from: data)
        #expect(decoded.credentialReference == credRef)
        #expect(decoded.expect == "Password:")
    }

    @Test func testSessionFileEnvelopeMigration() throws {
        // 1. Verify decoding legacy v1 array format
        let legacySession = SavedSession(name: "Legacy Node", host: "legacy.corp")
        let legacyData = try JSONEncoder().encode([legacySession])

        // Directly test envelope migration decoding logic
        var loadedFromLegacy: [SavedSession] = []
        if let envelope = try? JSONDecoder().decode(SessionFileEnvelope.self, from: legacyData) {
            loadedFromLegacy = envelope.sessions
        } else if let legacyList = try? JSONDecoder().decode([SavedSession].self, from: legacyData) {
            loadedFromLegacy = legacyList
        }
        #expect(loadedFromLegacy.count == 1)
        #expect(loadedFromLegacy.first?.name == "Legacy Node")

        // 2. Verify encoding and decoding v2 envelope format
        let v2Envelope = SessionFileEnvelope(sessions: [legacySession])
        #expect(v2Envelope.version == 2)
        let v2Data = try JSONEncoder().encode(v2Envelope)

        let decodedEnvelope = try JSONDecoder().decode(SessionFileEnvelope.self, from: v2Data)
        #expect(decodedEnvelope.version == 2)
        #expect(decodedEnvelope.sessions.first?.name == "Legacy Node")
    }

    @Test func testSessionLoggerSanitizationOfSensitiveTokens() throws {
        let logger = SessionLogger()
        let testSession = "SanitizeTest_\(UUID().uuidString.prefix(6))"

        logger.prependTimestamps = false
        logger.stripANSI = true
        logger.sanitizeSensitiveData = true

        logger.startRecording(sessionName: testSession)

        // Log sensitive streams: password, bearer token, AWS key, private key, JWT, GitHub token
        logger.log(text: "login: admin password: superSecretPassword123\n")
        logger.log(text: "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.doNotLeakThisJWT\n")
        logger.log(text: "AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE\n")
        logger.log(text: "export GITHUB_TOKEN=ghp_abcdefghijklmnopqrstuvwxyz123456\n")
        logger.log(text: "-----BEGIN RSA PRIVATE KEY-----\nMIIEowIBAAKCAQEA0...\n-----END RSA PRIVATE KEY-----\n")

        let logURL = logger.stopRecording()
        #expect(logURL != nil)

        if let url = logURL {
            let content = try String(contentsOf: url, encoding: .utf8)
            #expect(!content.contains("superSecretPassword123"))
            #expect(content.contains("[REDACTED]"))

            #expect(!content.contains("doNotLeakThisJWT"))
            #expect(content.contains("[JWT REDACTED]") || content.contains("[REDACTED]"))

            #expect(!content.contains("AKIAIOSFODNN7EXAMPLE"))
            #expect(!content.contains("ghp_abcdefghijklmnopqrstuvwxyz123456"))
            #expect(!content.contains("MIIEowIBAAKCAQEA0"))
            #expect(content.contains("[PRIVATE KEY REDACTED]"))

            try? FileManager.default.removeItem(at: url)
        }
    }

    @Test func testSessionLoggerIncrementalScreenIngestion() throws {
        let logger = SessionLogger()
        let testSession = "IngestTest_\(UUID().uuidString.prefix(6))"

        logger.prependTimestamps = false
        logger.stripANSI = false
        logger.sanitizeSensitiveData = false

        logger.startRecording(sessionName: testSession)

        // First snapshot
        logger.ingestScreenText("line 1\nline 2\nline 3")
        // Second snapshot: screen scrolled down by 1, added line 4
        logger.ingestScreenText("line 2\nline 3\nline 4")
        // Third snapshot: same screen (no changes)
        logger.ingestScreenText("line 2\nline 3\nline 4")
        // Fourth snapshot: line 5 appended
        logger.ingestScreenText("line 2\nline 3\nline 4\nline 5")

        let logURL = logger.stopRecording()
        #expect(logURL != nil)

        if let url = logURL {
            let content = try String(contentsOf: url, encoding: .utf8)
            // Count occurrences of "line 2" in the file — should appear only ONCE in the log body,
            // not 4 times!
            let occurrences = content.components(separatedBy: "line 2").count - 1
            #expect(occurrences == 1)

            #expect(content.contains("line 1"))
            #expect(content.contains("line 3"))
            #expect(content.contains("line 4"))
            #expect(content.contains("line 5"))

            try? FileManager.default.removeItem(at: url)
        }
    }

    @Test func testSessionCredentialResolverDelegation() throws {
        let resolver: SessionCredentialResolver = DefaultSessionCredentialResolver(store: .shared)
        let ref = CredentialReference()

        // Verify resolver methods work without crashing
        try resolver.store(secret: "testSecret987", for: ref)
        let fetched = try resolver.resolve(ref)
        #expect(fetched == "testSecret987")

        try resolver.delete(ref)
        let afterDelete = try resolver.resolve(ref)
        #expect(afterDelete == nil)
    }

    // MARK: - 9. Phase 1 SSH, Transfers & Reconnection Verification Tests

    @Test func testSSHReconnectControllerAdvancedStates() {
        let controller = SSHReconnectController(maximumAttempts: 3)
        #expect(controller.state == .idle)

        let delay1 = controller.disconnected(reason: "Connection reset by peer")
        #expect(delay1 == 1)
        #expect(controller.history.count == 1)
        #expect(controller.history.first?.reason == "Connection reset by peer")

        // Test Pause
        controller.pause()
        guard case .paused(let attempt) = controller.state else {
            Issue.record("Expected state to be paused")
            return
        }
        #expect(attempt == 1)

        // Test Resume
        let resumedDelay = controller.resume()
        #expect(resumedDelay == 1)
        guard case .waiting(let resumedAttempt, _) = controller.state else {
            Issue.record("Expected state to be waiting")
            return
        }
        #expect(resumedAttempt == 1)

        // Test Cancel
        controller.cancel()
        #expect(controller.state == .cancelled)

        // Reset
        controller.reset()
        #expect(controller.state == .idle)
    }

    @Test func testActiveSSHContextPathEscaping() {
        let pathWithSpaces = "My Documents/Report 2026.pdf"
        let escaped = ActiveSSHContext.escapeRemotePath(pathWithSpaces)
        #expect(escaped == "My\\ Documents/Report\\ 2026.pdf")

        let pathWithQuotes = "test\"file\".log"
        let escapedQuotes = ActiveSSHContext.escapeRemotePath(pathWithQuotes)
        #expect(escapedQuotes.contains("\\\""))
    }

    @Test func testSSHTransferManagerProgressPercentageParsing() {
        let sampleOutput1 = "backup.tar.gz          45%  1024KB  1.5MB/s   00:03"
        let pct1 = SSHTransferManager.parseProgressPercentage(from: sampleOutput1)
        #expect(pct1 == 0.45)

        let sampleOutput2 = "database.sql          100%    12MB  4.2MB/s   00:00"
        let pct2 = SSHTransferManager.parseProgressPercentage(from: sampleOutput2)
        #expect(pct2 == 1.0)

        let sampleOutput3 = "invalid stream without percentage"
        let pct3 = SSHTransferManager.parseProgressPercentage(from: sampleOutput3)
        #expect(pct3 == nil)
    }

    @Test func testSFTPTransferProgressFormatsLiveValues() {
        let progress = SFTPTransferProgress(
            fileName: "backup.tar.gz",
            isUpload: false,
            completedBytes: 1_048_576,
            totalBytes: 2_097_152,
            bytesPerSecond: 524_288,
            estimatedTimeRemaining: 2
        )

        #expect(progress.detailText.contains("of "))
        #expect(progress.detailText.contains("/s"))
        #expect(progress.detailText.contains("00:02 remaining"))
        #expect(!progress.detailText.contains("ByteCountFormatter"))
    }

    @Test func testSSHTransferQueuePriorityAndRetry() {
        let manager = SSHTransferManager.shared
        manager.clearHistory()

        let lowPriority = QueuedTransfer(
            fileName: "low.txt",
            localPath: "/tmp/low.txt",
            remotePath: "./low.txt",
            isUpload: true,
            priority: 1
        )
        let highPriority = QueuedTransfer(
            fileName: "urgent.tar",
            localPath: "/tmp/urgent.tar",
            remotePath: "./urgent.tar",
            isUpload: true,
            priority: 10
        )

        manager.enqueue(lowPriority)
        manager.enqueue(highPriority)

        // Queue should be sorted descending by priority
        #expect(manager.queue.first?.fileName == "urgent.tar")
        #expect(manager.queue.last?.fileName == "low.txt")

        // Cancel urgent transfer -> moves to history
        manager.cancelQueuedTransfer(id: highPriority.id)
        #expect(!manager.queue.contains(where: { $0.id == highPriority.id }))
        #expect(manager.history.first?.fileName == "urgent.tar")
        #expect(manager.history.first?.status == .cancelled)

        // Retry transfer -> moves back to queue
        manager.retryTransfer(id: highPriority.id)
        #expect(manager.queue.contains(where: { $0.id == highPriority.id }))
        #expect(manager.history.isEmpty)

        // Cleanup
        manager.cancelQueuedTransfer(id: lowPriority.id)
        manager.cancelQueuedTransfer(id: highPriority.id)
        manager.clearHistory()
    }

    // MARK: - 10. Phase 2 Professional Automation Verification Tests

    @Test func testAutomationTemplatesBuildValidPlans() {
        for tmpl in AutomationTemplate.allCases {
            let plan = tmpl.buildPlan(targets: [UUID(), UUID()])
            #expect(!plan.script.name.isEmpty)
            #expect(!plan.steps.isEmpty)
            #expect(plan.script.permissions == tmpl.requiredPermissions)
            #expect(plan.script.targetSessionIDs.count == 2)
            #expect(plan.steps.allSatisfy { !$0.command.isEmpty })
        }
    }

    @Test func testAutomationExecutorPreviewMode() {
        let executor = AutomationExecutor.shared
        let plan = AutomationTemplate.healthCheck.buildPlan(targets: [UUID(), UUID()])
        let policy = AutomationPolicy(grantedPermissions: [.network])

        let preview = executor.preview(plan: plan, policy: policy)
        #expect(preview.isAuthorized)
        #expect(preview.targetCount == 2)
        #expect(preview.stepCount == plan.steps.count)
        #expect(preview.missingPermissions.isEmpty)
        #expect(!preview.requiresProductionConfirmation)
        #expect(preview.validationError == nil)

        // Missing permission preview
        let unauthPolicy = AutomationPolicy(grantedPermissions: [])
        let unauthPreview = executor.preview(plan: plan, policy: unauthPolicy)
        #expect(!unauthPreview.isAuthorized)
        #expect(unauthPreview.missingPermissions.contains(.network))
    }

    @Test func testAutomationPolicyTargetLimits() {
        let policy = AutomationPolicy(grantedPermissions: [.network], maxTargets: 3)
        let script = AutomationScript(
            name: "Oversized run",
            source: "uptime",
            permissions: [.network],
            targetSessionIDs: [UUID(), UUID(), UUID(), UUID()] // 4 targets > limit 3
        )
        #expect(throws: AutomationPolicyError.self) {
            try policy.authorize(script)
        }
    }

    @Test func testAutomationExecutorCancellationAndPartialFailures() async {
        let target1 = UUID()
        let target2 = UUID()
        let script = AutomationScript(
            name: "Partial failure test",
            source: "test",
            permissions: [.network],
            targetSessionIDs: [target1, target2]
        )
        let plan = AutomationPlan(
            script: script,
            steps: [
                AutomationStep(command: "step 1", delayAfterSend: 0.01),
                AutomationStep(command: "step 2", delayAfterSend: 0.01)
            ]
        )
        let executor = AutomationExecutor()
        let policy = AutomationPolicy(grantedPermissions: [.network])

        // Target 1 fails on step 2; Target 2 succeeds on both steps
        executor.run(plan: plan, policy: policy) { target, command in
            if target == target1 && command == "step 2" {
                return false
            }
            return true
        }

        for _ in 0..<30 where executor.isRunning {
            try? await Task.sleep(for: .milliseconds(20))
        }

        #expect(executor.results.count == 2)
        let res1 = executor.results.first(where: { $0.targetID == target1 })
        let res2 = executor.results.first(where: { $0.targetID == target2 })

        #expect(res1?.failed == true)
        #expect(res1?.sentSteps == 1)

        #expect(res2?.failed == false)
        #expect(res2?.sentSteps == 2)

        // Verify record in history
        #expect(!executor.executionHistory.isEmpty)
        #expect(executor.executionHistory.first?.planName == "Partial failure test")
        #expect(executor.executionHistory.first?.successfulTargets == 1)
        #expect(executor.executionHistory.first?.failedTargets == 1)
    }

    // MARK: - 11. Phase 3 Operational Workspace Verification Tests

    @Test func testWorkspaceModelAtomicPersistenceAndMigration() {
        let store = WorkspaceStore.shared
        let workspaceID = UUID()
        let session1 = UUID()
        let session2 = UUID()

        let splitTree = WorkspaceSplitNode(
            orientation: .horizontal,
            ratio: 0.5,
            children: [
                WorkspaceSplitNode(sessionID: session1),
                WorkspaceSplitNode(sessionID: session2)
            ]
        )

        let tab = WorkspaceTab(title: "Cluster Ops", rootSplit: splitTree)
        let event = WorkspaceTimelineEvent(type: .connection, host: "prod-db-01", message: "Connected successfully", exitCode: 0)
        let note = WorkspaceIncidentNote(content: "Investigating failover event", pendingCommands: ["sudo systemctl status postgresql"])

        let workspace = WorkspaceModel(
            id: workspaceID,
            name: "Production Failover Incident",
            tabs: [tab],
            timeline: [event],
            notes: [note]
        )

        // Save
        store.save(workspace)

        // Reload
        store.loadAll()
        let reloaded = store.workspaces.first(where: { $0.id == workspaceID })
        #expect(reloaded != nil)
        #expect(reloaded?.name == "Production Failover Incident")
        #expect(reloaded?.tabs.count == 1)
        #expect(reloaded?.tabs.first?.rootSplit.children.count == 2)
        #expect(reloaded?.timeline.count == 1)
        #expect(reloaded?.notes.count == 1)
        #expect(reloaded?.notes.first?.pendingCommands.contains("sudo systemctl status postgresql") == true)

        // Cleanup
        store.delete(id: workspaceID)
        #expect(!store.workspaces.contains(where: { $0.id == workspaceID }))
    }

    @Test func testMultiHostComparatorGroupingAndOutlierDetection() {
        let outputs = [
            HostExecutionOutput(host: "node-1", command: "df -h", exitCode: 0, durationSeconds: 0.1, output: "/dev/sda1 50G 20G 30G 40% /"),
            HostExecutionOutput(host: "node-2", command: "df -h", exitCode: 0, durationSeconds: 0.1, output: "/dev/sda1 50G 20G 30G 40% /"),
            HostExecutionOutput(host: "node-3", command: "df -h", exitCode: 1, durationSeconds: 0.1, output: "/dev/sda1 50G 49G 1G 98% / [DISK FULL]"),
            HostExecutionOutput(host: "node-4", command: "df -h", exitCode: 0, durationSeconds: 0.1, output: "/dev/sda1 50G 20G 30G 40% /")
        ]

        let clusters = MultiHostComparator.groupOutputs(outputs)
        #expect(clusters.count == 2)

        let normalCluster = clusters.first(where: { $0.hosts.count == 3 })
        let outlierCluster = clusters.first(where: { $0.isOutlier })

        #expect(normalCluster != nil)
        #expect(normalCluster?.hosts == ["node-1", "node-2", "node-4"])
        #expect(normalCluster?.exitCode == 0)

        #expect(outlierCluster != nil)
        #expect(outlierCluster?.hosts == ["node-3"])
        #expect(outlierCluster?.exitCode == 1)
        #expect(outlierCluster?.commonOutput.contains("[DISK FULL]") == true)
    }

    @Test func testIncidentBundleExporterSanitization() {
        let event = WorkspaceTimelineEvent(
            type: .command,
            host: "core-router-01",
            message: "Ran config: password=SuperSecretPassword99 token=ghp_secretTokenHere",
            exitCode: 0
        )
        let note = WorkspaceIncidentNote(
            content: "Credentials tested: password: SecretPassPhrase123",
            pendingCommands: ["curl -H 'Authorization: Bearer mySecretBearerToken' https://api.corp/v1"]
        )
        let workspace = WorkspaceModel(
            name: "Audit Workspace",
            timeline: [event],
            notes: [note]
        )

        let bundle = IncidentBundleExporter.exportSanitizedBundle(workspace: workspace)
        #expect(bundle.contains("# Spectre Pro Incident Bundle"))
        #expect(bundle.contains("Audit Workspace"))
        #expect(!bundle.contains("SuperSecretPassword99"))
        #expect(!bundle.contains("SecretPassPhrase123"))
        #expect(!bundle.contains("mySecretBearerToken"))
        #expect(bundle.contains("[REDACTED]"))
    }

    // MARK: - 12. Phase 4 Fleet, Scale & Hardware Integrations Tests

    @Test func testSessionInventoryExportAndImportRoundTrip() throws {
        let originalSession = SavedSession(
            name: "Edge Gateway 01",
            folder: "Gateways",
            host: "10.200.0.1",
            user: "netadmin",
            port: 2222,
            environmentBadge: "PROD",
            portForwards: [
                PortForwardRule(type: .local, localPort: 8443, remoteHost: "10.200.0.1", remotePort: 443)
            ]
        )

        let exportedJSON = try SessionInventoryManager.exportJSON(sessions: [originalSession])
        #expect(exportedJSON.contains("\"schemaVersion\" : \"1.0\""))
        #expect(exportedJSON.contains("Edge Gateway 01"))
        #expect(exportedJSON.contains("10.200.0.1"))
        // Credentials must not be present in export
        #expect(!exportedJSON.contains("credentialReference"))
        #expect(!exportedJSON.contains("password"))

        let importedSessions = try SessionInventoryManager.importJSON(exportedJSON)
        #expect(importedSessions.count == 1)
        let imported = importedSessions[0]
        #expect(imported.name == "Edge Gateway 01")
        #expect(imported.folder == "Gateways")
        #expect(imported.host == "10.200.0.1")
        #expect(imported.port == 2222)
        #expect(imported.portForwards.count == 1)
        #expect(imported.portForwards[0].localPort == 8443)
    }

    @Test func testAnsibleInventoryParser() {
        let sampleInventory = """
        # Production Inventory
        [webservers]
        web-01 ansible_host=192.168.1.101 ansible_user=ubuntu ansible_port=22
        web-02 ansible_host=192.168.1.102 ansible_user=ubuntu

        [databases]
        db-primary ansible_host=10.0.0.50 ansible_user=postgres ansible_port=54322
        """

        let sessions = SessionInventoryManager.parseAnsibleInventory(sampleInventory)
        #expect(sessions.count == 3)

        let web1 = sessions.first(where: { $0.name == "web-01" })
        #expect(web1 != nil)
        #expect(web1?.host == "192.168.1.101")
        #expect(web1?.user == "ubuntu")
        #expect(web1?.folder == "Webservers")

        let db = sessions.first(where: { $0.name == "db-primary" })
        #expect(db != nil)
        #expect(db?.host == "10.0.0.50")
        #expect(db?.user == "postgres")
        #expect(db?.port == 54322)
        #expect(db?.folder == "Databases")
    }

    @Test func testSerialHardwareManufacturerProfiles() {
        let cisco = SerialHardwareManufacturer.cisco.createConfig(devicePath: "/dev/cu.usbserial-CISCO")
        #expect(cisco.baudRate == 9600)
        #expect(cisco.lineDelayMs == 50)
        #expect(cisco.charDelayMs == 2)
        #expect(cisco.name == "Cisco IOS / Catalyst")

        let arista = SerialHardwareManufacturer.arista.createConfig(devicePath: "/dev/cu.usbserial-ARISTA")
        #expect(arista.baudRate == 115200)
        #expect(arista.lineDelayMs == 10)
    }

    @Test func testFleetHealthMetricsManager() async {
        let fleet = FleetManager.shared
        fleet.refreshFromLibrary()
        #expect(!fleet.isScanning)

        await fleet.pingAll()
        #expect(!fleet.isScanning)
        #expect(fleet.fleetNodes.allSatisfy { $0.isReachable })
    }
}
