#if canImport(MultipeerConnectivity)
import Foundation
import MultipeerConnectivity

/// Wraps a non-Sendable framework object so it can hop to the main actor.
private struct UncheckedBox<Value>: @unchecked Sendable {
    let value: Value
}

/// DUT-1001 — MultipeerConnectivity transport for the Fire Circle (spike).
/// Real radio behaviour cannot be unit-tested; see the lifecycle-only tests.
@MainActor
public final class MultipeerFireCircleTransport: NSObject, FireCircleTransport {
    public static let serviceType = "dod-firecircle"

    public private(set) var isRunning = false
    public var connectedPeerCount: Int { session?.connectedPeers.count ?? 0 }

    private var localPeer: MCPeerID?
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var onEvent: (@MainActor (FireCircleEvent) -> Void)?

    public override init() {
        super.init()
    }

    public func start(
        localPeerID: String,
        displayName: String,
        onEvent: @escaping @MainActor (FireCircleEvent) -> Void
    ) {
        stop()
        self.onEvent = onEvent
        let peer = MCPeerID(displayName: displayName)
        let session = MCSession(peer: peer, securityIdentity: nil, encryptionPreference: .required)
        let advertiser = MCNearbyServiceAdvertiser(
            peer: peer,
            discoveryInfo: nil,
            serviceType: Self.serviceType
        )
        let browser = MCNearbyServiceBrowser(peer: peer, serviceType: Self.serviceType)
        localPeer = peer
        self.session = session
        self.advertiser = advertiser
        self.browser = browser
        session.delegate = self
        advertiser.delegate = self
        browser.delegate = self
        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()
        isRunning = true
    }

    public func stop() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session?.disconnect()
        advertiser = nil
        browser = nil
        session = nil
        localPeer = nil
        onEvent = nil
        isRunning = false
    }

    public func broadcast(_ cook: FireCircleCook) {
        guard let session, !session.connectedPeers.isEmpty else { return }
        guard let data = try? cook.encoded() else { return }
        try? session.send(data, toPeers: session.connectedPeers, with: .unreliable)
    }

    fileprivate func acceptInvitation(_ handler: UncheckedBox<(Bool, MCSession?) -> Void>) {
        handler.value(true, session)
    }

    fileprivate func invite(_ peer: UncheckedBox<MCPeerID>) {
        guard let browser, let session, let localPeer else { return }
        guard localPeer.displayName < peer.value.displayName else { return }
        browser.invitePeer(peer.value, to: session, withContext: nil, timeout: 30)
    }

    fileprivate func handleReceived(_ data: Data) {
        guard let cook = try? FireCircleCook.decode(data) else { return }
        onEvent?(.received(cook))
    }

    fileprivate func handlePeerLeft(_ name: String) {
        onEvent?(.peerLeft(peerID: name))
    }
}

extension MultipeerFireCircleTransport: MCNearbyServiceAdvertiserDelegate {
    nonisolated public func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        let box = UncheckedBox(value: invitationHandler)
        Task { @MainActor in self.acceptInvitation(box) }
    }
}

extension MultipeerFireCircleTransport: MCNearbyServiceBrowserDelegate {
    nonisolated public func browser(
        _ browser: MCNearbyServiceBrowser,
        foundPeer peerID: MCPeerID,
        withDiscoveryInfo info: [String: String]?
    ) {
        let box = UncheckedBox(value: peerID)
        Task { @MainActor in self.invite(box) }
    }

    nonisolated public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
}

extension MultipeerFireCircleTransport: MCSessionDelegate {
    nonisolated public func session(
        _ session: MCSession,
        peer peerID: MCPeerID,
        didChange state: MCSessionState
    ) {
        guard state == .notConnected else { return }
        let name = peerID.displayName
        Task { @MainActor in self.handlePeerLeft(name) }
    }

    nonisolated public func session(
        _ session: MCSession,
        didReceive data: Data,
        fromPeer peerID: MCPeerID
    ) {
        Task { @MainActor in self.handleReceived(data) }
    }

    nonisolated public func session(
        _ session: MCSession,
        didReceive stream: InputStream,
        withName streamName: String,
        fromPeer peerID: MCPeerID
    ) {}

    nonisolated public func session(
        _ session: MCSession,
        didStartReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        with progress: Progress
    ) {}

    nonisolated public func session(
        _ session: MCSession,
        didFinishReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        at localURL: URL?,
        withError error: Error?
    ) {}
}
#endif
