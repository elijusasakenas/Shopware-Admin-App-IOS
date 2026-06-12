//
//  ContentView.swift
//  ShopwareApp
//
//  Native SwiftUI dashboard for Shopware 6 Admin API.
//

import Charts
import Combine
import Foundation
import Security
import SwiftUI

// MARK: - Root

struct ContentView: View {
    @StateObject private var viewModel = ShopwareDashboardViewModel()

    var body: some View {
        Group {
            if viewModel.isBooting {
                ProgressView()
                    .tint(.shopwareBlue)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.appBackground)
            } else if viewModel.connection == nil {
                ConnectView(viewModel: viewModel)
            } else {
                DashboardView(viewModel: viewModel)
            }
        }
        // The palette is light-only; forcing light mode keeps text readable in system dark mode
        .preferredColorScheme(.light)
        .task { await viewModel.boot() }
    }
}

// MARK: - Connect

struct ConnectView: View {
    @ObservedObject var viewModel: ShopwareDashboardViewModel
    @State private var shopURL = ""
    @State private var accessKey = ""
    @State private var secretKey = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Shopware Admin API")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.shopwareBlue)
                            .textCase(.uppercase)
                        Text("Connect your shop")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundStyle(Color.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 36)

                    VStack(spacing: 16) {
                        FormField(title: "Shop URL", placeholder: "https://your-shop.com", text: $shopURL)
                        FormField(title: "Access key", placeholder: "SWIA...", text: $accessKey)
                        FormField(title: "Secret access key", placeholder: "Secret", text: $secretKey, isSecure: true)
                    }

                    if let msg = viewModel.errorMessage { ErrorBanner(message: msg) }

                    Button {
                        Task {
                            await viewModel.connect(ShopwareConnection(shopURL: shopURL, accessKey: accessKey, secretKey: secretKey))
                        }
                    } label: {
                        if viewModel.isLoading { ProgressView().tint(.white) }
                        else { Text("Connect").fontWeight(.bold) }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!canConnect || viewModel.isLoading)
                }
                .padding(22)
            }
            .background(Color.appBackground)
        }
    }

    private var canConnect: Bool {
        !shopURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !accessKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !secretKey.isEmpty
    }
}

// MARK: - Dashboard

struct DashboardView: View {
    @ObservedObject var viewModel: ShopwareDashboardViewModel
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header — identity block like the admin sidebar
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(red: 0.47, green: 0.71, blue: 1.0).opacity(0.18))
                            Text(String((viewModel.connection?.displayHost ?? "S").prefix(1)).uppercased())
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(Color(red: 0.47, green: 0.71, blue: 1.0))
                        }
                        .frame(width: 44, height: 44)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(viewModel.connection?.displayHost ?? "Shopware")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color(red: 0.22, green: 0.82, blue: 0.42))
                                    .frame(width: 7, height: 7)
                                Text(viewModel.versionString.isEmpty
                                     ? "Administration"
                                     : "Administration \(viewModel.versionString)")
                                    .font(.caption)
                                    .foregroundStyle(Color(red: 0.62, green: 0.69, blue: 0.78))
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.white.opacity(0.85))
                                .frame(width: 38, height: 38)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Shop settings")

                        Button {
                            Task { await viewModel.disconnect() }
                        } label: {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 15))
                                .foregroundStyle(.white.opacity(0.85))
                                .frame(width: 38, height: 38)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Disconnect")
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.14, green: 0.19, blue: 0.28), Color.swNavy],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    // Sales channel selector
                    Menu {
                        Button {
                            Task { await viewModel.selectChannel(nil) }
                        } label: {
                            if viewModel.selectedChannelID == nil {
                                Label("All sales channels", systemImage: "checkmark")
                            } else {
                                Text("All sales channels")
                            }
                        }
                        ForEach(viewModel.salesChannels) { channel in
                            Button {
                                Task { await viewModel.selectChannel(channel.id) }
                            } label: {
                                if viewModel.selectedChannelID == channel.id {
                                    Label(channel.name, systemImage: "checkmark")
                                } else {
                                    Text(channel.name)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "cart")
                                .font(.subheadline)
                            Text(viewModel.selectedChannelName)
                                .font(.subheadline.weight(.bold))
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption.weight(.bold))
                        }
                        .foregroundStyle(Color.primaryText)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 46)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    if let msg = viewModel.errorMessage { ErrorBanner(message: msg) }

                    // KPI cards
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        MetricCard(title: "Orders today", value: viewModel.metrics?.orderCountToday.formatted() ?? "-", accent: .shopwareBlue)
                        MetricCard(title: "Revenue today", value: viewModel.metrics?.todayRevenue.formatted(.currency(code: viewModel.metrics?.currencyCode ?? "EUR")) ?? "-", accent: .amber)
                        MetricCard(title: "Products", value: viewModel.metrics?.productCount.formatted() ?? "-", accent: .blue)
                        MetricCard(title: "Customers", value: viewModel.metrics?.customerCount.formatted() ?? "-", accent: .red)
                    }

                    // Orders chart
                    ChartCard(
                        title: "Orders",
                        ranges: DateRange.allCases,
                        selectedRange: $viewModel.ordersRange,
                        isLoading: viewModel.isLoading,
                        onRangeChange: { Task { await viewModel.fetchOrdersHistory() } }
                    ) {
                        OrdersBarChart(buckets: viewModel.orderBuckets, range: viewModel.ordersRange)
                    }

                    // Turnover chart
                    ChartCard(
                        title: "Turnover",
                        ranges: DateRange.allCases,
                        selectedRange: $viewModel.revenueRange,
                        isLoading: viewModel.isLoading,
                        onRangeChange: { Task { await viewModel.fetchRevenueHistory() } }
                    ) {
                        RevenueBarChart(buckets: viewModel.revenueBuckets, range: viewModel.revenueRange, currency: viewModel.metrics?.currencyCode ?? "EUR")
                    }

                    // Today's orders list
                    HStack {
                        Text("Today's orders")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.primaryText)
                        Spacer()
                        Button {
                            Task { await viewModel.refresh() }
                        } label: {
                            Image(systemName: "arrow.clockwise").font(.headline)
                        }
                        .buttonStyle(IconButtonStyle())
                        .disabled(viewModel.isLoading)
                    }

                    OrderList(orders: viewModel.metrics?.latestOrders ?? [], isLoading: viewModel.isLoading)

                    // Top products
                    if !viewModel.topProducts.isEmpty {
                        Text("Top products · 30 days")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.primaryText)
                        VStack(spacing: 0) {
                            ForEach(Array(viewModel.topProducts.enumerated()), id: \.element.id) { index, product in
                                HStack(spacing: 12) {
                                    Text("\(index + 1)")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(Color.shopwareBlue)
                                        .frame(width: 24)
                                    Text(product.label)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color.primaryText)
                                        .lineLimit(1)
                                    Spacer()
                                    Text("\(product.quantitySold) sold")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(Color.secondaryText)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                if product.id != viewModel.topProducts.last?.id {
                                    Divider().padding(.leading, 14)
                                }
                            }
                        }
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.border, lineWidth: 1))
                    }

                    // Low stock alert
                    if !viewModel.lowStockProducts.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color.amber)
                            Text("Low stock")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Color.primaryText)
                        }
                        VStack(spacing: 0) {
                            ForEach(viewModel.lowStockProducts) { product in
                                HStack(spacing: 12) {
                                    Text(product.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color.primaryText)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(product.stock == 0 ? "Out of stock" : "\(product.stock) left")
                                        .font(.caption.weight(.bold))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(product.stock == 0 ? Color.red.opacity(0.12) : Color.amber.opacity(0.12))
                                        .foregroundStyle(product.stock == 0 ? Color.red : Color.amber)
                                        .clipShape(Capsule())
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                if product.id != viewModel.lowStockProducts.last?.id {
                                    Divider().padding(.leading, 14)
                                }
                            }
                        }
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.border, lineWidth: 1))
                    }
                }
                .padding(20)
                .padding(.bottom, 32)
            }
            .background(Color.appBackground)
            .refreshable { await viewModel.refresh() }
            .task { await viewModel.refresh() }
            .navigationDestination(for: LatestOrder.self) { order in
                OrderDetailView(viewModel: viewModel, order: order)
            }
            .sheet(isPresented: $showSettings) {
                ShopSettingsView(viewModel: viewModel)
            }
        }
    }
}

// MARK: - Order detail

