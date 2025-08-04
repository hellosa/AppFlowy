# AppFlowy Development Guide - CLAUDE.md

## 项目概述

AppFlowy 是一个基于 Flutter 和 Rust 的开源笔记和知识管理应用，提供了类似 Notion 的功能。项目采用多平台架构，支持 Desktop、Mobile 和 Web 平台。

### 核心技术栈
- **前端**: Flutter (>=3.27.4) + Dart (>=3.3.0)
- **后端**: Rust + SQLite + Diesel ORM
- **协作**: AppFlowy-Collab (基于 Yrs/CRDT)
- **存储**: SQLite + 本地文件系统
- **构建工具**: cargo-make, Flutter SDK

## 项目架构

### 目录结构
```
AppFlowy/
├── frontend/                     # 前端代码
│   ├── appflowy_flutter/        # Flutter 应用主体
│   │   ├── lib/                 # Dart 源码
│   │   │   ├── core/           # 核心功能
│   │   │   ├── features/       # 功能模块
│   │   │   ├── plugins/        # 插件系统
│   │   │   ├── shared/         # 共享组件
│   │   │   └── workspace/      # 工作区管理
│   │   ├── packages/           # 本地包
│   │   ├── assets/             # 资源文件
│   │   └── integration_test/   # 集成测试
│   ├── rust-lib/               # Rust 后端库
│   │   ├── flowy-core/         # 核心业务逻辑
│   │   ├── flowy-database2/    # 数据库模块
│   │   ├── flowy-document/     # 文档模块
│   │   ├── flowy-folder/       # 文件夹管理
│   │   ├── flowy-user/         # 用户管理
│   │   ├── flowy-ai/           # AI 功能
│   │   └── dart-ffi/           # FFI 绑定
│   ├── scripts/                # 构建脚本
│   └── resources/              # 共享资源
├── doc/                        # 文档
└── install.sh                  # 安装脚本
```

### 架构特点
1. **前后端分离**: Flutter 前端 + Rust 后端
2. **FFI 通信**: 通过 dart-ffi 进行前后端通信
3. **模块化设计**: 功能按模块划分，高内聚低耦合
4. **协作支持**: 基于 CRDT 的实时协作
5. **多平台支持**: 统一代码库支持多个平台

## 开发环境配置

### 系统要求
- **操作系统**: macOS, Linux, Windows
- **Flutter**: >=3.27.4
- **Rust**: >=1.70
- **工具**: cargo-make

### 环境安装
```bash
# 1. 安装 Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# 2. 安装 Flutter (请访问 https://flutter.dev/docs/get-started/install)

# 3. 安装 cargo-make
cargo install cargo-make

# 4. 验证环境
flutter doctor
cargo --version
cargo make --version
```

### 项目初始化
```bash
# 克隆项目
git clone https://github.com/AppFlowy-IO/AppFlowy.git
cd AppFlowy

# 切换到开发分支 (例如基于 0.9.5)
git checkout -b feature/custom-dev-v095 0.9.5

# 进入 frontend 目录
cd frontend

# 安装 Flutter 依赖
cd appflowy_flutter
flutter pub get

# 构建 Rust 后端 (macOS)
cd ../
cargo make flowy-dev-env
```

## 常用开发命令

### Flutter 开发命令
```bash
# 进入 Flutter 项目目录
cd frontend/appflowy_flutter

# 安装依赖
flutter pub get

# 代码生成 (build_runner)
dart run build_runner build -d    # 一次性构建
dart run build_runner watch       # 监听模式

# 运行应用
flutter run                       # 默认平台
flutter run -d macos             # macOS
flutter run -d linux             # Linux
flutter run -d windows           # Windows

# 构建发布版本
flutter build macos              # macOS 发布版
flutter build linux              # Linux 发布版
flutter build windows            # Windows 发布版

# 测试
flutter test                      # 单元测试
flutter test integration_test/   # 集成测试

# 代码分析
flutter analyze                   # 静态分析
```

### Rust 开发命令
```bash
# 进入 frontend 目录
cd frontend

# 开发环境构建 (macOS ARM64)
cargo make appflowy-dev-macos-arm64

# 开发环境构建 (macOS x86_64)
cargo make appflowy-dev-macos-x86_64

# 开发环境构建 (Linux)
cargo make appflowy-dev-linux-x86_64

# 开发环境构建 (Windows)
cargo make appflowy-dev-windows-x86

# 运行 Rust 测试
cd rust-lib
cargo test

# 格式化代码
cargo fmt

# 代码检查
cargo clippy
```

