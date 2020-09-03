# genericSearchLib

## Usage
With any given model:
```swift
struct Item {
    var name: String
    var category: Category
    var price: Double
    var stores: [Store]
}

struct Store {
    var name: String
    var categories: [Category]
}

enum Category: String {
    case toys
    case clothes
    case electronics
    case housing
    case jewelry
}
```

Create a SearchResult and Implement SearchService:
```swift
class ItemSearchResult: SearchResult {
    override var categoryName: String {
        switch searchPath {
        case .path(currentLevel: \Item.name, nestedLevel: nil):
            return "Item"
        case .path(currentLevel: \Item.category.rawValue, nestedLevel: nil):
            return "Category"
        default:
            return ""
        }
    }
}

class ItemSearch: SearchService {
    private lazy var search: GenericSearch = {
        GenericSearch()
    }()

    func search<Content>(content: [Content],
                         with string: String,
                         completion: @escaping (_ results: [SearchResult]) -> Void) {

        search.search(content: content,
                      searchString: string,
                      searchPaths: [.path(currentLevel: \Item.name,
                                          nestedLevel: nil),
                                    .path(currentLevel: \Item.category.rawValue,
                                          nestedLevel: nil),
                                    .path(currentLevel: \Item.stores,
                                          nestedLevel: .path(currentLevel: \Store.name,
                                                             nestedLevel: nil))],
                            resultType: ItemSearchResult.self) { results in

                                completion(results)
        }
    }
}
```
