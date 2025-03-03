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
    @State private var sortOption: String = "Newest First"
    @State private var showShareSheet = false
    @State private var csvFileURL: URL?

    @AppStorage("monthlyBudget") private var monthlyBudget: Double = 500.0
    @State private var showBudgetAlert = false

    let categories = ["All", "Food", "Transport", "Entertainment", "Other"]
    let sortOptions = ["Newest First", "Oldest First", "Highest Amount", "Lowest Amount"]

    var filteredAndSortedExpenses: [Expense] {
        var filtered = selectedCategory == "All" ? Array(expenses) : expenses.filter { $0.category == selectedCategory }

        switch sortOption {
        case "Newest First":
            return filtered.sorted { $0.date ?? Date() > $1.date ?? Date() }
        case "Oldest First":
            return filtered.sorted { $0.date ?? Date() < $1.date ?? Date() }
        case "Highest Amount":
            return filtered.sorted { $0.amount > $1.amount }
        case "Lowest Amount":
            return filtered.sorted { $0.amount < $1.amount }
        default:
            return filtered
        }
    }

    var budgetProgress: Double {
        min(totalSpent / monthlyBudget, 1.0)
    }

    var body: some View {
        ZStack {
            // Gradient Background
            LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)

            NavigationView {
                VStack {
                    // 🔹 Budget Section
                    VStack {
                        Text("Monthly Budget: $\(monthlyBudget, specifier: "%.2f")")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        ProgressView(value: budgetProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                            .frame(width: 250)
                            .padding()

                        Text("Spent: $\(totalSpent, specifier: "%.2f")")
                            .font(.headline)
                            .foregroundColor(totalSpent > monthlyBudget ? .red : .white)

                        Button("Set Budget") {
                            showBudgetAlert = true
                        }
                        .padding()
                        .background(Color.white)
                        .foregroundColor(.blue)
                        .cornerRadius(10)
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 15).fill(Color.white.opacity(0.2)))
                    .shadow(radius: 5)
                    .padding(.horizontal)

                    // Category Filter
                    Picker("Filter by Category", selection: $selectedCategory) {
                        ForEach(categories, id: \.self) { category in
                            Text(category)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)

                    // Sorting Options
                    Picker("Sort By", selection: $sortOption) {
                        ForEach(sortOptions, id: \.self) { option in
                            Text(option)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .padding(.horizontal)

                    // Expense List
                    List {
                        ForEach(filteredAndSortedExpenses) { expense in
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

                    // Export CSV Button
                    Button(action: {
                        exportCSV()
                    }) {
                        Text("Export Expenses as CSV")
                            .font(.title2)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.white)
                            .foregroundColor(.blue)
                            .cornerRadius(10)
                            .shadow(radius: 5)
                    }
                    .padding(.horizontal)

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
                .alert("Set Monthly Budget", isPresented: $showBudgetAlert) {
                    TextField("Enter Budget", value: $monthlyBudget, formatter: NumberFormatter())
                    Button("OK", role: .cancel) {}
                }
            }
        }
    }

    private func exportCSV() {
        let fileName = "Expenses.csv"
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        var csvText = "Name,Amount,Category,Date\n"

        for expense in expenses {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateString = dateFormatter.string(from: expense.date ?? Date())

            let line = "\(expense.name ?? "Unknown"),\(expense.amount),\(expense.category ?? "Other"),\(dateString)\n"
            csvText.append(line)
        }

        do {
            try csvText.write(to: path, atomically: true, encoding: .utf8)
            self.csvFileURL = path
            self.showShareSheet = true
        } catch {
            print("Failed to create CSV file: \(error.localizedDescription)")
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

