//
//  Created by Yang Xu on 2020/8/6.
//

import Foundation
import SwiftUI

extension SwipeCellModifier {

    func body(content: Content) -> some View {
        if editMode?.wrappedValue == .active { dismissNotification() }

        return ZStack(alignment: .topLeading) {
            Color.clear.zIndex(0)
            ZStack {

                //加载左侧按钮
                GeometryReader { proxy in
                    ZStack {
                        if let lbs = leftSlot {
                            loadButtons(lbs, position: .left, frame: proxy.frame(in: .local))

                        }
                    }
                }.zIndex(1)
                //加载右侧按钮
                GeometryReader { proxy in
                    ZStack {
                        if let rbs = rightSlot {
                            loadButtons(rbs, position: .right, frame: proxy.frame(in: .local))
                        }
                    }
                }.zIndex(2)

                //加载Cell内容
                ZStack(alignment: swipeCellStyle.alignment) {
                    Color.clear
                    content
                        .environment(\.cellStatus, status)
                }
                .zIndex(3)
                .highPriorityGesture(
                    TapGesture(count: 1),
                    including: currentCellID == nil ? .subviews : .none
                )
                .contentShape(Rectangle())
                //解决Button冲突问题.
                .onTapGesture(
                    count: currentCellID != nil ? 1 : 4,
                    perform: {
                        resetStatus()
                        dismissNotification()
                    }
                )
                .offset(x: offset)
            }
        }
        .contentShape(Rectangle())
        .gesture(getGesture())
        .ifIs(clip) {
            $0.clipShape(Rectangle())
        }
        .onChange(of: status){ status in
            switch status {
            case .showLeftSlot:
                leftSlot?.showAction?()
            case .showRightSlot:
                rightSlot?.showAction?()
            case .showCell:
                break
            }
        }
        .onChange(of: offset) {value in
            leftSlot?.offsetAction?(cellID, Float(offset))
            rightSlot?.offsetAction?(cellID, Float(offset))
        }
        .onReceive(resetNotice) { notice in
            //            if status == .showCell {return}
            //如果其他的cell发送通知或者list发送通知,则本cell复位
            if cellID != notice.object as? UUID {
                resetStatus()
                currentCellID = notice.object as? UUID ?? nil
            }

        }
        .onReceive(timer) { _ in
            resetStatus()
        }
        .ifIs(
            (leftSlot?.slots.count == 1 && leftSlot?.slotStyle == .destructive)
                || (rightSlot?.slots.count == 1 && rightSlot?.slotStyle == .destructive)
        ) {
            $0.onChange(of: offset) { offset in
                //当前向右
                if offset > 0 && leftSlot?.slots.count == 1 && leftSlot?.slotStyle == .destructive {
                    guard let leftSlot = leftSlot else { return }
                    if leftSlot.slotStyle == .destructive && leftSlot.slots.count == 1 {
                        if feedStatus == .feedOnce {
                            withAnimation(.easeInOut) {
                                spaceWidth = offset - leftSlot.buttonWidth
                            }
                        }
                        if feedStatus == .feedAgain {
                            withAnimation(.easeInOut) {
                                spaceWidth = 0
                            }
                        }
                    }
                }
                //当前向左
                if offset < 0 && rightSlot?.slots.count == 1 && rightSlot?.slotStyle == .destructive
                {
                    guard let rightSlot = rightSlot else { return }
                    if rightSlot.slotStyle == .destructive && rightSlot.slots.count == 1 {
                        if feedStatus == .feedOnce {
                            withAnimation(.easeInOut) {
                                spaceWidth = -(abs(offset) - rightSlot.buttonWidth)
                            }
                        }
                        if feedStatus == .feedAgain {
                            withAnimation(.easeInOut) {
                                spaceWidth = 0
                            }
                        }
                    }
                }
            }
        }
        .listRowInsets(EdgeInsets())

    }

    func setStatus(_ position: CellStatus) {
        status = position
        guard let time = swipeCellStyle.autoResetTime else { return }
        timer = Timer.publish(every: time, on: .main, in: .common)
        timer.connect().store(in: &cancellables)
    }

    func resetStatus() {
        status = .showCell
        withAnimation(.easeInOut) {
            offset = 0
            leftOffset = -frameWidth
            rightOffset = frameWidth
            spaceWidth = 0
            showDalayButtonWith = 0
        }
        feedStatus = .none
        cancellables.removeAll()
        currentCellID = nil

    }

    func successFeedBack(_ type: Vibration) {
        #if os(iOS)
            type.vibrate()
        #endif
    }

    func dismissNotification() {
        NotificationCenter.default.post(name: .swipeCellReset, object: nil)
    }

}
