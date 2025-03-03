import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        entity: Expense.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Expense.date, ascending: false)]
    ) private var expenses: FetchedResults<Expense>

    @State private var showAddExpense = false
    @State private var totalSpent: Double = 0.0
    @State private var refreshTrigger = false
    @State private var selectedCategory: String = "All"

    let categories = ["All", "Food", "Transport", "Entertainment", "Other"]

    var filteredExpenses: [Expense] {
        if selectedCategory == "All" {
            return Array(expenses)
        } else {
            return expenses.filter { $0.category == selectedCategory }
        }
    }

    var body: some View {
        ZStack {
            // Gradient Background
            LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)

            NavigationView {
                VStack {
                    // Total Spent Section
                    VStack {
                        Text("Total Spent")
                            .font(.headline)
                            .foregroundColor(.gray)

                        Text("$\(totalSpent, specifier: "%.2f")")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 15).fill(Color.white.opacity(0.2)))
                    .shadow(radius: 5)
                    .padding(.horizontal)

                    // ✅ Category Filter
                    Picker("Filter by Category", selection: $selectedCategory) {
                        ForEach(categories, id: \.self) { category in
                            Text(category)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)

                    // Expense List
                    List {
                        ForEach(filteredExpenses) { expense in
                            ZStack {
                                RoundedRectangle(cornerRadius: 15)
                                    .fill(Color.black.opacity(0.3))
                                    .shadow(radius: 5)

                                VStack(alignment: .leading, spacing: 5) {
                                    Text(expense.name ?? "Unknown Expense")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                    
                                    Text("$\(expense.amount, specifier: "%.2f")")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.green)
                                    
                                    Text(expense.category ?? "Other")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.blue)
                                }
                                .padding()
                            }
                            .padding(.vertical, 5)
                        }
                        .onDelete(perform: deleteExpense)
                    }
                    .listStyle(PlainListStyle())

                    // Add Expense Button
                    Button(action: {
                        showAddExpense = true
                    }) {
                        Text("Add Expense")
                            .font(.title2)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.white)
                            .foregroundColor(.blue)
                            .cornerRadius(10)
                            .shadow(radius: 5)
                    }
                    .padding(.horizontal)
                    .sheet(isPresented: $showAddExpense) {
                        AddExpenseView()
                            .environment(\.managedObjectContext, viewContext)
                    }
                }
                .navigationTitle("Expense Tracker")
                .onAppear {
                    calculateTotalSpent()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ExpenseAdded"))) { _ in
                    calculateTotalSpent()
                    refreshTrigger.toggle()
                }
            }
        }
    }

    private func deleteExpense(at offsets: IndexSet) {
        for index in offsets {
            viewContext.delete(expenses[index])
        }
        saveContext()
        calculateTotalSpent()
    }

    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            print("Error saving: \(error.localizedDescription)")
        }
    }

    private func calculateTotalSpent() {
        totalSpent = expenses.reduce(0) { $0 + $1.amount }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
    }
}