struct OrderDetailView: View {
    @ObservedObject var viewModel: ShopwareDashboardViewModel
    let order: LatestOrder

    @State private var lineItems: [OrderLineItem] = []
    @State private var customerName = ""
    @State private var customerEmail = ""
    @State private var orderState: String
    @State private var orderTransitions: [OrderTransition] = []
    @State private var transactionID: String?
    @State private var paymentState = ""
    @State private var paymentTransitions: [OrderTransition] = []
    @State private var deliveryID: String?
    @State private var deliveryState = ""
    @State private var deliveryTransitions: [OrderTransition] = []
    @State private var isLoading = true
    @State private var isTransitioning = false
    @State private var errorMessage: String?

    init(viewModel: ShopwareDashboardViewModel, order: LatestOrder) {
        self.viewModel = viewModel
        self.order = order
        _orderState = State(initialValue: order.state)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Order header
                VStack(alignment: .leading, spacing: 8) {
                    Text(order.orderNumber)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(Color.primaryText)
                    Text(order.displayDate)
                        .font(.subheadline)
                        .foregroundStyle(Color.secondaryText)
                    HStack {
                        Text(orderState)
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.shopwareBlue.opacity(0.12))
                            .foregroundStyle(Color.shopwareBlue)
                            .clipShape(Capsule())
                        Spacer()
                        Text(order.amountTotal.formatted(.currency(code: order.currencyCode)))
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.primaryText)
                    }
                }

                if let errorMessage { ErrorBanner(message: errorMessage) }

                // Customer
                if !customerName.isEmpty || !customerEmail.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Customer")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.primaryText)
                        if !customerName.isEmpty {
                            Text(customerName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.primaryText)
                        }
                        if !customerEmail.isEmpty {
                            Text(customerEmail)
                                .font(.subheadline)
                                .foregroundStyle(Color.secondaryText)
                                .textSelection(.enabled)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.border, lineWidth: 1))
                }

                // Line items
                VStack(alignment: .leading, spacing: 8) {
                    Text("Items")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.primaryText)
                    if isLoading {
                        ProgressView().tint(.shopwareBlue).frame(maxWidth: .infinity).padding(12)
                    } else if lineItems.isEmpty {
                        Text("No items found.")
                            .font(.subheadline)
                            .foregroundStyle(Color.secondaryText)
                    } else {
                        ForEach(lineItems) { item in
                            HStack(spacing: 12) {
                                Text("\(item.quantity)×")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(Color.shopwareBlue)
                                Text(item.label)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.primaryText)
                                Spacer()
                                Text(item.totalPrice.formatted(.currency(code: order.currencyCode)))
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(Color.primaryText)
                            }
                            .padding(.vertical, 6)
                            if item.id != lineItems.last?.id { Divider() }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.border, lineWidth: 1))

                // Status management
                StateTransitionCard(
                    title: "Order status",
                    currentState: orderState,
                    transitions: orderTransitions,
                    isBusy: isTransitioning
                ) { transition in
                    Task { await perform(entityName: "order", entityID: order.id, transition: transition) }
                }

                if let transactionID, !paymentState.isEmpty {
                    StateTransitionCard(
                        title: "Payment status",
                        currentState: paymentState,
                        transitions: paymentTransitions,
                        isBusy: isTransitioning
                    ) { transition in
                        Task { await perform(entityName: "order_transaction", entityID: transactionID, transition: transition) }
                    }
                }

                if let deliveryID, !deliveryState.isEmpty {
                    StateTransitionCard(
                        title: "Delivery status",
                        currentState: deliveryState,
                        transitions: deliveryTransitions,
                        isBusy: isTransitioning
                    ) { transition in
                        Task { await perform(entityName: "order_delivery", entityID: deliveryID, transition: transition) }
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 32)
        }
        .background(Color.appBackground)
        .navigationTitle("Order")
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await load() }
    }

    private func load() async {
        do {
            lineItems = try await viewModel.orderLineItems(orderID: order.id)
            if let customer = try await viewModel.orderCustomer(orderID: order.id) {
                customerName = customer.name
                customerEmail = customer.email
            }
            orderTransitions = try await viewModel.stateTransitions(entityName: "order", entityID: order.id)

            if let transaction = try await viewModel.orderTransaction(orderID: order.id) {
                transactionID = transaction.id
                paymentState = transaction.state
                paymentTransitions = try await viewModel.stateTransitions(entityName: "order_transaction", entityID: transaction.id)
            }
            if let delivery = try await viewModel.orderDelivery(orderID: order.id) {
                deliveryID = delivery.id
                deliveryState = delivery.state
                deliveryTransitions = try await viewModel.stateTransitions(entityName: "order_delivery", entityID: delivery.id)
            }
        } catch {
            errorMessage = error.shopwareDisplayMessage
        }
        isLoading = false
    }

    private func perform(entityName: String, entityID: String, transition: OrderTransition) async {
        isTransitioning = true
        errorMessage = nil
        do {
            try await viewModel.performTransition(entityName: entityName, entityID: entityID, action: transition.actionName)
            switch entityName {
            case "order":
                orderState = transition.displayName
                orderTransitions = (try? await viewModel.stateTransitions(entityName: entityName, entityID: entityID)) ?? []
            case "order_transaction":
                paymentState = transition.displayName
                paymentTransitions = (try? await viewModel.stateTransitions(entityName: entityName, entityID: entityID)) ?? []
            case "order_delivery":
                deliveryState = transition.displayName
                deliveryTransitions = (try? await viewModel.stateTransitions(entityName: entityName, entityID: entityID)) ?? []
            default:
                break
            }
            await viewModel.refresh()
        } catch {
            errorMessage = error.shopwareDisplayMessage
        }
        isTransitioning = false
    }
}

struct StateTransitionCard: View {
    let title: String
    let currentState: String
    let transitions: [OrderTransition]
    let isBusy: Bool
    let onSelect: (OrderTransition) -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.secondaryText)
                    .textCase(.uppercase)
                Text(currentState)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.primaryText)
            }
            Spacer()
            if isBusy {
                ProgressView().tint(.shopwareBlue)
            } else if !transitions.isEmpty {
                Menu {
                    ForEach(transitions) { transition in
                        Button(transition.displayName) { onSelect(transition) }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text("Change")
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2.weight(.bold))
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 40)
                    .background(Color.shopwareBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.border, lineWidth: 1))
    }
}

// MARK: - Shop settings

struct ShopSettingsView: View {
    @ObservedObject var viewModel: ShopwareDashboardViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var promotions: [Promotion] = []
    @State private var recipients: [NewsletterRecipient] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let errorMessage { ErrorBanner(message: errorMessage) }

