# AppFlowy 二次开发需求分析 - TODO

## 🔍 yuni2 分支改动分析

基于对 `yuni2` 分支相对于 `main` 分支的分析，以下是该分支实现的主要功能：

### 📋 功能概述

yuni2 分支主要实现了两个核心功能：
1. **文档同步状态显示** - 在文档页面显示最后同步时间
2. **文档变更报告系统** - 允许用户报告文档修改并通知团队成员

### 📁 涉及文件

1. `frontend/appflowy_flutter/lib/plugins/document/application/document_bloc.dart`
2. `frontend/appflowy_flutter/lib/plugins/document/document_page.dart`
3. `frontend/appflowy_flutter/lib/startup/tasks/appflowy_cloud_task.dart`
4. `frontend/appflowy_flutter/lib/startup/tasks/deeplink/page_view_deeplink_handler.dart` (新增)

### 🔧 具体改动详情

#### 1. 文档同步状态跟踪 (document_bloc.dart)
- **改动**: 在 `DocumentState` 中新增 `lastSyncTime` 字段
- **功能**: 记录文档最后一次同步完成的时间
- **实现**: 当同步状态变为 `SyncFinished` 时，更新 `lastSyncTime` 为当前时间

```dart
// 新增字段
DateTime? lastSyncTime,

// 同步状态变更时的处理
if (syncState.value == DocumentSyncState.SyncFinished) {
  lastSyncTime = DateTime.now();
}
```

#### 2. 页面深度链接处理器 (page_view_deeplink_handler.dart)
- **功能**: 处理 `appflowy-flutter://page-view?workspace_id={}&view_id={}` 格式的深度链接
- **目的**: 支持通过链接直接打开特定文档页面
- **平台适配**: 区分移动端和桌面端的导航方式

#### 3. 深度链接集成 (appflowy_cloud_task.dart)
- **改动**: 注册 `PageViewDeepLinkHandler` 到深度链接系统
- **功能**: 当深度链接导航失败时显示错误提示

#### 4. 文档变更报告系统 (document_page.dart)
这是最大的功能改动，包含：

##### A. 同步状态显示界面
- 在文档封面下方显示同步时间信息
- 时间格式：刚刚/分钟前/小时前/天前 等人性化显示
- 显示同步状态：正在同步/尚未同步/同步成功

##### B. "Report Changes" 按钮
- 位置：文档右上角
- 样式：蓝色 ElevatedButton
- 功能：打开变更报告对话框

##### C. 变更报告对话框
包含以下元素：
- **变更描述输入框**: 多行文本输入，用于描述修改内容
- **团队成员选择**: 
  - 获取当前工作区的所有成员
  - 支持多选成员进行通知
  - 显示成员姓名和邮箱
  - 已选成员以 Chip 形式展示
- **提交功能**: 发送变更通知到微信群

