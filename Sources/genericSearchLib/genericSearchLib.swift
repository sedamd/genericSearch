import Foundation

public indirect enum SearchPath {
    case path(currentLevel: AnyKeyPath, nestedLevel: SearchPath?)
    
    var currentLevel: AnyKeyPath {
        switch self {
        case .path(let currentLevel, _):
            return currentLevel
        }
    }
    
    var nestedLevel: SearchPath? {
        switch self {
        case .path(_, let nestedLevel):
            return nestedLevel
        }
    }
}

extension SearchPath: Hashable {
    public static func == (lhs: SearchPath, rhs: SearchPath) -> Bool {
        return lhs.currentLevel == rhs.currentLevel
            && lhs.nestedLevel == rhs.nestedLevel
    }
}

public protocol SearchResult {
    var searchText: String { get set }
    var matchingText: String { get set }
    var searchPath: SearchPath { get set }
    
    var categoryName: String { get }
    
    init(searchText: String,
         matchingText: String,
         searchPath: SearchPath)
}

public protocol UniqueSearchResult: Hashable, SearchResult { }

public protocol SearchDefinition {
    
    func search<Content, SearchResult: UniqueSearchResult>(content: [Content],
                                                           searchString: String,
                                                           searchPaths: [SearchPath],
                                                           resultType: SearchResult.Type,
                                                           completion: @escaping (_ results: [SearchResult]) -> Void)
}

public struct GenericSearch: SearchDefinition {
    
    public func search<Content, SearchResult: UniqueSearchResult>(content: [Content],
                                                                  searchString: String,
                                                                  searchPaths: [SearchPath],
                                                                  resultType: SearchResult.Type,
                                                                  completion: @escaping ([SearchResult]) -> Void) {
        if searchString == "" {
            completion([])
            return
        }

        let searchStringLowercased = searchString.lowercased()
        
        var results: Set<SearchResult> = Set<SearchResult>()

        content.forEach { itemToSearch in
            searchPaths.forEach { prop in
                
                self.search(itemToSearch: itemToSearch,
                            searchString: searchString,
                            originalSearchPath: prop,
                            searchPath: prop,
                            results: &results)
            }
        }
        
        var resultsArray = Array(results)

        resultsArray.sort {
            guard let first = $0.matchingText.lowercased().range(of: searchStringLowercased)?.lowerBound,
                let second = $1.matchingText.lowercased().range(of: searchStringLowercased)?.lowerBound else {
                    return true
            }
            return first < second
        }
        completion(resultsArray)
    }
    
    private func search<Content, SearchResult: UniqueSearchResult>(itemToSearch: Content,
                                                                   searchString: String,
                                                                   originalSearchPath: SearchPath,
                                                                   searchPath: SearchPath,
                                                                   results: inout Set<SearchResult>) {
        
        let searchStringLowercased = searchString.lowercased()
        
        guard let nestedLevel = searchPath.nestedLevel else {
            if let itemToSearch = itemToSearch[keyPath: searchPath.currentLevel] as? String,
                itemToSearch.lowercased().contains(searchStringLowercased) {
                let result = SearchResult.init(searchText: searchString,
                                               matchingText: itemToSearch,
                                               searchPath: originalSearchPath)
                results.insert(result)
            }
            return
        }
        
        guard let nextItems = itemToSearch[keyPath: searchPath.currentLevel] as? [Any] else { return }
            
        nextItems.forEach { nextItemToSearch in
            return search(itemToSearch: nextItemToSearch,
                          searchString: searchString,
                          originalSearchPath: originalSearchPath,
                          searchPath: nestedLevel,
                          results: &results)
        }
    }

}

public protocol FilterService: class {
    func apply<Content>(filter: SearchResult, to content: [Content]) -> [Content]
}

public class TextFilter: FilterService {
    
    public typealias SearchFilter = SearchResult
    
    public func apply<Content>(filter: SearchFilter, to content: [Content]) -> [Content] {
        
        let filteredContent = content.filter { item in
            return applyFilter(path: filter.searchPath,
                               value: filter.matchingText.lowercased(),
                               itemToSearch: item)
        }
        
        return filteredContent
    }
    
    private func applyFilter<Content>(path: SearchPath,
                                      value: String,
                                      itemToSearch: Content) -> Bool {
                
        guard let nestedLevel = path.nestedLevel else {
            if let itemToSearch = itemToSearch[keyPath: path.currentLevel] as? String,
                itemToSearch.lowercased() == value {
                return true
            }
            return false
        }
        
        guard let nextItems = itemToSearch[keyPath: path.currentLevel] as? [Any] else { return false }
            
        return nextItems.contains { nextItemToSearch -> Bool in
            return applyFilter(path: nestedLevel,
                               value: value,
                               itemToSearch: nextItemToSearch)
        }
    }
}

public protocol SearchService: class {
    func search<Content>(content: [Content],
                         with string: String,
                         completion: @escaping (_ results: [SearchResult]) -> Void)
}
