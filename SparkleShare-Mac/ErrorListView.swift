//
//  ErrorListView.swift
//  SparkleShare-Mac
//
//  Created by Stefan Bethge on 28.01.26.
//

import SwiftUI

struct ErrorRowView: View {
    let error: SyncError
    @EnvironmentObject var errorStore: ErrorStore
    @State private var isExpanded: Bool = false

    private var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: error.timestamp)
    }

    private var operationIcon: String {
        switch error.operationType {
        case .add:
            return "plus.circle"
        case .commit:
            return "checkmark.circle"
        case .push:
            return "arrow.up.circle"
        case .pull:
            return "arrow.down.circle"
        case .clone:
            return "doc.on.doc"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: operationIcon)
                    .foregroundColor(.red)
                    .font(.title2)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(error.operationType.rawValue)
                            .font(.headline)
                        Spacer()
                        Text(formattedTimestamp)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text(error.repositoryPath)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    if isExpanded {
                        Text(error.errorMessage)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.primary)
                            .textSelection(.enabled)
                    } else {
                        Text(error.errorMessage)
                            .font(.body)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .truncationMode(.tail)
                    }
                }

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .onTapGesture {
                isExpanded.toggle()
            }
        }
        .contextMenu {
            Button("Copy Error") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(error.errorMessage, forType: .string)
            }
            Divider()
            Button("Ignore errors like this") {
                errorStore.ignoreError(error)
            }
        }
    }
}

struct ErrorListView: View {
    @EnvironmentObject var errorStore: ErrorStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Sync Errors")
                    .font(.headline)
                Spacer()
                if errorStore.hasIgnoredErrors {
                    Button("Reset Ignores") {
                        errorStore.resetIgnoredErrors()
                    }
                }
                Button("Clear All") {
                    errorStore.clearErrors()
                }
                .disabled(!errorStore.hasVisibleErrors)
            }
            .padding()

            Divider()

            // Content
            if errorStore.filteredErrors.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    Text("No errors")
                        .font(.title2)
                        .padding(.top, 8)
                    Text("All sync operations completed successfully")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(errorStore.filteredErrors.reversed()) { error in
                        ErrorRowView(error: error)
                    }
                    .onDelete(perform: deleteErrors)
                }
            }
        }
        .frame(minWidth: 450, minHeight: 300)
        .onDisappear {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    private func deleteErrors(at offsets: IndexSet) {
        // Since we reversed the array for display, we need to convert indices
        let reversedErrors = errorStore.filteredErrors.reversed()
        for index in offsets {
            let error = Array(reversedErrors)[index]
            errorStore.removeError(error)
        }
    }
}