##### D. 微信群通知集成
- **Webhook URL**: 硬编码的企业微信群机器人地址
- **消息格式**: Markdown 格式
- **消息内容**:
  - 文档标题
  - 修改时间 (yyyy-MM-dd HH:mm:ss)
  - 修改者姓名
  - APP 链接 (appflowy-flutter://)
  - WEB 链接 (https://docs.uneedx.com/)
  - 修改内容描述
  - 需要通知的人员列表

##### E. 技术实现细节
- 使用 `http` 包发送 POST 请求
- 错误处理：捕获异常并显示 SnackBar
- 日志记录：详细的调试日志
- 异步处理：使用 async/await

### 🎯 核心业务逻辑

1. **同步状态管理**: 实时跟踪文档同步状态，记录同步时间
2. **团队协作**: 通过变更报告功能促进团队沟通
3. **多平台链接**: 支持 APP 和 WEB 两种访问方式
4. **即时通知**: 通过企业微信实现实时团队通知

### 📊 数据流

```
用户修改文档 → 触发同步 → 更新同步时间 → 用户点击Report Changes → 
选择通知人员 → 填写变更描述 → 发送微信通知 → 团队成员接收通知 → 
点击链接跳转到文档
```

### 🔍 待确认的用户自定义需求

用户提到"现在我的需求会有一点不同"，需要了解：

1. **微信 Webhook**: 是否需要更换企业微信群地址？
2. **消息格式**: 是否需要调整通知消息的内容或格式？
3. **WEB 链接域名**: 是否需要更改 `docs.uneedx.com` 为其他域名？
4. **界面调整**: 是否需要修改按钮位置、样式或文案？
5. **功能扩展**: 是否需要新增其他功能或移除某些功能？
6. **团队成员获取**: 是否需要调整成员获取逻辑？

## ✅ 实现完成状态

基于用户需求，已完成以下功能实现：

### 🎯 用户自定义需求
1. ❌ **同步状态跟踪**: 不需要实现（新版本已有此功能）
2. ✅ **按钮位置调整**: 将 notify 按钮放在 share 按钮旁边（而非文档内容区域）
3. ✅ **微信群地址**: 继续使用硬编码的企业微信 webhook URL
4. ✅ **消息格式**: 保持原有的 Markdown 格式不变

### 📁 已实现的文件

#### 新增文件
1. **`lib/plugins/shared/notify/notify_button.dart`**
   - Notify 按钮组件
   - 使用 notification 图标
   - 集成到文档页面的 rightBarItem 中

2. **`lib/plugins/shared/notify/notify_dialog.dart`**
   - 完整的通知对话框实现
   - 工作区成员选择功能
   - 企业微信消息发送功能
   - 移植自 yuni2 分支的核心逻辑

3. **`lib/startup/tasks/deeplink/page_view_deeplink_handler.dart`**
   - 深度链接处理器
   - 支持 `appflowy-flutter://page-view?workspace_id={}&view_id={}` 格式
   - 跨平台导航支持

#### 修改文件
1. **`lib/plugins/document/document.dart`**
   - 在 rightBarItem 的 ShareButton 旁边添加 NotifyButton
   - 调整按钮间距布局

2. **`lib/startup/tasks/appflowy_cloud_task.dart`**
   - 注册 PageViewDeepLinkHandler
   - 添加深度链接错误处理

### 🔧 核心功能

#### Notify 按钮功能
- **位置**: 文档页面右上角，在 Share 按钮和 Favorite 按钮之间
- **图标**: 使用 `FlowySvgs.notification_s` 通知图标
- **交互**: 点击打开通知对话框

#### 通知对话框功能
- **变更描述**: 多行文本输入框，描述文档修改内容
- **成员选择**: 
  - 自动获取当前工作区的所有成员
  - 支持多选通知对象
  - 显示成员姓名和邮箱
  - 已选成员以 Chip 形式展示
- **消息发送**: 
  - 通过企业微信 webhook 发送 Markdown 格式消息
  - 包含文档标题、修改时间、修改者、链接等信息

#### 深度链接支持
- **APP 链接**: `appflowy-flutter://page-view?workspace_id={}&view_id={}`
- **WEB 链接**: `https://docs.uneedx.com/app/{workspace_id}/{view_id}`
- **平台适配**: 区分移动端和桌面端的导航处理

### 🧪 代码质量
- ✅ Flutter analyze 无警告错误
- ✅ 遵循项目代码规范
- ✅ 正确的错误处理和日志记录
- ✅ 适当的用户反馈（SnackBar 提示）

### 📋 技术实现要点
1. **模块化设计**: 按功能拆分为独立的组件文件
2. **错误处理**: 完整的异常捕获和用户提示
3. **异步处理**: 使用 async/await 处理网络请求
4. **状态管理**: 使用 StatefulWidget 管理对话框状态
5. **日志记录**: 详细的调试日志便于问题追踪

---

*实现完成于: feature/custom-dev-v095 分支*
*基于: AppFlowy v0.9.5*
*参考: yuni2 分支功能需求*