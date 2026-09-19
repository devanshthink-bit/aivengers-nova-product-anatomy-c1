//
//  OnboardingTests.swift
//  NOVATests
//

import Testing
@testable import NOVA

@Suite("Topic selection")
struct TopicSelectionTests {

    @Test("An empty selection needs two more before the flow moves on")
    func emptySelection() {
        let selection = TopicSelection()
        #expect(selection.count == 0)
        #expect(selection.isComplete == false)
        #expect(selection.remaining == TopicSelection.minimum)
    }

    @Test("Toggling adds then removes the same category")
    func togglingIsReversible() {
        var selection = TopicSelection()
        selection.toggle(.technology)
        #expect(selection.contains(.technology))
        #expect(selection.count == 1)

        selection.toggle(.technology)
        #expect(selection.contains(.technology) == false)
        #expect(selection.count == 0)
    }

    @Test("The minimum is reached at two, and never goes negative past it")
    func minimumIsTwo() {
        var selection = TopicSelection()
        selection.toggle(.india)
        #expect(selection.isComplete == false)
        #expect(selection.remaining == 1)

        selection.toggle(.science)
        #expect(selection.isComplete)
        #expect(selection.remaining == 0)

        selection.toggle(.world)
        #expect(selection.isComplete)
        #expect(selection.remaining == 0)
    }

    @Test("A selection survives a round trip through its stored string")
    func encodingRoundTrips() {
        let original = TopicSelection(categories: [.business, .india, .science])
        let restored = TopicSelection(rawValue: original.rawValue)
        #expect(restored == original)
    }

    @Test("The stored string is stable regardless of insertion order")
    func encodingIsStable() {
        var first = TopicSelection()
        first.toggle(.world)
        first.toggle(.india)

        var second = TopicSelection()
        second.toggle(.india)
        second.toggle(.world)

        #expect(first.rawValue == second.rawValue)
    }

    @Test("Unknown stored categories are dropped rather than crashing")
    func decodingIgnoresUnknownCategories() {
        let selection = TopicSelection(rawValue: "technology,sportsball,,science")
        #expect(selection.categories == [.technology, .science])
    }

    @Test("An empty stored string decodes to an empty selection")
    func decodingEmptyString() {
        #expect(TopicSelection(rawValue: "") == TopicSelection())
    }
}

@Suite("Story ordering")
struct StoryOrderingTests {

    private static let stories = MockNewsService.todayStories

    @Test("Chosen categories move to the front and the rest keep their order")
    func chosenComeFirst() {
        let selection = TopicSelection(categories: [.science])
        let ordered = Self.stories.leading(with: selection)

        #expect(ordered.first?.category == .science)
        #expect(ordered.count == Self.stories.count)

        // Everything not chosen is still in its original relative order.
        let restBefore = Self.stories.filter { $0.category != .science }.map(\.id)
        let restAfter = ordered.filter { $0.category != .science }.map(\.id)
        #expect(restBefore == restAfter)
    }

    @Test("Nothing is dropped, whatever the selection")
    func nothingIsLost() {
        for selection in [
            TopicSelection(),
            TopicSelection(categories: [.india]),
            TopicSelection(categories: [.india, .technology, .business, .world, .science]),
        ] {
            let ordered = Self.stories.leading(with: selection)
            #expect(Set(ordered.map(\.id)) == Set(Self.stories.map(\.id)))
            #expect(ordered.count == Self.stories.count)
        }
    }

    @Test("An empty selection leaves the deck untouched")
    func emptySelectionKeepsOrder() {
        let ordered = Self.stories.leading(with: TopicSelection())
        #expect(ordered.map(\.id) == Self.stories.map(\.id))
    }

    @Test("Choosing every category leaves the deck untouched")
    func fullSelectionKeepsOrder() {
        let all = TopicSelection(categories: Set(StoryCategory.allCases))
        let ordered = Self.stories.leading(with: all)
        #expect(ordered.map(\.id) == Self.stories.map(\.id))
    }
}

@Suite("Onboarding pages")
struct OnboardingPageTests {

    @Test("The pages run in order and the last one has no next")
    func pagesRunInOrder() {
        #expect(OnboardingPage.allCases.first == .manifesto)
        #expect(OnboardingPage.allCases.last == .ready)
        #expect(OnboardingPage.ready.next == nil)
        #expect(OnboardingPage.ready.isLast)
        #expect(OnboardingPage.manifesto.next == .ritual)
        #expect(OnboardingPage.manifesto.isLast == false)
    }

    @Test("Walking next from the first page reaches the last one exactly once")
    func walkingReachesTheEnd() {
        var page = OnboardingPage.manifesto
        var visited = [page]
        while let next = page.next {
            page = next
            visited.append(page)
        }
        #expect(visited == OnboardingPage.allCases)
        #expect(visited.count == OnboardingPage.count)
    }

    @Test("Numbering is 1-based for the progress dots")
    func numbering() {
        #expect(OnboardingPage.manifesto.number == 1)
        #expect(OnboardingPage.ready.number == OnboardingPage.count)
    }
}