                    if isLoading {
                        ProgressView()
                            .tint(.shopwareBlue)
                            .frame(maxWidth: .infinity)
                            .padding(40)
                    } else {
                        // Subpages
                        VStack(spacing: 0) {
                            NavigationLink {
                                NewCustomersView(viewModel: viewModel)
                            } label: {
                                SettingsRow(icon: "person.crop.circle.badge.plus", title: "New customer registrations")
                            }
                            .buttonStyle(.plain)
                            Divider().padding(.leading, 52)
                            NavigationLink {
                                ShopStatusView(viewModel: viewModel)
                            } label: {
                                SettingsRow(icon: "waveform.path.ecg", title: "Shop status & log")
                            }
                            .buttonStyle(.plain)
                        }
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.border, lineWidth: 1))

                        // Maintenance mode
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Maintenance mode")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Color.primaryText)
                            Text("Visitors see a maintenance page while enabled.")
                                .font(.caption)
                                .foregroundStyle(Color.secondaryText)

                            ForEach(viewModel.salesChannels) { channel in
                                Toggle(isOn: maintenanceBinding(for: channel)) {
                                    Text(channel.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color.primaryText)
                                }
                                .tint(.shopwareBlue)
                                .padding(.vertical, 4)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.border, lineWidth: 1))

                        // Marketing / promotions
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Marketing")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Color.primaryText)
                            Text("Enable or disable promotions instantly.")
                                .font(.caption)
                                .foregroundStyle(Color.secondaryText)

                            if promotions.isEmpty {
                                Text("No promotions yet. Create them in the admin under Marketing > Promotions.")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.secondaryText)
                                    .padding(.vertical, 8)
                            } else {
                                ForEach(promotions) { promotion in
                                    Toggle(isOn: promotionBinding(for: promotion)) {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(promotion.name)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(Color.primaryText)
                                            if let code = promotion.code, !code.isEmpty {
                                                Text("Code: \(code)")
                                                    .font(.caption)
                                                    .foregroundStyle(Color.secondaryText)
                                            }
                                        }
                                    }
                                    .tint(.shopwareBlue)
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.border, lineWidth: 1))

                        // Newsletter registrations
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Newsletter signups")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Color.primaryText)
                            Text("Latest registrations, newest first.")
                                .font(.caption)
                                .foregroundStyle(Color.secondaryText)

                            if recipients.isEmpty {
                                Text("No newsletter registrations yet.")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.secondaryText)
                                    .padding(.vertical, 8)
                            } else {
                                ForEach(recipients) { recipient in
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(recipient.email)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(Color.primaryText)
                                                .lineLimit(1)
                                            if let createdAt = recipient.createdAt {
                                                Text(createdAt.formatted(date: .abbreviated, time: .shortened))
                                                    .font(.caption)
                                                    .foregroundStyle(Color.secondaryText)
                                            }
                                        }
                                        Spacer()
                                        Text(recipient.statusLabel)
                                            .font(.caption.weight(.bold))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(statusColor(recipient.status).opacity(0.12))
                                            .foregroundStyle(statusColor(recipient.status))
                                            .clipShape(Capsule())
                                    }
                                    .padding(.vertical, 5)
                                    if recipient.id != recipients.last?.id { Divider() }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.border, lineWidth: 1))
                    }
                }
                .padding(20)
            }
            .background(Color.appBackground)
            .navigationTitle("Shop settings")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await load() }
        }
    }

    private func load() async {
        do {
            async let promos = viewModel.promotions()
            async let news = viewModel.newsletterRecipients()
            promotions = try await promos
            recipients = try await news
        } catch {
            errorMessage = error.shopwareDisplayMessage
        }
        isLoading = false
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "optIn":  return .shopwareBlue
        case "direct": return .blue
        case "optOut": return .red
        default:       return .amber
        }
    }

    private func promotionBinding(for promotion: Promotion) -> Binding<Bool> {
        Binding(
            get: { promotions.first { $0.id == promotion.id }?.active ?? false },
            set: { newValue in
                Task {
                    do {
                        try await viewModel.setPromotionActive(promotionID: promotion.id, active: newValue)
                        if let index = promotions.firstIndex(where: { $0.id == promotion.id }) {
                            promotions[index].active = newValue
                        }
                    } catch {
                        errorMessage = error.shopwareDisplayMessage
                    }
                }
            }
        )
    }

    private func maintenanceBinding(for channel: SalesChannel) -> Binding<Bool> {
        Binding(
            get: { viewModel.salesChannels.first { $0.id == channel.id }?.maintenance ?? false },
            set: { newValue in
                Task {
                    do { try await viewModel.setMaintenance(channelID: channel.id, enabled: newValue) }
                    catch { errorMessage = error.shopwareDisplayMessage }
                }
            }
        )
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(Color.shopwareBlue)
                .frame(width: 28)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.primaryText)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.secondaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

// MARK: - New customers

struct NewCustomersView: View {
    @ObservedObject var viewModel: ShopwareDashboardViewModel

    @State private var customers: [CustomerRegistration] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let errorMessage { ErrorBanner(message: errorMessage) }

                if isLoading {
                    ProgressView().tint(.shopwareBlue).frame(maxWidth: .infinity).padding(40)
                } else if customers.isEmpty {
                    Text("No customer registrations yet.")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(40)
                } else {
                    VStack(spacing: 0) {
                        ForEach(customers) { customer in
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(customer.name.isEmpty ? customer.email : customer.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color.primaryText)
                                        .lineLimit(1)
                                    Text(customer.email)
                                        .font(.caption)
                                        .foregroundStyle(Color.secondaryText)
                                        .lineLimit(1)
                                    if let createdAt = customer.createdAt {
                                        Text(createdAt.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption2)
                                            .foregroundStyle(Color.secondaryText)
                                    }
                                }
                                Spacer()
                                Text(customer.guest ? "Guest" : "Account")
                                    .font(.caption.weight(.bold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background((customer.guest ? Color.amber : Color.shopwareBlue).opacity(0.12))
                                    .foregroundStyle(customer.guest ? Color.amber : Color.shopwareBlue)
                                    .clipShape(Capsule())
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            if customer.id != customers.last?.id {
                                Divider().padding(.leading, 14)
                            }
                        }
                    }
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.border, lineWidth: 1))
                }
            }
            .padding(20)
        }
        .background(Color.appBackground)
        .navigationTitle("New customers")
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            do { customers = try await viewModel.recentCustomers() }
            catch { errorMessage = error.shopwareDisplayMessage }
            isLoading = false
        }
    }
}

// MARK: - Shop status & log

struct ShopStatusView: View {
    @ObservedObject var viewModel: ShopwareDashboardViewModel

    @State private var version = ""
    @State private var domains: [DomainStatus] = []
    @State private var logEntries: [LogEntry] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let errorMessage { ErrorBanner(message: errorMessage) }

                if isLoading {
                    ProgressView().tint(.shopwareBlue).frame(maxWidth: .infinity).padding(40)
                } else {
                    // Version
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Shopware version")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.secondaryText)
                                .textCase(.uppercase)
                            Text(version)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.primaryText)
                        }
                        Spacer()
                        Image(systemName: "checkmark.seal.fill")
                            .font(.title2)
                            .foregroundStyle(Color.shopwareBlue)
                    }
                    .padding(16)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.border, lineWidth: 1))

                    // Storefront reachability
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Storefront availability")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.primaryText)

                        if domains.isEmpty {
                            Text("No storefront domains configured.")
                                .font(.subheadline)
                                .foregroundStyle(Color.secondaryText)
                        } else {
                            ForEach(domains) { domain in
                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(domain.isHealthy ? Color.green : Color.red)
                                        .frame(width: 10, height: 10)
                                    Text(domain.url)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color.primaryText)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                    Spacer()
                                    if let ms = domain.responseMs {
                                        Text("\(ms) ms")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(Color.secondaryText)
                                    }
                                    Text(domain.statusCode.map(String.init) ?? "—")
                                        .font(.caption.weight(.bold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background((domain.isHealthy ? Color.green : Color.red).opacity(0.12))
                                        .foregroundStyle(domain.isHealthy ? Color.green : Color.red)
                                        .clipShape(Capsule())
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.border, lineWidth: 1))

                    // Shop log
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Shop log")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.primaryText)

                        if logEntries.isEmpty {
                            Text("The log is empty.")
                                .font(.subheadline)
                                .foregroundStyle(Color.secondaryText)
                        } else {
                            ForEach(logEntries) { entry in
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack {
                                        Text(entry.levelLabel)
                                            .font(.caption2.weight(.bold))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(entry.levelColor.opacity(0.12))
                                            .foregroundStyle(entry.levelColor)
                                            .clipShape(Capsule())
                                        Spacer()
                                        if let createdAt = entry.createdAt {
                                            Text(createdAt.formatted(date: .abbreviated, time: .shortened))
                                                .font(.caption2)
                                                .foregroundStyle(Color.secondaryText)
                                        }
                                    }
                                    Text(entry.message)
                                        .font(.caption)
                                        .foregroundStyle(Color.primaryText)
                                        .lineLimit(3)
                                }
                                .padding(.vertical, 6)
                                if entry.id != logEntries.last?.id { Divider() }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.border, lineWidth: 1))
                }
            }
            .padding(20)
        }
        .background(Color.appBackground)
        .navigationTitle("Shop status")
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await load() }
    }

    private func load() async {
        do {
            version = (try? await viewModel.shopwareVersion()) ?? "Unknown"
            logEntries = (try? await viewModel.logEntries()) ?? []
            let urls = try await viewModel.domainURLs()
            var results: [DomainStatus] = []
            for url in urls {
                results.append(await checkDomain(url))
            }
            domains = results
        } catch {
            errorMessage = error.shopwareDisplayMessage
        }
        isLoading = false
    }

    private func checkDomain(_ urlString: String) async -> DomainStatus {
        guard let url = URL(string: urlString) else {
            return DomainStatus(url: urlString, statusCode: nil, responseMs: nil)
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        let start = Date()
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let ms = Int(Date().timeIntervalSince(start) * 1000)
            return DomainStatus(url: urlString, statusCode: (response as? HTTPURLResponse)?.statusCode, responseMs: ms)
        } catch {
            return DomainStatus(url: urlString, statusCode: nil, responseMs: nil)
        }
    }
}

