//
//  MockNewsService.swift
//  NOVA
//

import Foundation

/// Local stand-in for whatever supplies stories later.
///
/// IMPORTANT: every story below is invented demo content written for this prototype.
/// It does not report real events, and the sources are fictional NOVA desks on purpose
/// so no made-up claim is ever attributed to a real publication. This must be replaced
/// before the app shows anything to real readers.
enum MockNewsService {
    static let isDemoContent = true

    static let todayStories: [Story] = [
        Story(
            id: StoryID("story-1"),
            title: "Bengaluru opens a 14-station metro line across the city's east",
            summary: """
            The city's newest metro line started carrying passengers this week, adding \
            14 stations between Whitefield and the central business district. Transport \
            officials expect it to move about 180,000 riders a day once feeder buses are \
            running, turning a 90-minute road commute into one of roughly 35 minutes.

            Fares on the line start at ₹10 and trains run every four minutes during peak \
            hours. Two interchange stations remain under construction and are scheduled \
            to open next year.
            """,
            source: "NOVA India Desk",
            category: .india,
            publishedAt: Date.now.addingTimeInterval(-2 * 3600),
            artwork: .asset("story-metro")
        ),
        Story(
            id: StoryID("story-2"),
            title: "Chip designers push assistants back onto the phone itself",
            summary: """
            Three of the largest mobile chip designers used this week's developer events \
            to show processors that run an assistant entirely on the handset, with no \
            request leaving the device. Their pitch is privacy and speed: answers arrive \
            in under 200 milliseconds because there is no network round trip.

            Analysts covering the segment expect on-device models to handle most everyday \
            requests within two years, while longer reasoning tasks stay in data centres. \
            Handset makers are less certain, and say memory cost is the open question.
            """,
            source: "NOVA Tech Desk",
            category: .technology,
            publishedAt: Date.now.addingTimeInterval(-4 * 3600),
            artwork: .asset("story-chips")
        ),
        Story(
            id: StoryID("story-3"),
            title: "Small investors now hold a fifth of all mutual fund assets",
            summary: """
            Retail investors crossed a milestone this quarter, holding 20% of total mutual \
            fund assets for the first time, up from 12% five years ago. Monthly systematic \
            investment plans drove almost all of the growth, with the average contribution \
            sitting at ₹2,400.

            Fund houses are cautious about the shift. Most of these investors started \
            after the last downturn, so how they behave in a long falling market is still \
            untested.
            """,
            source: "NOVA Business Desk",
            category: .business,
            publishedAt: Date.now.addingTimeInterval(-6 * 3600),
            artwork: .asset("story-funds")
        ),
        Story(
            id: StoryID("story-4"),
            title: "Shipping lines reroute around a drought-hit canal for a third season",
            summary: """
            Low water levels have cut daily transits through a major inter-ocean canal from \
            36 vessels to 24, pushing carriers onto a detour that adds roughly 8,000 \
            kilometres and ten days to each Asia-to-Europe sailing.

            Freight rates on the affected lanes are up 18% from a year ago. The canal \
            authority is auctioning a small number of priority slots, and the highest of \
            them has sold for close to four million dollars.
            """,
            source: "NOVA World Desk",
            category: .world,
            publishedAt: Date.now.addingTimeInterval(-9 * 3600),
            artwork: .asset("story-canal")
        ),
        Story(
            id: StoryID("story-5"),
            title: "Sea-floor sensors catch an earthquake's opening seconds",
            summary: """
            A network of 62 sea-floor sensors recorded the first seconds of an offshore \
            earthquake, giving coastal towns 40 seconds of warning before strong shaking \
            arrived. The array measures pressure changes in the water column rather than \
            ground motion, which is why it registered the event ahead of land stations.

            The team behind it plans to publish the raw recordings for independent review, \
            and wants a second array installed along a neighbouring trench.
            """,
            source: "NOVA Science Desk",
            category: .science,
            publishedAt: Date.now.addingTimeInterval(-12 * 3600),
            artwork: .asset("story-seafloor")
        )
    ]

    /// One question per story, each answerable from the summary above.
    static let todayQuestions: [Question] = [
        Question(
            id: QuestionID("question-1"),
            storyID: StoryID("story-1"),
            prompt: "How many stations did Bengaluru's new metro line add?",
            answers: ["9", "14", "22", "31"],
            correctAnswerIndex: 1
        ),
        Question(
            id: QuestionID("question-2"),
            storyID: StoryID("story-2"),
            prompt: "How fast do the new on-device assistants answer?",
            answers: [
                "Under 200 milliseconds",
                "Under 2 seconds",
                "Under 5 seconds",
                "Under 30 milliseconds"
            ],
            correctAnswerIndex: 0
        ),
        Question(
            id: QuestionID("question-3"),
            storyID: StoryID("story-3"),
            prompt: "What share of mutual fund assets do retail investors now hold?",
            answers: ["8%", "12%", "20%", "34%"],
            correctAnswerIndex: 2
        ),
        Question(
            id: QuestionID("question-4"),
            storyID: StoryID("story-4"),
            prompt: "How much time does the canal detour add to each sailing?",
            answers: ["Three days", "Ten days", "Eighteen days", "A month"],
            correctAnswerIndex: 1
        ),
        Question(
            id: QuestionID("question-5"),
            storyID: StoryID("story-5"),
            prompt: "How much warning did the sea-floor sensors give?",
            answers: ["4 seconds", "40 seconds", "4 minutes", "14 minutes"],
            correctAnswerIndex: 1
        )
    ]
}
