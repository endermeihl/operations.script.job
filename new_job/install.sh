#!/bin/bash

# 安装脚本
# 作者: 系统管理员
# 日期: $(date +%Y-%m-%d)
# 描述: 设置脚本权限和初始化环境

set -e

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== 前端项目部署系统安装 ==="
echo "安装目录: $SCRIPT_DIR"

# 设置脚本执行权限
echo "设置脚本执行权限..."
chmod +x "$SCRIPT_DIR/scripts"/*.sh
chmod +x "$SCRIPT_DIR/utils"/*.sh

echo "✓ 脚本权限设置完成"

# 检查必要命令
echo "检查必要命令..."
commands=("git" "npm" "node" "curl")
missing_commands=()

for cmd in "${commands[@]}"; do
    if command -v $cmd &> /dev/null; then
        echo "✓ $cmd: $(which $cmd)"
    else
        echo "✗ $cmd: 未安装"
        missing_commands+=("$cmd")
    fi
done

if [ ${#missing_commands[@]} -gt 0 ]; then
    echo ""
    echo "警告: 以下命令未安装，请先安装："
    for cmd in "${missing_commands[@]}"; do
        echo "  - $cmd"
    done
    echo ""
fi

# 创建必要目录
echo "创建必要目录..."
mkdir -p "$SCRIPT_DIR/logs"
mkdir -p "$SCRIPT_DIR/backup"

echo "✓ 目录创建完成"

# 检查配置文件
echo "检查配置文件..."
config_files=("$SCRIPT_DIR/config/projects.conf" "$SCRIPT_DIR/config/environments.conf" "$SCRIPT_DIR/config/paths.conf")

for file in "${config_files[@]}"; do
    if [ -f "$file" ]; then
        echo "✓ 配置文件存在: $(basename "$file")"
    else
        echo "✗ 配置文件不存在: $(basename "$file")"
    fi
done

echo ""
echo "=== 安装完成 ==="
echo ""
echo "下一步操作："
echo "1. 编辑配置文件 config/paths.conf，设置正确的路径和GitLab信息"
echo "2. 运行初始化命令: ./scripts/manage.sh init"
echo "3. 测试GitLab连接: ./scripts/manage.sh test"
echo "4. 开始使用部署脚本"
echo ""
echo "获取帮助: ./scripts/manage.sh --help"
echo "查看状态: ./scripts/manage.sh status"