// MARK: - Chart card wrapper

struct ChartCard<ChartContent: View>: View {
    let title: String
    let ranges: [DateRange]
    @Binding var selectedRange: DateRange
    let isLoading: Bool
    let onRangeChange: () -> Void
    @ViewBuilder let chartContent: () -> ChartContent

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.primaryText)
                    Text(selectedRange.subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText)
                }
                Spacer()
                if isLoading {
                    ProgressView().scaleEffect(0.7)
                }
                Menu {
                    ForEach(ranges, id: \.self) { range in
                        Button {
                            selectedRange = range
                            onRangeChange()
                        } label: {
                            if selectedRange == range {
                                Label(range.menuLabel, systemImage: "checkmark")
                            } else {
                                Text(range.menuLabel)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(selectedRange.menuLabel)
                            .font(.subheadline)
                        Image(systemName: "chevron.down")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(Color.primaryText)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 36)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Color.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            chartContent()
                .frame(height: 190)
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.border.opacity(0.7), lineWidth: 1))
    }
}

// MARK: - Charts

struct OrdersBarChart: View {
    let buckets: [DashboardBucket]
    let range: DateRange

    var body: some View {
        if buckets.isEmpty {
            ChartEmptyState(text: "No orders in this period")
        } else {
            Chart(buckets) { bucket in
                AreaMark(
                    x: .value("Date", bucket.date, unit: range.calendarComponent),
                    y: .value("Orders", bucket.count)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.shopwareBlue.opacity(0.16), Color.shopwareBlue.opacity(0.01)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .interpolationMethod(.monotone)

                LineMark(
                    x: .value("Date", bucket.date, unit: range.calendarComponent),
                    y: .value("Orders", bucket.count)
                )
                .foregroundStyle(Color.shopwareBlue)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.monotone)
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                    AxisValueLabel(format: range.axisFormat)
                        .foregroundStyle(Color.secondaryText)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine().foregroundStyle(Color.border.opacity(0.55))
                    AxisValueLabel {
                        if let v = value.as(Int.self) {
                            Text("\(v)").foregroundStyle(Color.secondaryText)
                        }
                    }
                }
            }
        }
    }
}

struct RevenueBarChart: View {
    let buckets: [DashboardBucket]
    let range: DateRange
    let currency: String

    var body: some View {
        if buckets.isEmpty {
            ChartEmptyState(text: "No turnover in this period")
        } else {
            Chart(buckets) { bucket in
                AreaMark(
                    x: .value("Date", bucket.date, unit: range.calendarComponent),
                    y: .value("Turnover", bucket.amount)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.shopwareBlue.opacity(0.16), Color.shopwareBlue.opacity(0.01)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .interpolationMethod(.monotone)

                LineMark(
                    x: .value("Date", bucket.date, unit: range.calendarComponent),
                    y: .value("Turnover", bucket.amount)
                )
                .foregroundStyle(Color.shopwareBlue)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.monotone)
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                    AxisValueLabel(format: range.axisFormat)
                        .foregroundStyle(Color.secondaryText)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine().foregroundStyle(Color.border.opacity(0.55))
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(v.formatted(.currency(code: currency).precision(.fractionLength(2))))
                                .font(.caption2)
                                .foregroundStyle(Color.secondaryText)
                        }
                    }
                }
            }
        }
    }
}

struct ChartEmptyState: View {
    let text: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.xyaxis.line")
                .font(.title2)
                .foregroundStyle(Color.border)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Color.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Date ranges

enum DateRange: String, CaseIterable {
    case days30 = "30Days"
    case days14 = "14Days"
    case days7  = "7Days"
    case hours24 = "24Hours"
    case yesterday = "Yesterday"

    var label: String {
        switch self {
        case .days30:    return "30 days"
        case .days14:    return "14 days"
        case .days7:     return "7 days"
        case .hours24:   return "24 hours"
        case .yesterday: return "Yesterday"
        }
    }

    var menuLabel: String {
        switch self {
        case .days30:    return "Last 30 days"
        case .days14:    return "Last 14 days"
        case .days7:     return "Last 7 days"
        case .hours24:   return "Last 24 hours"
        case .yesterday: return "Yesterday"
        }
    }

    // "13 May - 12 Jun" under the card title, like the admin dashboard
    var subtitle: String {
        let format = Date.FormatStyle().day().month(.abbreviated)
        if self == .yesterday {
            return sinceDate.formatted(format)
        }
        return "\(sinceDate.formatted(format)) - \(Date().formatted(format))"
    }

    var sinceDate: Date {
        let cal = Calendar.current
        let now = Date()
        switch self {
        case .days30:
            return cal.startOfDay(for: cal.date(byAdding: .day, value: -30, to: now)!)
        case .days14:
            return cal.startOfDay(for: cal.date(byAdding: .day, value: -14, to: now)!)
        case .days7:
            return cal.startOfDay(for: cal.date(byAdding: .day, value: -7, to: now)!)
        case .hours24:
            return cal.date(byAdding: .hour, value: -24, to: now)!
        case .yesterday:
            return cal.startOfDay(for: cal.date(byAdding: .day, value: -1, to: now)!)
        }
    }

    var calendarComponent: Calendar.Component {
        switch self {
        case .hours24, .yesterday: return .hour
        default:                   return .day
        }
    }

    var histogramInterval: String {
        switch self {
        case .hours24, .yesterday: return "hour"
        default:                   return "day"
        }
    }

    var axisFormat: Date.FormatStyle {
        switch self {
        case .hours24, .yesterday: return .dateTime.hour()
        default:                   return .dateTime.month(.abbreviated).day()
        }
    }
}

// MARK: - Sub-views

struct FormField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var isSecure = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.secondaryText)
            Group {
                if isSecure { SecureField(placeholder, text: $text) }
                else { TextField(placeholder, text: $text) }
            }
            .autocorrectionDisabled()
            .font(.body)
            .foregroundStyle(Color.primaryText)
            .tint(Color.shopwareBlue)
            .padding(.horizontal, 14)
            .frame(minHeight: 52)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.border, lineWidth: 1))
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Circle().fill(accent).frame(width: 8, height: 8)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)
                    .lineLimit(1)
            }
            Text(value)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Color.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.border.opacity(0.7), lineWidth: 1))
    }
}

struct OrderList: View {
    let orders: [LatestOrder]
    let isLoading: Bool

    var body: some View {
        VStack(spacing: 0) {
            if orders.isEmpty {
                Text(isLoading ? "Loading..." : "No orders today.")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(18)
            } else {
                ForEach(orders) { order in
                    NavigationLink(value: order) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(order.orderNumber)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(Color.primaryText)
                                    .lineLimit(1)
                                Text("\(order.displayDate) · \(order.state)")
                                    .font(.caption)
                                    .foregroundStyle(Color.secondaryText)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Text(order.amountTotal.formatted(.currency(code: order.currencyCode)))
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Color.primaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.secondaryText)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    if order.id != orders.last?.id {
                        Divider().padding(.leading, 14)
                    }
                }
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.border, lineWidth: 1))
    }
}

