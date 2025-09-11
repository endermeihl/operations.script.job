#!/bin/bash

# 通用工具函数库
# 作者: 系统管理员
# 日期: $(date +%Y-%m-%d)

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# 错误处理函数
handle_error() {
    local exit_code=$1
    local error_message=$2
    if [ $exit_code -ne 0 ]; then
        log_error "$error_message"
        exit $exit_code
    fi
}

# 检查命令是否存在
check_command() {
    local cmd=$1
    if ! command -v $cmd &> /dev/null; then
        log_error "命令 '$cmd' 未找到，请先安装"
        exit 1
    fi
}

# 检查目录是否存在，不存在则创建
ensure_directory() {
    local dir=$1
    if [ ! -d "$dir" ]; then
        log_info "创建目录: $dir"
        mkdir -p "$dir"
        handle_error $? "创建目录失败: $dir"
    fi
}

# 检查文件是否存在
check_file() {
    local file=$1
    if [ ! -f "$file" ]; then
        log_error "文件不存在: $file"
        exit 1
    fi
}

# 备份函数
backup_directory() {
    local source_dir=$1
    local backup_dir=$2
    local timestamp=$(date +%Y%m%d_%H%M%S)
    
    if [ -d "$source_dir" ]; then
        log_info "备份目录: $source_dir -> $backup_dir/backup_$timestamp"
        ensure_directory "$backup_dir"
        cp -r "$source_dir" "$backup_dir/backup_$timestamp"
        handle_error $? "备份失败: $source_dir"
    fi
}

# 清理旧备份（保留最近7天）
cleanup_old_backups() {
    local backup_dir=$1
    if [ -d "$backup_dir" ]; then
        log_info "清理7天前的备份文件"
        find "$backup_dir" -type d -name "backup_*" -mtime +7 -exec rm -rf {} \;
    fi
}

# 验证Git仓库
validate_git_repo() {
    local repo_path=$1
    if [ ! -d "$repo_path/.git" ]; then
        log_error "不是有效的Git仓库: $repo_path"
        return 1
    fi
    return 0
}

# 获取Git仓库状态
get_git_status() {
    local repo_path=$1
    cd "$repo_path" || return 1
    git status --porcelain
}

# 检查是否有未提交的更改
check_uncommitted_changes() {
    local repo_path=$1
    local changes=$(get_git_status "$repo_path")
    if [ -n "$changes" ]; then
        log_warning "仓库有未提交的更改: $repo_path"
        echo "$changes"
        return 1
    fi
    return 0
}
