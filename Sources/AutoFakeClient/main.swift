import AutoFake
import Foundation

@AutoFake
struct Emoji: RawRepresentable, Codable {
     static let thumbsUp = Emoji(rawValue: "👍")
    let rawValue: String
}

@AutoFake
struct Image {
    let id: String
}

@AutoFake
struct User {
    let name: String
    let age: Int
    let image: Image
    let href: URL
    let createdAt: Date
}

@AutoFake
enum Order {
    case first, second
}

@AutoFake
enum Order2 {
    case second
    case first
}

@AutoFake
struct SetStruct {
    @AutoFakeDefault(Set<Int>())
    let set: Set<Int>
}

struct TrickyUser: Decodable {
    let name: String
    let age: Int?

    enum CodingKeys: CodingKey {
        case name, age
    }

    init(
        from
        decoder
        : Decoder
    ) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.age = try container.decodeIfPresent(Int.self, forKey: .age)
    }

    // order of arguments are flipped for some reasons
    init(age: Int?, name: String) {
        self.age = age
        self.name = name
    }
}

let user = User.fake()
print(user)

print(Order.fake())
print(Order2.fake())