struct ErrorBanner: View {
    let message: String
    var body: some View {
        Text(message)
            .font(.subheadline)
            .foregroundStyle(Color(red: 0.56, green: 0.11, blue: 0.09))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(red: 1.0, green: 0.94, blue: 0.93))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color(red: 0.95, green: 0.71, blue: 0.68), lineWidth: 1))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(Color.white)
            .background(Color.shopwareBlue.opacity(configuration.isPressed ? 0.82 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 48, height: 44)
            .foregroundStyle(Color.primaryText)
            .background(Color(red: 0.91, green: 0.94, blue: 0.96).opacity(configuration.isPressed ? 0.7 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

// MARK: - ViewModel

@MainActor
final class ShopwareDashboardViewModel: ObservableObject {
    @Published var connection: ShopwareConnection?
    @Published var metrics: DashboardMetrics?
    @Published var orderBuckets: [DashboardBucket] = []
    @Published var revenueBuckets: [DashboardBucket] = []
    @Published var errorMessage: String?
    @Published var isBooting = true
    @Published var isLoading = false
    @Published var ordersRange: DateRange = .days30
    @Published var revenueRange: DateRange = .days30
    @Published var salesChannels: [SalesChannel] = []
    @Published var selectedChannelID: String?
    @Published var lowStockProducts: [LowStockProduct] = []
    @Published var topProducts: [TopProduct] = []
    @Published var versionString = ""

    var selectedChannelName: String {
        guard let id = selectedChannelID else { return "All sales channels" }
        return salesChannels.first { $0.id == id }?.name ?? "Sales channel"
    }

    private let credentialStore = CredentialStore()
    private var client: ShopwareAdminClient?

    func boot() async {
        guard isBooting else { return }
        do {
            connection = try credentialStore.load()
            if let connection { client = ShopwareAdminClient(connection: connection) }
        } catch {
            errorMessage = error.localizedDescription
        }
        isBooting = false
    }

    func connect(_ nextConnection: ShopwareConnection) async {
        isLoading = true
        errorMessage = nil
        do {
            let client = ShopwareAdminClient(connection: nextConnection)
            try await client.testConnection()
            try credentialStore.save(nextConnection)
            self.connection = nextConnection
            self.client = client
            salesChannels = (try? await client.fetchSalesChannels()) ?? []
            await loadAll()
        } catch {
            errorMessage = error.shopwareDisplayMessage
            isLoading = false
        }
    }

    func refresh() async {
        guard let client else { return }
        if salesChannels.isEmpty {
            salesChannels = (try? await client.fetchSalesChannels()) ?? []
        }
        await loadAll()
    }

    func selectChannel(_ id: String?) async {
        guard id != selectedChannelID else { return }
        selectedChannelID = id
        await loadAll()
    }

    private func loadAll() async {
        guard let client else { return }
        isLoading = true
        errorMessage = nil
        if versionString.isEmpty {
            versionString = (try? await client.fetchShopwareVersion()) ?? ""
        }
        do {
            async let m = client.dashboardMetrics(salesChannelID: selectedChannelID)
            async let ob = client.fetchHistory(paid: false, range: ordersRange, salesChannelID: selectedChannelID)
            async let rb = client.fetchHistory(paid: true, range: revenueRange, salesChannelID: selectedChannelID)
            async let ls = client.fetchLowStockProducts(salesChannelID: selectedChannelID)
            async let tp = client.fetchTopProducts(since: DateRange.days30.sinceDate, salesChannelID: selectedChannelID)
            metrics = try await m
            orderBuckets = try await ob
            revenueBuckets = try await rb
            lowStockProducts = (try? await ls) ?? []
            topProducts = (try? await tp) ?? []
        } catch {
            errorMessage = error.shopwareDisplayMessage
        }
        isLoading = false
    }

    func fetchOrdersHistory() async {
        guard let client else { return }
        isLoading = true
        errorMessage = nil
        do { orderBuckets = try await client.fetchHistory(paid: false, range: ordersRange, salesChannelID: selectedChannelID) }
        catch { errorMessage = error.shopwareDisplayMessage }
        isLoading = false
    }

    func fetchRevenueHistory() async {
        guard let client else { return }
        isLoading = true
        errorMessage = nil
        do { revenueBuckets = try await client.fetchHistory(paid: true, range: revenueRange, salesChannelID: selectedChannelID) }
        catch { errorMessage = error.shopwareDisplayMessage }
        isLoading = false
    }

    func promotions() async throws -> [Promotion] {
        guard let client else { throw ShopwareAPIError.message("Not connected.") }
        return try await client.fetchPromotions()
    }

    func setPromotionActive(promotionID: String, active: Bool) async throws {
        guard let client else { throw ShopwareAPIError.message("Not connected.") }
        try await client.setPromotionActive(promotionID: promotionID, active: active)
    }

    func newsletterRecipients() async throws -> [NewsletterRecipient] {
        guard let client else { throw ShopwareAPIError.message("Not connected.") }
        return try await client.fetchNewsletterRecipients()
    }

    func recentCustomers() async throws -> [CustomerRegistration] {
        guard let client else { throw ShopwareAPIError.message("Not connected.") }
        return try await client.fetchRecentCustomers()
    }

    func logEntries() async throws -> [LogEntry] {
        guard let client else { throw ShopwareAPIError.message("Not connected.") }
        return try await client.fetchLogEntries()
    }

    func domainURLs() async throws -> [String] {
        guard let client else { throw ShopwareAPIError.message("Not connected.") }
        return try await client.fetchDomainURLs()
    }

    func shopwareVersion() async throws -> String {
        guard let client else { throw ShopwareAPIError.message("Not connected.") }
        return try await client.fetchShopwareVersion()
    }

    func setMaintenance(channelID: String, enabled: Bool) async throws {
        guard let client else { throw ShopwareAPIError.message("Not connected.") }
        try await client.setMaintenance(salesChannelID: channelID, enabled: enabled)
        if let index = salesChannels.firstIndex(where: { $0.id == channelID }) {
            salesChannels[index].maintenance = enabled
        }
    }

    func orderLineItems(orderID: String) async throws -> [OrderLineItem] {
        guard let client else { throw ShopwareAPIError.message("Not connected.") }
        return try await client.fetchOrderLineItems(orderID: orderID)
    }

    func orderCustomer(orderID: String) async throws -> (name: String, email: String)? {
        guard let client else { throw ShopwareAPIError.message("Not connected.") }
        return try await client.fetchOrderCustomer(orderID: orderID)
    }

    func stateTransitions(entityName: String, entityID: String) async throws -> [OrderTransition] {
        guard let client else { throw ShopwareAPIError.message("Not connected.") }
        return try await client.fetchStateTransitions(entityName: entityName, entityID: entityID)
    }

    func performTransition(entityName: String, entityID: String, action: String) async throws {
        guard let client else { throw ShopwareAPIError.message("Not connected.") }
        try await client.performStateTransition(entityName: entityName, entityID: entityID, action: action)
    }

    func orderTransaction(orderID: String) async throws -> (id: String, state: String)? {
        guard let client else { throw ShopwareAPIError.message("Not connected.") }
        return try await client.fetchOrderSubEntity("order-transaction", orderID: orderID)
    }

    func orderDelivery(orderID: String) async throws -> (id: String, state: String)? {
        guard let client else { throw ShopwareAPIError.message("Not connected.") }
        return try await client.fetchOrderSubEntity("order-delivery", orderID: orderID)
    }

    func disconnect() async {
        try? credentialStore.clear()
        connection = nil
        client = nil
        metrics = nil
        orderBuckets = []
        revenueBuckets = []
        salesChannels = []
        selectedChannelID = nil
        versionString = ""
    }
}

// MARK: - Models

struct ShopwareConnection: Codable, Equatable {
    var shopURL: String
    var accessKey: String
    var secretKey: String

    var displayHost: String { normalizedBaseURL.host ?? shopURL }

    var normalizedBaseURL: URL {
        let trimmed = shopURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let withScheme = trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://")
            ? trimmed : "https://\(trimmed)"
        return URL(string: withScheme.trimmingCharacters(in: CharacterSet(charactersIn: "/"))) ?? URL(string: "https://example.com")!
    }
}

struct DashboardMetrics {
    var orderCountToday: Int
    var openOrderCount: Int
    var productCount: Int
    var customerCount: Int
    var todayRevenue: Decimal
    var currencyCode: String
    var latestOrders: [LatestOrder]
}

struct SalesChannel: Identifiable, Equatable {
    var id: String
    var name: String
    var maintenance: Bool = false
}

struct Promotion: Identifiable {
    var id: String
    var name: String
    var active: Bool
    var code: String?
}

struct NewsletterRecipient: Identifiable {
    var id: String
    var email: String
    var status: String
    var createdAt: Date?

    var statusLabel: String {
        switch status {
        case "optIn":  return "Confirmed"
        case "direct": return "Registered"
        case "optOut": return "Unsubscribed"
        default:       return "Pending"
        }
    }
}

struct DashboardBucket: Identifiable {
    var id: String { ISO8601DateFormatter.shopware.string(from: date) }
    var date: Date
    var count: Int
    var amount: Double
}

struct OrderLineItem: Identifiable {
    var id: String
    var label: String
    var quantity: Int
    var totalPrice: Decimal
}

struct OrderTransition: Identifiable {
    var id: String { actionName }
    var actionName: String
    var displayName: String
}

struct LowStockProduct: Identifiable {
    var id: String
    var name: String
    var stock: Int
}

struct TopProduct: Identifiable {
    var id: String { label }
    var label: String
    var quantitySold: Int
}

struct CustomerRegistration: Identifiable {
    var id: String
    var name: String
    var email: String
    var createdAt: Date?
    var guest: Bool
}

struct LogEntry: Identifiable {
    var id: String
    var message: String
    var level: Int
    var createdAt: Date?

    var levelLabel: String {
        switch level {
        case 500...: return "Critical"
        case 400...: return "Error"
        case 300...: return "Warning"
        case 250...: return "Notice"
        case 200...: return "Info"
        default:     return "Debug"
        }
    }

    var levelColor: Color {
        switch level {
        case 400...: return .red
        case 300...: return .amber
        default:     return .secondaryText
        }
    }
}

struct DomainStatus: Identifiable {
    var id: String { url }
    var url: String
    var statusCode: Int?
    var responseMs: Int?

    var isHealthy: Bool { (statusCode ?? 0) >= 200 && (statusCode ?? 0) < 400 }
}

struct LatestOrder: Identifiable, Equatable, Hashable {
    var id: String
    var orderNumber: String
    var amountTotal: Decimal
    var orderDateTime: Date?
    var currencyCode: String
    var state: String

    var displayDate: String {
        guard let orderDateTime else { return "No date" }
        return orderDateTime.formatted(date: .abbreviated, time: .shortened)
    }
}

// MARK: - API Client

final class ShopwareAdminClient {
    private let connection: ShopwareConnection
    private let session: URLSession
    private var token: AccessToken?

    init(connection: ShopwareConnection, session: URLSession = .shared) {
        self.connection = connection
        self.session = session
    }

    func testConnection() async throws { _ = try await countEntity("order") }

    func dashboardMetrics(salesChannelID: String?) async throws -> DashboardMetrics {
        let todayFilter: [String: Any] = [
            "type": "range",
            "field": "orderDateTime",
            "parameters": ["gte": Calendar.current.startOfDay(for: Date()).iso8601String]
        ]
        let channelFilter: [String: Any]? = salesChannelID.map {
            ["type": "equals", "field": "salesChannelId", "value": $0]
        }
        let visibilityFilter: [String: Any]? = salesChannelID.map {
            ["type": "equals", "field": "visibilities.salesChannelId", "value": $0]
        }
        let channelFilters: [[String: Any]] = channelFilter.map { [$0] } ?? []

        let todayFilters: [[String: Any]] = [todayFilter] + channelFilters
        let openFilters: [[String: Any]] = [[
            "type": "equals", "field": "stateMachineState.technicalName", "value": "open"
        ]] + channelFilters
        let productFilters: [[String: Any]] = visibilityFilter.map { [$0] } ?? []
        let customerFilters: [[String: Any]] = channelFilters
        let latestFilters: [[String: Any]] = channelFilters

        async let orderCountToday = countEntity("order", filters: todayFilters)
        async let openOrderCount = countEntity("order", filters: openFilters)
        async let productCount = countEntity("product", filters: productFilters)
        async let customerCount = countEntity("customer", filters: customerFilters)
        async let todayOrders = searchOrders([
            "limit": 100,
            "filter": todayFilters,
            "sort": [["field": "orderDateTime", "order": "DESC"]],
            "associations": ["currency": [:]]
        ])
        async let latestOrders = searchOrders([
            "limit": 8,
            "filter": latestFilters,
            "sort": [["field": "orderDateTime", "order": "DESC"]],
            "associations": ["currency": [:], "stateMachineState": [:]]
        ])

        let resolvedToday = try await todayOrders
        let resolvedLatest = try await latestOrders
        let currency = resolvedLatest.first?.currencyCode ?? resolvedToday.first?.currencyCode ?? "EUR"

        return DashboardMetrics(
            orderCountToday: try await orderCountToday,
            openOrderCount: try await openOrderCount,
            productCount: try await productCount,
            customerCount: try await customerCount,
            todayRevenue: resolvedToday.reduce(Decimal(0)) { $0 + $1.amountTotal },
            currencyCode: currency,
            latestOrders: resolvedLatest
        )
    }

    func fetchSalesChannels() async throws -> [SalesChannel] {
        let response = try await requestJSON(path: "/api/search/sales-channel", method: "POST", body: [
            "limit": 50,
            "filter": [["type": "equals", "field": "active", "value": true]],
            "sort": [["field": "name", "order": "ASC"]]
        ])
        return (response["data"] as? [[String: Any]] ?? []).compactMap { row in
            guard let id = row["id"] as? String else { return nil }
            let attrs = entityAttributes(of: row)
            let name = translatedName(from: attrs) ?? attrs["name"] as? String ?? "Unnamed channel"
            let maintenance = attrs["maintenance"] as? Bool ?? false
            return SalesChannel(id: id, name: name, maintenance: maintenance)
        }
    }

    func fetchPromotions() async throws -> [Promotion] {
        let response = try await requestJSON(path: "/api/search/promotion", method: "POST", body: [
            "limit": 25,
            "sort": [["field": "createdAt", "order": "DESC"]]
        ])
        return (response["data"] as? [[String: Any]] ?? []).compactMap { row in
            guard let id = row["id"] as? String else { return nil }
            let attrs = entityAttributes(of: row)
            return Promotion(
                id: id,
                name: translatedName(from: attrs) ?? attrs["name"] as? String ?? "Unnamed promotion",
                active: attrs["active"] as? Bool ?? false,
                code: attrs["code"] as? String
            )
        }
    }

    func setPromotionActive(promotionID: String, active: Bool) async throws {
        _ = try await requestJSON(path: "/api/promotion/\(promotionID)", method: "PATCH", body: [
            "active": active
        ])
    }

    func fetchRecentCustomers() async throws -> [CustomerRegistration] {
        let response = try await requestJSON(path: "/api/search/customer", method: "POST", body: [
            "limit": 25,
            "sort": [["field": "createdAt", "order": "DESC"]]
        ])
        return (response["data"] as? [[String: Any]] ?? []).compactMap { row in
            guard let id = row["id"] as? String else { return nil }
            let attrs = entityAttributes(of: row)
            let first = attrs["firstName"] as? String ?? ""
            let last = attrs["lastName"] as? String ?? ""
            return CustomerRegistration(
                id: id,
                name: "\(first) \(last)".trimmingCharacters(in: .whitespaces),
                email: attrs["email"] as? String ?? "Unknown",
                createdAt: date(from: attrs["createdAt"] as? String),
                guest: attrs["guest"] as? Bool ?? false
            )
        }
    }

    func fetchLogEntries() async throws -> [LogEntry] {
        let response = try await requestJSON(path: "/api/search/log-entry", method: "POST", body: [
            "limit": 25,
            "sort": [["field": "createdAt", "order": "DESC"]]
        ])
        return (response["data"] as? [[String: Any]] ?? []).compactMap { row in
            guard let id = row["id"] as? String else { return nil }
            let attrs = entityAttributes(of: row)
            return LogEntry(
                id: id,
                message: attrs["message"] as? String ?? "No message",
                level: attrs["level"] as? Int ?? 200,
                createdAt: date(from: attrs["createdAt"] as? String)
            )
        }
    }

    func fetchDomainURLs() async throws -> [String] {
        let response = try await requestJSON(path: "/api/search/sales-channel-domain", method: "POST", body: [
            "limit": 10
        ])
        return (response["data"] as? [[String: Any]] ?? []).compactMap { row in
            entityAttributes(of: row)["url"] as? String
        }
    }

    func fetchShopwareVersion() async throws -> String {
        let response = try await requestJSON(path: "/api/_info/version", method: "GET")
        return response["version"] as? String ?? "Unknown"
    }

    func fetchNewsletterRecipients() async throws -> [NewsletterRecipient] {
        let response = try await requestJSON(path: "/api/search/newsletter-recipient", method: "POST", body: [
            "limit": 20,
            "sort": [["field": "createdAt", "order": "DESC"]]
        ])
        return (response["data"] as? [[String: Any]] ?? []).compactMap { row in
            guard let id = row["id"] as? String else { return nil }
            let attrs = entityAttributes(of: row)
            return NewsletterRecipient(
                id: id,
                email: attrs["email"] as? String ?? "Unknown",
                status: attrs["status"] as? String ?? "notSet",
                createdAt: date(from: attrs["createdAt"] as? String)
            )
        }
    }

    func setMaintenance(salesChannelID: String, enabled: Bool) async throws {
        _ = try await requestJSON(path: "/api/sales-channel/\(salesChannelID)", method: "PATCH", body: [
            "maintenance": enabled
        ])
    }

    func fetchOrderLineItems(orderID: String) async throws -> [OrderLineItem] {
        let response = try await requestJSON(path: "/api/search/order-line-item", method: "POST", body: [
            "limit": 100,
            "filter": [["type": "equals", "field": "orderId", "value": orderID]],
            "sort": [["field": "position", "order": "ASC"]]
        ])
        return (response["data"] as? [[String: Any]] ?? []).compactMap { row in
            guard let id = row["id"] as? String else { return nil }
            let attrs = entityAttributes(of: row)
            return OrderLineItem(
                id: id,
                label: attrs["label"] as? String ?? "Item",
                quantity: attrs["quantity"] as? Int ?? 0,
                totalPrice: decimal(from: attrs["totalPrice"])
            )
        }
    }

    func fetchOrderCustomer(orderID: String) async throws -> (name: String, email: String)? {
        let response = try await requestJSON(path: "/api/search/order-customer", method: "POST", body: [
            "limit": 1,
            "filter": [["type": "equals", "field": "orderId", "value": orderID]]
        ])
        guard let row = (response["data"] as? [[String: Any]])?.first else { return nil }
        let attrs = entityAttributes(of: row)
        let first = attrs["firstName"] as? String ?? ""
        let last = attrs["lastName"] as? String ?? ""
        return (name: "\(first) \(last)".trimmingCharacters(in: .whitespaces),
                email: attrs["email"] as? String ?? "")
    }

    // entityName: "order", "order_transaction" or "order_delivery"
    func fetchStateTransitions(entityName: String, entityID: String) async throws -> [OrderTransition] {
        let response = try await requestJSON(path: "/api/_action/state-machine/\(entityName)/\(entityID)/state", method: "GET")
        return (response["transitions"] as? [[String: Any]] ?? []).compactMap { transition in
            guard let action = transition["actionName"] as? String else { return nil }
            let toState = transition["toStateMachineState"] as? [String: Any]
            let name = (toState?["translated"] as? [String: Any])?["name"] as? String
                ?? toState?["name"] as? String
                ?? action.capitalized
            return OrderTransition(actionName: action, displayName: name)
        }
    }

    func performStateTransition(entityName: String, entityID: String, action: String) async throws {
        _ = try await requestJSON(path: "/api/_action/state-machine/\(entityName)/\(entityID)/state/\(action)", method: "POST")
    }

    // Returns the newest transaction/delivery of an order with its current state name
    func fetchOrderSubEntity(_ entity: String, orderID: String) async throws -> (id: String, state: String)? {
        let response = try await requestJSON(path: "/api/search/\(entity)", method: "POST", body: [
            "limit": 1,
            "filter": [["type": "equals", "field": "orderId", "value": orderID]],
            "sort": [["field": "createdAt", "order": "DESC"]],
            "associations": ["stateMachineState": [:]]
        ])
        guard let row = (response["data"] as? [[String: Any]])?.first,
              let id = row["id"] as? String else { return nil }
        let attrs = entityAttributes(of: row)
        let included = response["included"] as? [[String: Any]] ?? []
        let includedByID = Dictionary(uniqueKeysWithValues: included.compactMap { item -> (String, [String: Any])? in
            guard let itemID = item["id"] as? String else { return nil }
            return (itemID, item)
        })
        let relationships = row["relationships"] as? [String: Any] ?? [:]
        let stateID = relationshipID(from: relationships["stateMachineState"])
        let stateAttrs = includedByID[stateID ?? ""]?["attributes"] as? [String: Any]
        return (id: id, state: orderState(from: attrs, includedState: stateAttrs))
    }

    func fetchLowStockProducts(threshold: Int = 10, salesChannelID: String?) async throws -> [LowStockProduct] {
        var filters: [[String: Any]] = [
            ["type": "range", "field": "stock", "parameters": ["lte": threshold]],
            ["type": "equals", "field": "active", "value": true]
        ]
        if let salesChannelID {
            filters.append(["type": "equals", "field": "visibilities.salesChannelId", "value": salesChannelID])
        }
        let response = try await requestJSON(path: "/api/search/product", method: "POST", body: [
            "limit": 10,
            "filter": filters,
            "sort": [["field": "stock", "order": "ASC"]]
        ])
        return (response["data"] as? [[String: Any]] ?? []).compactMap { row in
            guard let id = row["id"] as? String else { return nil }
            let attrs = entityAttributes(of: row)
            let name = translatedName(from: attrs) ?? attrs["name"] as? String ?? "Unnamed product"
            return LowStockProduct(id: id, name: name, stock: attrs["stock"] as? Int ?? 0)
        }
    }

    func fetchTopProducts(since: Date, salesChannelID: String?) async throws -> [TopProduct] {
        var filters: [[String: Any]] = [
            ["type": "range", "field": "order.orderDateTime", "parameters": ["gte": since.iso8601String]],
            ["type": "equals", "field": "type", "value": "product"]
        ]
        if let salesChannelID {
            filters.append(["type": "equals", "field": "order.salesChannelId", "value": salesChannelID])
        }
        let response = try await requestJSON(path: "/api/search/order-line-item", method: "POST", body: [
            "limit": 1,
            "includes": ["order_line_item": ["id"]],
            "filter": filters,
            "aggregations": [[
                "name": "top_products",
                "type": "terms",
                "field": "label",
                "limit": 50,
                "aggregation": ["name": "qty", "type": "sum", "field": "quantity"]
            ]]
        ])
        guard let aggregations = response["aggregations"] as? [String: Any],
              let terms = aggregations["top_products"] as? [String: Any],
              let buckets = terms["buckets"] as? [[String: Any]] else {
            return []
        }
        return buckets.compactMap { bucket -> TopProduct? in
            guard let label = bucket["key"] as? String else { return nil }
            let qty = ((bucket["qty"] as? [String: Any])?["sum"] as? NSNumber)?.intValue ?? bucket["count"] as? Int ?? 0
            return TopProduct(label: label, quantitySold: qty)
        }
        .sorted { $0.quantitySold > $1.quantitySold }
        .prefix(5)
        .map { $0 }
    }

    // Uses a histogram aggregation on the order search instead of the
    // /_admin/dashboard endpoint, because that endpoint cannot filter by sales channel.
    func fetchHistory(paid: Bool, range: DateRange, salesChannelID: String?) async throws -> [DashboardBucket] {
        var filters: [[String: Any]] = [[
            "type": "range",
            "field": "orderDateTime",
            "parameters": ["gte": range.sinceDate.iso8601String]
        ]]
        if let salesChannelID {
            filters.append(["type": "equals", "field": "salesChannelId", "value": salesChannelID])
        }
        if paid {
            filters.append(["type": "equals", "field": "transactions.stateMachineState.technicalName", "value": "paid"])
        }

        let response = try await requestJSON(path: "/api/search/order", method: "POST", body: [
            "limit": 1,
            "includes": ["order": ["id"]],
            "filter": filters,
            "aggregations": [[
                "name": "order_histogram",
                "type": "histogram",
                "field": "orderDateTime",
                "interval": range.histogramInterval,
                "aggregation": ["name": "amount_sum", "type": "sum", "field": "amountTotal"]
            ]]
        ])

        guard let aggregations = response["aggregations"] as? [String: Any],
              let histogram = aggregations["order_histogram"] as? [String: Any],
              let buckets = histogram["buckets"] as? [[String: Any]] else {
            return []
        }

        return buckets.compactMap { bucket -> DashboardBucket? in
            guard let key = bucket["key"] as? String, let date = parseHistogramDate(key) else { return nil }
            let count = bucket["count"] as? Int ?? 0
            let amount = ((bucket["amount_sum"] as? [String: Any])?["sum"] as? NSNumber)?.doubleValue ?? 0
            return DashboardBucket(date: date, count: count, amount: amount)
        }
        .sorted { $0.date < $1.date }
    }

    private func countEntity(_ entity: String, filters: [[String: Any]] = []) async throws -> Int {
        let response = try await searchEntity(entity, body: ["limit": 1, "filter": filters, "total-count-mode": 1])
        if let meta = response["meta"] as? [String: Any], let total = meta["total"] as? Int { return total }
        if let total = response["total"] as? Int { return total }
        return (response["data"] as? [[String: Any]])?.count ?? 0
    }

    private func searchOrders(_ body: [String: Any]) async throws -> [LatestOrder] {
        let response = try await searchEntity("order", body: body)
        let included = response["included"] as? [[String: Any]] ?? []
        let includedByID = Dictionary(uniqueKeysWithValues: included.compactMap { item -> (String, [String: Any])? in
            guard let id = item["id"] as? String else { return nil }
            return (id, item)
        })
        return (response["data"] as? [[String: Any]] ?? []).compactMap { row in
            guard let id = row["id"] as? String else { return nil }
            let attributes = entityAttributes(of: row)
            let relationships = row["relationships"] as? [String: Any] ?? [:]
            let currencyID = relationshipID(from: relationships["currency"])
            let stateID = relationshipID(from: relationships["stateMachineState"])
            let currencyAttributes = includedByID[currencyID ?? ""]?["attributes"] as? [String: Any]
            let stateAttributes = includedByID[stateID ?? ""]?["attributes"] as? [String: Any]
            return LatestOrder(
                id: id,
                orderNumber: attributes["orderNumber"] as? String ?? "Unknown",
                amountTotal: decimal(from: attributes["amountTotal"]),
                orderDateTime: date(from: attributes["orderDateTime"] as? String),
                currencyCode: (attributes["currency"] as? [String: Any])?["isoCode"] as? String ?? currencyAttributes?["isoCode"] as? String ?? "EUR",
                state: orderState(from: attributes, includedState: stateAttributes)
            )
        }
    }

    private func searchEntity(_ entity: String, body: [String: Any]) async throws -> [String: Any] {
        try await requestJSON(path: "/api/search/\(entity)", method: "POST", body: body)
    }

    private func requestJSON(path: String, method: String, body: [String: Any]? = nil, queryItems: [URLQueryItem]? = nil, attempt: Int = 0) async throws -> [String: Any] {
        let accessToken = try await accessToken()
        var url = connection.normalizedBaseURL.appending(path: path)
        if let queryItems,
           var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            components.queryItems = queryItems
            url = components.url ?? url
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        if let body { request.httpBody = try JSONSerialization.data(withJSONObject: body) }

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0

        if status == 401 && attempt == 0 {
            token = nil
            return try await requestJSON(path: path, method: method, body: body, queryItems: queryItems, attempt: 1)
        }

        if [408, 429, 500, 502, 503, 504].contains(status), attempt < 2 {
            try await Task.sleep(for: .milliseconds(500 * (attempt + 1)))
            return try await requestJSON(path: path, method: method, body: body, queryItems: queryItems, attempt: attempt + 1)
        }

        return try parseJSONResponse(data: data, status: status)
    }

    private func accessToken() async throws -> String {
        if let token, token.expiresAt > Date().addingTimeInterval(30) { return token.value }

        var request = URLRequest(url: connection.normalizedBaseURL.appending(path: "/api/oauth/token"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "grant_type": "client_credentials",
            "client_id": connection.accessKey.trimmingCharacters(in: .whitespacesAndNewlines),
            "client_secret": connection.secretKey
        ])

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let json = try parseJSONResponse(data: data, status: status)

        guard let value = json["access_token"] as? String else {
            throw ShopwareAPIError.message("Shopware did not return an access token.")
        }

        let expiresIn = json["expires_in"] as? TimeInterval ?? 600
        token = AccessToken(value: value, expiresAt: Date().addingTimeInterval(expiresIn))
        return value
    }

    private func parseJSONResponse(data: Data, status: Int) throws -> [String: Any] {
        let payload: Any = data.isEmpty ? [:] : (try JSONSerialization.jsonObject(with: data))
        if !(200...299).contains(status) {
            throw ShopwareAPIError.message(errorMessage(from: payload, status: status))
        }
        return payload as? [String: Any] ?? [:]
    }
}

// MARK: - Keychain

struct AccessToken {
    var value: String
    var expiresAt: Date
}

final class CredentialStore {
    private let service = "com.opensource.shopwareapp.connection"
    private let account = "shopware-admin-api"

    func load() throws -> ShopwareConnection? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            throw ShopwareAPIError.message("Could not read saved credentials from Keychain.")
        }
        return try JSONDecoder().decode(ShopwareConnection.self, from: data)
    }

    func save(_ connection: ShopwareConnection) throws {
        let data = try JSONEncoder().encode(connection)
        try clear()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        guard SecItemAdd(query as CFDictionary, nil) == errSecSuccess else {
            throw ShopwareAPIError.message("Could not save credentials to Keychain.")
        }
    }

    func clear() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        let acceptable: [OSStatus] = [errSecSuccess, errSecItemNotFound, -25308]
        guard acceptable.contains(status) else {
            throw ShopwareAPIError.message("Could not clear credentials from Keychain.")
        }
    }
}

