import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        entity: Expense.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Expense.date, ascending: false)]
    ) private var expenses: FetchedResults<Expense>

    @State private var showAddExpense = false

    var body: some View {
        NavigationView {
            VStack {
                List {
                    ForEach(expenses) { expense in
                        VStack(alignment: .leading) {
                            Text(expense.name ?? "Unknown Expense")
                                .font(.headline)
                            Text("$\(expense.amount, specifier: "%.2f")")
                                .font(.subheadline)
                            Text(expense.category ?? "Other")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .onDelete(perform: deleteExpense)
                }

                Button(action: {
                    showAddExpense = true
                }) {
                    Text("Add Expense")
                        .font(.title2)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.horizontal)
                }
                .sheet(isPresented: $showAddExpense) {
                    AddExpenseView()
                        .environment(\.managedObjectContext, viewContext)
                }
            }
            .navigationTitle("Expense Tracker")
        }
    }

    private func deleteExpense(at offsets: IndexSet) {
        for index in offsets {
            viewContext.delete(expenses[index])
        }
        saveContext()
    }

    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            print("Error saving: \(error.localizedDescription)")
        }
    }
}

