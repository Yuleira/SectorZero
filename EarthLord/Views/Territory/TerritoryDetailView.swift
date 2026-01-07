//
//  TerritoryDetailView.swift
//  EarthLord
//
//  Created by Claude on 07/01/2026.
//
//  领地详情页
//  显示领地信息、地图预览、删除功能和未来功能占位

import SwiftUI
import MapKit
import CoreLocation

struct TerritoryDetailView: View {

    // MARK: - 属性

    /// 领地数据
    let territory: Territory

    /// 删除回调
    var onDelete: (() -> Void)?

    /// 环境变量
    @Environment(\.dismiss) private var dismiss

    /// 领地管理器
    @ObservedObject private var territoryManager = TerritoryManager.shared

    /// 是否显示删除确认
    @State private var showDeleteAlert = false

    /// 是否正在删除
    @State private var isDeleting = false

    /// 地图相机位置
    @State private var cameraPosition: MapCameraPosition = .automatic

    // MARK: - 计算属性

    /// 领地坐标
    private var coordinates: [CLLocationCoordinate2D] {
        territory.toCoordinates()
    }

    /// 领地中心点
    private var centerCoordinate: CLLocationCoordinate2D? {
        guard !coordinates.isEmpty else { return nil }
        let totalLat = coordinates.reduce(0) { $0 + $1.latitude }
        let totalLon = coordinates.reduce(0) { $0 + $1.longitude }
        return CLLocationCoordinate2D(
            latitude: totalLat / Double(coordinates.count),
            longitude: totalLon / Double(coordinates.count)
        )
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景色
                ApocalypseTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // 地图预览
                        mapPreview
                            .padding(.horizontal)

                        // 领地信息卡片
                        infoCard
                            .padding(.horizontal)

                        // 未来功能占位
                        futureFeatures
                            .padding(.horizontal)

                        // 删除按钮
                        deleteButton
                            .padding(.horizontal)
                            .padding(.top, 20)

                        // 底部间距
                        Spacer()
                            .frame(height: 40)
                    }
                    .padding(.top)
                }
            }
            .navigationTitle(territory.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
            .alert("确认删除", isPresented: $showDeleteAlert) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    Task {
                        await deleteTerritory()
                    }
                }
            } message: {
                Text("删除后无法恢复，确定要删除这块领地吗？")
            }
        }
    }

    // MARK: - 子视图

    /// 地图预览
    private var mapPreview: some View {
        ZStack {
            if coordinates.count >= 3 {
                Map(position: $cameraPosition) {
                    // 绘制多边形
                    MapPolygon(coordinates: coordinates)
                        .foregroundStyle(ApocalypseTheme.primary.opacity(0.3))
                        .stroke(ApocalypseTheme.primary, lineWidth: 2)
                }
                .mapStyle(.standard)
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .onAppear {
                    setupCamera()
                }
            } else {
                // 坐标不足时显示占位
                RoundedRectangle(cornerRadius: 12)
                    .fill(ApocalypseTheme.cardBackground)
                    .frame(height: 200)
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "map")
                                .font(.system(size: 40))
                                .foregroundColor(ApocalypseTheme.textMuted)
                            Text("无法显示地图")
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        }
                    }
            }
        }
    }

    /// 领地信息卡片
    private var infoCard: some View {
        VStack(spacing: 0) {
            // 面积
            infoRow(icon: "square.dashed", title: "面积", value: territory.formattedArea)

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 点数
            infoRow(
                icon: "mappin.circle",
                title: "轨迹点数",
                value: territory.pointCount != nil ? "\(territory.pointCount!) 个" : "-"
            )

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 完成时间
            infoRow(
                icon: "clock",
                title: "圈地时间",
                value: territory.formattedCompletedAt ?? "-"
            )
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    /// 信息行
    private func infoRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(ApocalypseTheme.primary)
                .frame(width: 24)

            Text(title)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
        .padding()
    }

    /// 未来功能占位
    private var futureFeatures: some View {
        VStack(spacing: 0) {
            // 标题
            HStack {
                Text("更多功能")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                Spacer()
            }
            .padding(.bottom, 12)

            // 功能列表
            VStack(spacing: 0) {
                futureFeatureRow(icon: "pencil", title: "重命名领地")

                Divider()
                    .background(ApocalypseTheme.textMuted.opacity(0.3))

                futureFeatureRow(icon: "building.2", title: "建筑系统")

                Divider()
                    .background(ApocalypseTheme.textMuted.opacity(0.3))

                futureFeatureRow(icon: "arrow.left.arrow.right", title: "领地交易")
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ApocalypseTheme.cardBackground)
            )
        }
    }

    /// 未来功能行
    private func futureFeatureRow(icon: String, title: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(ApocalypseTheme.textMuted)
                .frame(width: 24)

            Text(title)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()

            Text("敬请期待")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textMuted)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(ApocalypseTheme.textMuted.opacity(0.2))
                )
        }
        .padding()
    }

    /// 删除按钮
    private var deleteButton: some View {
        Button {
            showDeleteAlert = true
        } label: {
            HStack {
                if isDeleting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "trash")
                }
                Text("删除领地")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.red)
            )
        }
        .disabled(isDeleting)
        .opacity(isDeleting ? 0.7 : 1.0)
    }

    // MARK: - 方法

    /// 设置地图相机
    private func setupCamera() {
        guard let center = centerCoordinate else { return }

        // 计算边界以确定合适的缩放级别
        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude

        for coord in coordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        let latDelta = (maxLat - minLat) * 1.5 + 0.002
        let lonDelta = (maxLon - minLon) * 1.5 + 0.002

        let region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        )

        cameraPosition = .region(region)
    }

    /// 删除领地
    private func deleteTerritory() async {
        isDeleting = true
        defer { isDeleting = false }

        let success = await territoryManager.deleteTerritory(territoryId: territory.id)

        if success {
            onDelete?()
            dismiss()
        }
    }
}

#Preview {
    TerritoryDetailView(
        territory: Territory(
            id: "test-id",
            userId: "user-id",
            name: "测试领地",
            path: [
                ["lat": 31.2304, "lon": 121.4737],
                ["lat": 31.2314, "lon": 121.4747],
                ["lat": 31.2324, "lon": 121.4737],
                ["lat": 31.2314, "lon": 121.4727]
            ],
            area: 1500,
            pointCount: 15,
            isActive: true,
            completedAt: "2026-01-07T10:30:00Z",
            startedAt: "2026-01-07T10:25:00Z",
            createdAt: "2026-01-07T10:30:00Z"
        )
    )
}