// MARK: - Errors & helpers

enum ShopwareAPIError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        if case .message(let m) = self { return m }
        return nil
    }
}

extension Error {
    var shopwareDisplayMessage: String {
        (self as? LocalizedError)?.errorDescription ?? localizedDescription
    }
}

private func errorMessage(from payload: Any, status: Int) -> String {
    guard let json = payload as? [String: Any],
          let errors = json["errors"] as? [[String: Any]],
          let first = errors.first else {
        return "Shopware request failed with status \(status)."
    }
    return first["detail"] as? String ?? first["title"] as? String ?? "Shopware request failed with status \(status)."
}

// Admin API rows are JSON:API ({"attributes": {...}}) or plain JSON depending on Accept handling
private func entityAttributes(of row: [String: Any]) -> [String: Any] {
    row["attributes"] as? [String: Any] ?? row
}

private func relationshipID(from relationship: Any?) -> String? {
    guard let rel = relationship as? [String: Any], let data = rel["data"] as? [String: Any] else { return nil }
    return data["id"] as? String
}

private func orderState(from attributes: [String: Any], includedState: [String: Any]?) -> String {
    if let embedded = attributes["stateMachineState"] as? [String: Any] {
        return translatedName(from: embedded) ?? embedded["technicalName"] as? String ?? "Unknown"
    }
    return includedState.flatMap(translatedName) ?? includedState?["technicalName"] as? String ?? "Unknown"
}

