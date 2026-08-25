# 优化聊天对话界面 (ChatConversationView)

主要目标是修复滚动逻辑冲突、移除 `build` 方法中的副作用（如自动标记已读），并提升交互体验。

## Proposed Changes

### [Component] UI 与 交互优化

#### [MODIFY] [chat_conversation_view.dart](file:///C:/Users/ahbla/OneDrive/Documents/GitHub/soul_finder/lib/views/chat_conversation_view.dart)
- **状态管理优化**：
    - 在 `initState` 中初始化消息 `Stream` 并添加监听器。
    - 将“标记已读”和“自动滚动”逻辑从 `build` 移至 `Stream` 监听器中。
- **滚动体验优化**：
    - 改进 `_scrollToBottom` 逻辑：仅在用户发送消息，或接收新消息且当前处于底部时自动滚动。
    - 为 `ListView` 添加 `keyboardDismissBehavior: onDrag`，提升移动端操作感。
- **健壮性优化**：
    - 确保所有约会建议（Structured Proposal）的交互按钮都遵循 `_isSending` 状态，防止连击。
    - 移除 `build` 块中重复的 `_scrollToBottom()` 调用。

#### [MODIFY] [meet_soul_view.dart](file:///C:/Users/ahbla/OneDrive/Documents/GitHub/soul_finder/lib/views/meet_soul_view.dart) (可选/建议)
- **代码一致性**：将手动拼凑文本发送建议的方式，改为调用 `_chatService.sendMeetingProposal`（结构化消息），以统一数据格式。

## Verification Plan

### Manual Verification
- **滚动测试**：
    1. 打开聊天窗口，向上滚动查看历史记录。
    2. 让另一端发送一条消息。
    3. 验证：屏幕不应强制滚动到底部（除非我本身就在底部）。
    4. 自己发送一条消息。
    5. 验证：屏幕立即平滑滚动到底部。
- **交互测试**：
    1. 点击“接受”建议，在网络请求期间验证按钮变为不可用或显示加载状态。
- **键盘测试**：
    1. 弹出键盘，向下拖拽列表。
    2. 验证：键盘随之收起。
