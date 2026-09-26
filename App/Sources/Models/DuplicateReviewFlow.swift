import Photos
import SwiftUI

enum DuplicateReviewStage: Equatable {
    case accessDenied
    case scanning(done: Int, total: Int)
    case noDuplicates
    case reviewing
    case deleting
    case done(deletedCount: Int, groupsReviewed: Int)
}

@MainActor
@Observable
final class DuplicateReviewFlow {
    var stage: DuplicateReviewStage = .scanning(done: 0, total: 0)
    private(set) var groups: [DuplicateGroup] = []
    private(set) var currentIndex = 0

    /// Which of the current group's assets are marked "keep" — everything else in the group is
    /// implicitly "delete". Reseeded each time a new group is shown.
    private(set) var keepMarks: Set<String> = []

    private var deletedTotal = 0
    private var groupsReviewed = 0

    var currentGroup: DuplicateGroup? {
        currentIndex < groups.count ? groups[currentIndex] : nil
    }

    func start(forceRescan: Bool = false) async {
        if forceRescan { DuplicateDecisionStore.reset() }
        guard await PhotoLibraryService.requestAuthorization() else {
            stage = .accessDenied
            return
        }
        stage = .scanning(done: 0, total: 0)
        let candidates = PhotoLibraryService.fetchAllImageAssets()
            .filter { !DuplicateDecisionStore.isHandled($0.localIdentifier) }

        let found = await DuplicateDetector.scan(assets: candidates) { done, total in
            Task { @MainActor in self.stage = .scanning(done: done, total: total) }
        }

        groups = found
        currentIndex = 0
        deletedTotal = 0
        groupsReviewed = 0
        if groups.isEmpty {
            stage = .noDuplicates
        } else {
            seedKeepMarks()
            stage = .reviewing
        }
    }

    private func seedKeepMarks() {
        guard let group = currentGroup, let keeper = DuplicateDetector.defaultKeeper(in: group.assets) else {
            keepMarks = []
            return
        }
        keepMarks = [keeper.localIdentifier]
    }

    func isKept(_ asset: PHAsset) -> Bool { keepMarks.contains(asset.localIdentifier) }

    func toggle(_ asset: PHAsset) {
        if keepMarks.contains(asset.localIdentifier) {
            keepMarks.remove(asset.localIdentifier)
        } else {
            keepMarks.insert(asset.localIdentifier)
        }
    }

    var keepCount: Int { keepMarks.count }
    var deleteCount: Int { (currentGroup?.assets.count ?? 0) - keepCount }

    func confirmCurrentGroup() {
        guard let group = currentGroup else { return }
        Task {
            stage = .deleting
            let toDelete = group.assets.filter { !isKept($0) }
            let success = await PhotoLibraryService.delete(toDelete)
            if success {
                StatsStore.recordDeletion(of: toDelete)
                deletedTotal += toDelete.count
            }
            DuplicateDecisionStore.markHandled(group.assets.map(\.localIdentifier))
            groupsReviewed += 1
            advance()
        }
    }

    private func advance() {
        currentIndex += 1
        if currentIndex >= groups.count {
            stage = .done(deletedCount: deletedTotal, groupsReviewed: groupsReviewed)
        } else {
            seedKeepMarks()
            stage = .reviewing
        }
    }

    func rescan() {
        Task { await start(forceRescan: true) }
    }
}