### 通用构建命令
```bash
# 进入 frontend 目录
cd frontend

# 完整开发构建 (自动检测平台)
cargo make appflowy-dev

# 清理构建产物
cargo make clean

# 查看所有可用任务
cargo make --list-all-steps

# 环境信息
cargo make echo_env
```

## 代码规范

### Dart/Flutter 规范
基于 `frontend/appflowy_flutter/analysis_options.yaml`:

1. **Lint 规则**:
   - 使用 `flutter_lints` 基础规则
   - 强制使用尾随逗号 `require_trailing_commas`
   - 偏好 final 声明 `prefer_final_fields`, `prefer_final_locals`
   - 避免不必要的容器 `avoid_unnecessary_containers`

2. **代码风格**:
   - 总是声明返回类型 `always_declare_return_types`
   - 构造函数优先排序 `sort_constructors_first`
   - 使用装饰盒子 `use_decorated_box`

3. **文件命名**:
   - 使用蛇形命名法 (snake_case)
   - 生成的文件排除检查 (`**/*.g.dart`, `**/*.freezed.dart`)

### Rust 规范
基于 `frontend/rust-lib/rustfmt.toml`:

1. **格式化配置**:
   - 最大宽度: 100 字符
   - 缩进: 2 个空格
   - 自动换行样式: Auto
   - 启用字段初始化简写

2. **代码组织**:
   - 重新排序导入 `reorder_imports = true`
   - 重新排序模块 `reorder_modules = true`
   - 合并派生 `merge_derives = true`

3. **命名规范**:
   - 模块: snake_case
   - 结构体/枚举: PascalCase
   - 函数/变量: snake_case
   - 常量: SCREAMING_SNAKE_CASE

## 开发工作流

### 1. 功能开发流程
```bash
# 1. 创建功能分支
git checkout -b feature/your-feature-name

# 2. 开发前端 (Flutter)
cd frontend/appflowy_flutter
# 编辑 lib/ 下的代码
# 运行 dart run build_runner watch (如果需要代码生成)

# 3. 开发后端 (Rust)
cd ../rust-lib
# 编辑相应模块的代码
# 运行 cargo test 验证

# 4. 构建和测试
cd ../
cargo make appflowy-dev
cd appflowy_flutter
flutter test
flutter run

# 5. 提交代码
git add .
git commit -m "feat: add your feature description"
```

### 2. 调试技巧
- **Flutter 调试**: 使用 VS Code / Android Studio 的调试功能
- **Rust 调试**: 使用 `tracing` 日志库，设置 `RUST_LOG=debug`
- **FFI 调试**: 检查 `dart-ffi` 模块的绑定

### 3. 测试策略
- **单元测试**: Flutter `test/` 和 Rust `#[cfg(test)]`
- **集成测试**: `integration_test/` 目录
- **手动测试**: 多平台验证

## 项目配置

### 环境变量
```bash
# Rust 日志级别
export RUST_LOG=info

# 构建配置
export CARGO_PROFILE=dev        # dev/release
export BUILD_FLAG=debug         # debug/release
export APP_ENVIRONMENT=local    # local/production
```

### 关键配置文件
- `frontend/Makefile.toml`: cargo-make 主配置
- `frontend/appflowy_flutter/pubspec.yaml`: Flutter 项目配置
- `frontend/rust-lib/Cargo.toml`: Rust 工作区配置
- `frontend/appflowy_flutter/analysis_options.yaml`: Dart 分析器配置

## 常见问题

### 构建问题
1. **FFI 绑定失败**: 检查 Rust 库是否正确构建
2. **Flutter 依赖冲突**: 运行 `flutter pub deps` 检查
3. **平台特定问题**: 检查对应的环境配置

### 开发问题
1. **代码生成**: 确保运行了 `build_runner`
2. **热重载失败**: 重启 `flutter run`
3. **Rust 编译慢**: 使用增量编译，避免 `clean`

## 相关资源

### 官方文档
- [AppFlowy 官方文档](https://docs.appflowy.io/)
- [贡献指南](https://docs.appflowy.io/docs/documentation/software-contributions/contributing-to-appflowy)
- [架构文档](https://appflowy.gitbook.io/docs/essential-documentation/contribute-to-appflowy/architecture/frontend/frontend/codemap)

### 社区资源
- [GitHub 仓库](https://github.com/AppFlowy-IO/AppFlowy)
- [Discord 社区](https://discord.gg/9Q2xaN37tV)
- [论坛](https://forum.appflowy.io/)

### 技术栈文档
- [Flutter 官方文档](https://flutter.dev/docs)
- [Rust 官方文档](https://doc.rust-lang.org/)
- [cargo-make 文档](https://github.com/sagiegurari/cargo-make)

---

*最后更新: 基于 AppFlowy v0.9.5*
*分支: feature/custom-dev-v095*