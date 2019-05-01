import BitcoinCore

class MasternodeListSyncer: IMasternodeListSyncer {
    private var successor: IPeerTaskHandler?

    private let bitcoinCore: BitcoinCore
    private let initialBlockDownload: IInitialBlockDownload
    private let peerTaskFactory: IPeerTaskFactory
    private let masternodeListManager: IMasternodeListManager

    private var workingPeer: IPeer? = nil
    private let queue: DispatchQueue

    init(bitcoinCore: BitcoinCore, initialBlockDownload: IInitialBlockDownload, peerTaskFactory: IPeerTaskFactory, masternodeListManager: IMasternodeListManager,
         queue: DispatchQueue = DispatchQueue(label: "MasternodeListSyncer", qos: .background)) {
        self.bitcoinCore = bitcoinCore
        self.initialBlockDownload = initialBlockDownload
        self.peerTaskFactory = peerTaskFactory
        self.masternodeListManager = masternodeListManager
        self.queue = queue
    }

    private func assignNextSyncPeer() {
        queue.async {
            guard self.workingPeer == nil,
                  let lastBlockInfo = self.bitcoinCore.lastBlockInfo,
                  let syncedPeer = self.initialBlockDownload.syncedPeers.first,
                  let blockHash = lastBlockInfo.headerHash.reversedData else {
                return
            }

            let baseBlockHash = self.masternodeListManager.baseBlockHash

            if (blockHash != baseBlockHash) {
                let task = self.peerTaskFactory.createRequestMasternodeListDiffTask(baseBlockHash: baseBlockHash, blockHash: blockHash)
                syncedPeer.add(task: task)

                self.workingPeer = syncedPeer
            }
        }
    }

}

extension MasternodeListSyncer: IPeerSyncListener {

    func onPeerSynced(peer: IPeer) {
        assignNextSyncPeer()
    }

}

extension MasternodeListSyncer: IPeerGroupListener {

    func onPeerDisconnect(peer: IPeer, error: Error?) {
        if peer.equalTo(workingPeer) {
            workingPeer = nil

            assignNextSyncPeer()
        }
    }

}

extension MasternodeListSyncer: IPeerTaskHandler {

    func handleCompletedTask(peer: IPeer, task: PeerTask) -> Bool {
        switch task {
        case let listDiffTask as RequestMasternodeListDiffTask:
            if let message = listDiffTask.masternodeListDiffMessage {
                do {
                    try masternodeListManager.updateList(masternodeListDiffMessage: message)
                    workingPeer = nil
                } catch {
                    peer.disconnect(error: error)
                }
            }
            return true
        default: return false
        }
    }

}
