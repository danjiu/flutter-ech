#!/bin/bash

# 代码生成脚本
# 在GitHub Codespaces或本地Flutter环境中运行

echo "开始生成代码..."

# 生成JSON序列化代码
flutter packages pub run build_runner build --delete-conflicting-outputs

echo "代码生成完成！"