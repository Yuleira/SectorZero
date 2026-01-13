//
//  POIProximityPopup.swift
//  EarthLord
//
//  POI接近提示弹窗
//  当玩家走到POI附近时显示搜刮提示
//

import SwiftUI
import CoreLocation

/// POI接近提示弹窗
struct POIProximityPopup: View {

    // MARK: - 属性

    /// 当前POI
    let poi: NearbyPOI

    /// 到POI的距离
    let distance: Double

    /// 搜刮回调
    let onScavenge: () -> Void

    /// 关闭回调
    let onDismiss: () -> Void

    // MARK: - 视图

    var body: some View {
        VStack(spacing: 0) {
            // 顶部装饰条
            Rectangle()
                .fill(ApocalypseTheme.primary)
                .frame(height: 4)

            VStack(spacing: 16) {
                // POI图标和名称
                HStack(spacing: 12) {
                    // 图标
                    ZStack {
                        Circle()
                            .fill(poiBackgroundColor)
                            .frame(width: 56, height: 56)

                        Image(systemName: poi.type.icon)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    // 信息
                    VStack(alignment: .leading, spacing: 4) {
                        Text("发现废墟")
                            .font(.system(size: 13))
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        Text(poi.name)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(ApocalypseTheme.textPrimary)
                            .lineLimit(1)

                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 11))
                            Text("\(String(format: "%.0f", distance))米")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(ApocalypseTheme.textMuted)
                    }

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                // 分隔线
                Rectangle()
                    .fill(ApocalypseTheme.cardBackground)
                    .frame(height: 1)
                    .padding(.horizontal, 20)

                // POI类型标签
                HStack {
                    Label(poi.type.rawValue, systemImage: poi.type.icon)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(poiBackgroundColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(poiBackgroundColor.opacity(0.15))
                        )

                    Spacer()

                    // 提示文字
                    Text("可搜刮物资")
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
                .padding(.horizontal, 20)

                // 按钮区域
                HStack(spacing: 12) {
                    // 稍后再说按钮
                    Button(action: onDismiss) {
                        Text("稍后再说")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(ApocalypseTheme.cardBackground)
                            )
                    }

                    // 立即搜刮按钮
                    Button(action: onScavenge) {
                        HStack(spacing: 8) {
                            Image(systemName: "hand.point.up.left.fill")
                                .font(.system(size: 14))
                            Text("立即搜刮")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(ApocalypseTheme.primary)
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(ApocalypseTheme.background)
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: -5)
        )
    }

    // MARK: - 计算属性

    /// POI背景颜色
    private var poiBackgroundColor: Color {
        switch poi.type {
        case .store, .supermarket, .convenience:
            return .blue
        case .hospital:
            return .red
        case .pharmacy:
            return .green
        case .gasStation:
            return .orange
        case .restaurant:
            return .purple
        case .cafe:
            return .brown
        }
    }
}

// MARK: - 预览

#Preview {
    ZStack {
        ApocalypseTheme.background
            .ignoresSafeArea()

        VStack {
            Spacer()
            POIProximityPopup(
                poi: NearbyPOI(
                    id: "test",
                    name: "全家便利店",
                    type: .convenience,
                    coordinate: .init(latitude: 0, longitude: 0)
                ),
                distance: 32,
                onScavenge: {},
                onDismiss: {}
            )
        }
    }
}
