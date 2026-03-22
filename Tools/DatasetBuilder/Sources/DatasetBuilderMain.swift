import Foundation

@main
struct DatasetBuilderMain {
    static func main() throws {
        let configuration = try BuilderConfiguration.parse(arguments: Array(CommandLine.arguments.dropFirst()))
        let builder = DatasetBuilder(configuration: configuration)
        try builder.run()
    }
}
