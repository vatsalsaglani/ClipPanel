import SwiftData

enum ClipboardSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [ClipboardRecord.self] }
}

enum ClipboardSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }
    static var models: [any PersistentModel.Type] { [ClipboardRecord.self, ClipMetadata.self, ClipTag.self, ClipCollection.self, ClipSmartFilter.self] }
}

enum ClipboardMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [ClipboardSchemaV1.self, ClipboardSchemaV2.self] }
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: ClipboardSchemaV1.self, toVersion: ClipboardSchemaV2.self)]
    }
}
