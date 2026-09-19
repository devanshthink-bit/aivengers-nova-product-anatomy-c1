//
//  DailySessionTests.swift
//  NOVATests
//

import Testing
@testable import NOVA

@Suite("Daily session")
struct DailySessionTests {

    @Test("The quiz is gated behind reading every story")
    func readingGatesTheQuiz() {
        let session = DailySession()

        #expect(session.hasReadAllStories == false)

        for story in session.stories.dropLast() {
            session.markRead(story)
        }
        #expect(session.hasReadAllStories == false)
        #expect(session.firstUnreadStoryIndex == session.stories.count - 1)

        session.markRead(session.stories.last!)
        #expect(session.hasReadAllStories == true)
        #expect(session.storiesReadCount == session.stories.count)
    }

    @Test("Marking the same story twice does not double count it")
    func readingIsIdempotent() {
        let session = DailySession()
        let story = session.stories[0]

        session.markRead(story)
        session.markRead(story)

        #expect(session.storiesReadCount == 1)
    }

    @Test("The round is built from today's stories and questions")
    func roundMatchesTodaysContent() {
        let session = DailySession()

        #expect(session.engine.questionCount == session.questions.count)
        #expect(session.engine.round.storyIDs == session.stories.map(\.id))
    }
}

@Suite("Mock content")
struct MockContentTests {

    @Test("Today ships five stories and five questions")
    func todayHasFiveOfEach() {
        #expect(MockNewsService.todayStories.count == 5)
        #expect(MockNewsService.todayQuestions.count == 5)
    }

    @Test("Every question has four answers and a valid correct answer")
    func questionsAreWellFormed() {
        for question in MockNewsService.todayQuestions {
            #expect(question.answers.count == 4)
            #expect(question.answers.indices.contains(question.correctAnswerIndex))
            #expect(question.correctAnswer.isEmpty == false)
            #expect(Set(question.answers).count == question.answers.count)
        }
    }

    @Test("Every question belongs to one of today's stories")
    func questionsPointAtRealStories() {
        let storyIDs = Set(MockNewsService.todayStories.map(\.id))

        for question in MockNewsService.todayQuestions {
            #expect(storyIDs.contains(question.storyID))
        }
    }

    @Test("Identifiers are unique")
    func identifiersAreUnique() {
        #expect(Set(MockNewsService.todayStories.map(\.id)).count == 5)
        #expect(Set(MockNewsService.todayQuestions.map(\.id)).count == 5)
    }
}
