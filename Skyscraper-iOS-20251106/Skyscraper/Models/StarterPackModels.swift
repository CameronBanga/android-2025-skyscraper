//
//  StarterPackModels.swift
//  Skyscraper
//
//  Models for BlueSky Starter Packs
//

import Foundation

struct StarterPack: Codable, Identifiable {
    let uri: String
    let cid: String
    let record: StarterPackRecord
    let creator: Author
    let listItemCount: Int?
    let joinedWeekCount: Int?
    let joinedAllTimeCount: Int?
    let labels: [Label]?
    let indexedAt: String?

    var id: String { uri }
}

struct StarterPackRecord: Codable {
    let name: String
    let description: String?
    let descriptionFacets: [Facet]?
    let list: String
    let feeds: [FeedItem]?
    let createdAt: String
}

struct FeedItem: Codable, Identifiable {
    let uri: String

    var id: String { uri }
}

struct StarterPacksResponse: Codable {
    let starterPacks: [StarterPack]
    let cursor: String?
}
