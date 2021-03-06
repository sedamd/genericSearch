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

open class SearchResult {
    public var searchText: String
    public var matchingText: String
    public var searchPath: SearchPath
    
    open var categoryName: String {
        return ""
    }
    
    public required init(searchText: String,
         matchingText: String,
         searchPath: SearchPath) {
        
        self.searchText = searchText
        self.matchingText = matchingText
        self.searchPath = searchPath
    }
}

extension SearchResult: Hashable {
    public func hash(into hasher: inout Hasher) { return hasher.combine(ObjectIdentifier(self)) }

    public static func == (lhs: SearchResult, rhs: SearchResult) -> Bool {
        return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }
}

public protocol SearchDefinition {
    
    func search<Content>(content: [Content],
                         searchString: String,
                         searchPaths: [SearchPath],
                         resultType: SearchResult.Type,
                         completion: @escaping (_ results: [SearchResult]) -> Void)
}

public struct GenericSearch: SearchDefinition {
    
    public init() { }
    
    public func search<Content>(content: [Content],
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
                            resultType: resultType,
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
    
    private func search<Content>(itemToSearch: Content,
                                 searchString: String,
                                 originalSearchPath: SearchPath,
                                 searchPath: SearchPath,
                                 resultType: SearchResult.Type,
                                 results: inout Set<SearchResult>) {
        
        let searchStringLowercased = searchString.lowercased()
        
        guard let nestedLevel = searchPath.nestedLevel else {
            if let itemToSearch = itemToSearch[keyPath: searchPath.currentLevel] as? String,
                itemToSearch.lowercased().contains(searchStringLowercased) {
                let result = resultType.init(searchText: searchString,
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
                          resultType: resultType,
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
