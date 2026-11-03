//
//  FilterPanelView.swift
//  DocGuardian
//
//  Advanced filter panel — replaces the simple category picker
//  with a multi-criteria filter including tags, amount range,
//  due status, and sort order.
//

import SwiftUI

struct FilterPanelView: View {

    @EnvironmentObject var listVM: DocumentListViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Category") {
                    categoryRow(nil, label: "All")
                    ForEach(DocumentType.allCases) { t in
                        categoryRow(t, label: t.displayName)
                    }
                }

                Section("Tags") {
                    if listVM.allTagNames.isEmpty {
                        Text("No tags yet — add them to documents in the detail view.")
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    } else {
                        tagRow(nil, label: "All tags")
                        ForEach(listVM.allTagNames, id: \.self) { tag in
                            tagRow(tag, label: tag)
                        }
                    }
                }

                Section("Status") {
                    Toggle("Only unresolved", isOn: $listVM.onlyUnresolved)
                    Toggle("Due in 7 days", isOn: $listVM.onlyDueSoon)
                    Toggle("Overdue", isOn: $listVM.onlyOverdue)
                }

                Section("Amount Range") {
                    HStack {
                        Text("Min $")
                        TextField("0", value: $amountMinText, format: .number)
                            .keyboardType(.decimalPad)
                            .frame(maxWidth: 80)
                        Text("Max $")
                        TextField("Any", value: $amountMaxText, format: .number)
                            .keyboardType(.decimalPad)
                            .frame(maxWidth: 80)
                    }
                    .onChange(of: amountMinText) { _, new in listVM.amountMin = new }
                    .onChange(of: amountMaxText) { _, new in listVM.amountMax = new }

                    Button("Clear amount range") {
                        amountMinText = nil
                        amountMaxText = nil
                        listVM.amountMin = nil
                        listVM.amountMax = nil
                    }
                    .disabled(listVM.amountMin == nil && listVM.amountMax == nil)
                }

                Section("Sort By") {
                    Picker("Order", selection: $listVM.sortOrder) {
                        Text("Due date (soonest first)").tag(DocumentListViewModel.SortOrder.dueDateAsc)
                        Text("Due date (latest first)").tag(DocumentListViewModel.SortOrder.dueDateDesc)
                        Text("Most recently added").tag(DocumentListViewModel.SortOrder.createdAtDesc)
                        Text("Largest amount").tag(DocumentListViewModel.SortOrder.amountDesc)
                        Text("Title A–Z").tag(DocumentListViewModel.SortOrder.titleAsc)
                    }
                    .pickerStyle(.menu)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") { resetAll() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @State private var amountMinText: Decimal? = nil
    @State private var amountMaxText: Decimal? = nil

    private func categoryRow(_ type: DocumentType?, label: String) -> some View {
        Button {
            listVM.selectedCategory = type
        } label: {
            HStack {
                Text(label)
                Spacer()
                if listVM.selectedCategory == type {
                    Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func tagRow(_ tag: String?, label: String) -> some View {
        Button {
            listVM.selectedTag = tag
        } label: {
            HStack {
                Text(label)
                Spacer()
                if listVM.selectedTag == tag {
                    Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func resetAll() {
        listVM.selectedCategory = nil
        listVM.selectedTag = nil
        listVM.onlyUnresolved = false
        listVM.onlyDueSoon = false
        listVM.onlyOverdue = false
        listVM.amountMin = nil
        listVM.amountMax = nil
        listVM.sortOrder = .dueDateAsc
        amountMinText = nil
        amountMaxText = nil
    }
}
