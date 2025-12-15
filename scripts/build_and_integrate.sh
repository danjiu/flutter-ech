#!/bin/bash

# ECH VPN iOS 构建和集成脚本
# 此脚本用于编译Go代码为iOS Framework并集成到项目中

set -e

# 配置
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ECH_WRAPPER_DIR="$PROJECT_ROOT/ech-wrapper"
IOS_FRAMEWORKS_DIR="$PROJECT_ROOT/ios/Frameworks"
IOS_PROJECT_DIR="$PROJECT_ROOT/ios/Runner.xcodeproj"

echo "🚀 开始构建 ECH VPN iOS Framework..."

# 检查依赖
echo "📦 检查依赖..."
if ! command -v go &> /dev/null; then
    echo "❌ 错误: Go 未安装"
    exit 1
fi

if ! command -v lipo &> /dev/null; then
    echo "❌ 错误: Xcode 命令行工具未安装"
    exit 1
fi

# 构建 Go 模块依赖
echo "📥 下载 Go 依赖..."
cd "$ECH_WRAPPER_DIR"
go mod tidy

# 检查是否需要添加 ech-wk 的源代码
if [ ! -d "$ECH_WRAPPER_DIR/ech-core" ]; then
    echo "📂 复制 ech-wk 源代码..."
    mkdir -p "$ECH_WRAPPER_DIR/ech-core"
    cp -r "$PROJECT_ROOT/../ech-wk"/* "$ECH_WRAPPER_DIR/ech-core/" 2>/dev/null || true
fi

# 构建 iOS Framework
echo "🔨 构建 iOS Framework..."
chmod +x build.sh
./build.sh

# 检查构建结果
if [ ! -d "$IOS_FRAMEWORKS_DIR/ECHWrapper.framework" ]; then
    echo "❌ 构建失败: Framework 未生成"
    exit 1
fi

echo "✅ Framework 构建成功!"

# 集成到 Xcode 项目
echo "🔗 集成到 iOS 项目..."

# 创建 Frameworks 目录（如果不存在）
mkdir -p "$PROJECT_ROOT/ios/Frameworks"

# 更新 Podfile
echo "📝 更新 Podfile..."
cat > "$PROJECT_ROOT/ios/Podfile" << 'EOF'
# Uncomment this line to define a global platform for your project
platform :ios, '12.0'

target 'Runner' do
  use_frameworks!

  # Flutter
  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))

  # 本地 Framework
  pod 'ECHWrapper', :path => 'Frameworks/ECHWrapper.framework'

  target 'RunnerTests' do
    inherit! :search_paths
  end
endEOF

# 安装 Pods
echo "📦 安装 CocoaPods 依赖..."
cd "$PROJECT_ROOT/ios"
pod install

echo "✅ 集成完成!"

# 创建构建说明
echo "📄 创建构建说明文档..."
cat > "$PROJECT_ROOT/BUILD_INSTRUCTIONS.md" << 'EOF'
# ECH VPN iOS 构建说明

## 前置要求

1. 安装 Go 1.21+
2. 安装 Xcode 15+
3. 安装 CocoaPods
4. iOS 开发者账号

## 构建步骤

### 1. 构建 Go Framework

```bash
cd ech-wrapper
./build.sh
```

### 2. 集成到 Xcode 项目

```bash
# 在 ios 目录下
pod install
```

### 3. 在 Xcode 中配置

1. 打开 `ios/Runner.xcworkspace`
2. 在 "General" 标签页中：
   - 确保 "Embed & Sign" 已启用
3. 在 "Signing & Capabilities" 中：
   - 添加 "Network Extensions" Capability
   - 设置正确的 Bundle ID 和签名

### 4. 配置 VPN 权限

在 `ios/Runner/Info.plist` 中已添加：
- Network Extensions 权限
- 后台 VPN 运行权限
- 必要的隐私描述

### 5. 运行项目

```bash
flutter run
```

## 注意事项

1. **签名证书**: 需要有效的 iOS 开发者证书
2. **Bundle ID**: 必须使用开发者账号下的唯一 ID
3. **网络扩展**: 需要在 Apple 开发者后台启用 Network Extensions entitlement

## 故障排除

1. **构建失败**: 检查 Go 和 Xcode 版本
2. **签名错误**: 确保证书和描述文件配置正确
3. **VPN 权限**: 检查 entitlements 文件是否包含 Network Extensions

## 调试

- 查看设备控制台日志
- 使用 Xcode 调试器
- 检查 `ech-wrapper` 的输出日志
EOF

echo "🎉 构建和集成完成!"
echo ""
echo "下一步:"
echo "1. 在 Xcode 中打开 ios/Runner.xcworkspace"
echo "2. 配置签名证书和 Bundle ID"
echo "3. 运行 flutter run"
echo ""
echo "详细说明请查看: BUILD_INSTRUCTIONS.md"