private func translatedName(from attributes: [String: Any]) -> String? {
    (attributes["translated"] as? [String: Any])?["name"] as? String
}

private func decimal(from value: Any?) -> Decimal {
    if let d = value as? Decimal { return d }
    if let n = value as? NSNumber { return n.decimalValue }
    if let s = value as? String { return Decimal(string: s) ?? 0 }
    return 0
}

private func date(from value: String?) -> Date? {
    guard let value else { return nil }
    return ISO8601DateFormatter.shopware.date(from: value)
}

// Histogram bucket keys come in plain formats like "2026-06-01" or "2026-06-01 10:00"
private func parseHistogramDate(_ key: String) -> Date? {
    for format in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm", "yyyy-MM-dd", "yyyy-MM"] {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        if let date = formatter.date(from: key) { return date }
    }
    return ISO8601DateFormatter.shopware.date(from: key) ?? ISO8601DateFormatter.shopwareDate.date(from: key)
}

// MARK: - Extensions

extension Date {
    var iso8601String: String { ISO8601DateFormatter.shopware.string(from: self) }
}

extension ISO8601DateFormatter {
    static let shopware: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static let shopwareDate: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        return f
    }()
}

// Palette matching the Shopware 6 administration (Meteor design system)
extension Color {
    static let appBackground = Color(red: 0.94, green: 0.95, blue: 0.96)  // #F0F2F5 admin background
    static let border        = Color(red: 0.82, green: 0.85, blue: 0.88)  // #D1D9E0 card borders
    static let primaryText   = Color(red: 0.08, green: 0.13, blue: 0.18)  // #14202E headlines
    static let secondaryText = Color(red: 0.32, green: 0.40, blue: 0.48)  // #52667A muted text
    static let shopwareBlue  = Color(red: 0.03, green: 0.44, blue: 1.0)   // #0870FF primary actions
    static let swNavy        = Color(red: 0.10, green: 0.14, blue: 0.20)  // admin sidebar navy
    static let amber         = Color(red: 0.72, green: 0.45, blue: 0.05)  // warning
    static let blue          = Color(red: 0.42, green: 0.27, blue: 0.76)  // violet accent
    static let red           = Color(red: 0.87, green: 0.16, blue: 0.30)  // #DE294C error
}

#Preview { ContentView() }
