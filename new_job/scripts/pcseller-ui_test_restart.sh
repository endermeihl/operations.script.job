#!/bin/bash

# PC Seller UI 测试环境部署脚本
# 作者: 系统管理员
# 日期: $(date +%Y-%m-%d)
# 描述: 部署pc-seller项目到测试环境

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 调用统一部署脚本
exec "$SCRIPT_DIR/deploy.sh" pc-seller test "$@"
