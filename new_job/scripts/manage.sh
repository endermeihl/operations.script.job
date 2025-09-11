#!/bin/bash

# 部署管理脚本
# 作者: 系统管理员
# 日期: $(date +%Y-%m-%d)
# 描述: 提供部署系统的管理功能

set -e

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 加载工具函数
source "$PROJECT_ROOT/utils/common.sh"

# 加载配置文件
source "$PROJECT_ROOT/config/paths.conf"

# 显示帮助信息
show_help() {
    cat << EOF
用法: $0 <命令> [选项]

命令:
    status              显示系统状态
    config              显示配置信息
    test                测试GitLab连接
    init                初始化部署环境
    clean               清理临时文件
    backup              备份当前部署
    restore <backup>    恢复指定备份
    logs                查看部署日志
    health              健康检查

选项:
    -h, --help          显示此帮助信息
    -v, --verbose       显示详细信息

示例:
    $0 status                    # 显示系统状态
    $0 test                      # 测试GitLab连接
    $0 init                      # 初始化部署环境
    $0 clean                     # 清理临时文件
    $0 backup                    # 备份当前部署
    $0 restore backup_20240101   # 恢复指定备份

EOF
}

# 显示系统状态
show_status() {
    log_info "=== 系统状态 ==="
    
    # 检查必要命令
    local commands=("git" "npm" "node" "curl")
    for cmd in "${commands[@]}"; do
        if command -v $cmd &> /dev/null; then
            local version=$($cmd --version 2>/dev/null | head -n1)
            log_success "✓ $cmd: $version"
        else
            log_error "✗ $cmd: 未安装"
        fi
    done
    
    # 检查目录
    local directories=("$STATIC_DEPLOY_PATH" "$LOG_PATH" "$BACKUP_PATH")
    for dir in "${directories[@]}"; do
        if [ -d "$dir" ]; then
            local size=$(du -sh "$dir" 2>/dev/null | cut -f1)
            log_success "✓ 目录存在: $dir (大小: $size)"
        else
            log_warning "✗ 目录不存在: $dir"
        fi
    done
    
    # 检查配置文件
    local config_files=("$PROJECT_ROOT/config/projects.conf" "$PROJECT_ROOT/config/environments.conf" "$PROJECT_ROOT/config/paths.conf")
    for file in "${config_files[@]}"; do
        if [ -f "$file" ]; then
            log_success "✓ 配置文件存在: $file"
        else
            log_error "✗ 配置文件不存在: $file"
        fi
    done
    
    # 显示项目状态
    log_info "=== 项目状态 ==="
    if [ -d "$STATIC_DEPLOY_PATH" ]; then
        local project_count=$(find "$STATIC_DEPLOY_PATH" -maxdepth 1 -type d -name "pc*" | wc -l)
        log_info "已部署项目数量: $project_count"
        
        if [ "$VERBOSE" = true ]; then
            find "$STATIC_DEPLOY_PATH" -maxdepth 1 -type d -name "pc*" | while read -r project_dir; do
                local project_name=$(basename "$project_dir")
                local project_size=$(du -sh "$project_dir" 2>/dev/null | cut -f1)
                local file_count=$(find "$project_dir" -type f 2>/dev/null | wc -l)
                log_info "  $project_name: $project_size ($file_count 个文件)"
            done
        fi
    fi
}

# 显示配置信息
show_config() {
    log_info "=== 配置信息 ==="
    
    echo "静态文件部署路径: $STATIC_DEPLOY_PATH"
    echo "日志文件路径: $LOG_PATH"
    echo "备份路径: $BACKUP_PATH"
    echo "GitLab URL: $GITLAB_URL"
    echo "GitLab Token: ${GITLAB_TOKEN:0:10}..."
    
    log_info "=== 项目配置 ==="
    if [ -f "$PROJECT_ROOT/config/projects.conf" ]; then
        grep -v '^#' "$PROJECT_ROOT/config/projects.conf" | grep -v '^$' | while IFS='|' read -r name repo_url local_path build_cmd output_name; do
            echo "项目: $name"
            echo "  仓库: $repo_url"
            echo "  本地路径: $local_path"
            echo "  构建命令: $build_cmd"
            echo "  输出名称: $output_name"
            echo ""
        done
    fi
    
    log_info "=== 环境配置 ==="
    if [ -f "$PROJECT_ROOT/config/environments.conf" ]; then
        grep -v '^#' "$PROJECT_ROOT/config/environments.conf" | grep -v '^$' | while IFS='|' read -r env_name build_suffix description; do
            echo "环境: $env_name"
            echo "  构建后缀: $build_suffix"
            echo "  描述: $description"
            echo ""
        done
    fi
}

# 测试GitLab连接
test_gitlab() {
    log_info "=== 测试GitLab连接 ==="
    
    if [ -z "$GITLAB_TOKEN" ] || [ "$GITLAB_TOKEN" = "your_gitlab_token_here" ]; then
        log_error "GitLab Token 未配置"
        return 1
    fi
    
    if [ -z "$GITLAB_URL" ]; then
        log_error "GitLab URL 未配置"
        return 1
    fi
    
    log_info "测试连接到: $GITLAB_URL"
    
    local response=$(curl -s -H "PRIVATE-TOKEN: ${GITLAB_TOKEN}" "${GITLAB_URL}/api/v4/user")
    
    if echo "$response" | grep -q "id"; then
        local username=$(echo "$response" | grep -o '"username":"[^"]*"' | cut -d'"' -f4)
        local name=$(echo "$response" | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
        log_success "GitLab连接成功"
        log_info "用户: $username ($name)"
        return 0
    else
        log_error "GitLab连接失败"
        echo "响应: $response"
        return 1
    fi
}

# 初始化部署环境
init_environment() {
    log_info "=== 初始化部署环境 ==="
    
    # 创建必要目录
    ensure_directory "$STATIC_DEPLOY_PATH"
    ensure_directory "$LOG_PATH"
    ensure_directory "$BACKUP_PATH"
    
    # 设置权限
    chmod 755 "$STATIC_DEPLOY_PATH"
    chmod 755 "$LOG_PATH"
    chmod 755 "$BACKUP_PATH"
    
    log_success "目录创建完成"
    
    # 检查配置文件
    local config_files=("$PROJECT_ROOT/config/projects.conf" "$PROJECT_ROOT/config/environments.conf" "$PROJECT_ROOT/config/paths.conf")
    for file in "${config_files[@]}"; do
        if [ ! -f "$file" ]; then
            log_error "配置文件不存在: $file"
            return 1
        fi
    done
    
    log_success "配置文件检查完成"
    
    # 测试GitLab连接
    if test_gitlab; then
        log_success "GitLab连接测试通过"
    else
        log_warning "GitLab连接测试失败，请检查配置"
    fi
    
    log_success "部署环境初始化完成"
}

# 清理临时文件
clean_temp_files() {
    log_info "=== 清理临时文件 ==="
    
    # 清理日志文件（保留最近7天）
    if [ -d "$LOG_PATH" ]; then
        local log_count=$(find "$LOG_PATH" -name "*.log" -mtime +7 | wc -l)
        if [ $log_count -gt 0 ]; then
            find "$LOG_PATH" -name "*.log" -mtime +7 -delete
            log_info "清理了 $log_count 个旧日志文件"
        else
            log_info "没有需要清理的旧日志文件"
        fi
    fi
    
    # 清理临时目录
    local temp_dirs=("/tmp/deploy_*" "/tmp/result_*")
    for pattern in "${temp_dirs[@]}"; do
        local temp_count=$(find /tmp -maxdepth 1 -name "$(basename "$pattern")" 2>/dev/null | wc -l)
        if [ $temp_count -gt 0 ]; then
            find /tmp -maxdepth 1 -name "$(basename "$pattern")" -delete 2>/dev/null || true
            log_info "清理了 $temp_count 个临时目录"
        fi
    done
    
    # 清理npm缓存
    if command -v npm &> /dev/null; then
        log_info "清理npm缓存..."
        npm cache clean --force
        log_success "npm缓存清理完成"
    fi
    
    log_success "临时文件清理完成"
}

# 备份当前部署
backup_deployment() {
    log_info "=== 备份当前部署 ==="
    
    if [ ! -d "$STATIC_DEPLOY_PATH" ]; then
        log_error "部署目录不存在: $STATIC_DEPLOY_PATH"
        return 1
    fi
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_name="deployment_backup_$timestamp"
    local backup_path="$BACKUP_PATH/$backup_name"
    
    log_info "创建备份: $backup_name"
    
    cp -r "$STATIC_DEPLOY_PATH" "$backup_path"
    handle_error $? "备份失败"
    
    # 创建备份信息文件
    cat > "$backup_path/backup_info.txt" << EOF
备份时间: $(date)
备份路径: $backup_path
原始路径: $STATIC_DEPLOY_PATH
备份大小: $(du -sh "$backup_path" | cut -f1)
EOF
    
    log_success "备份创建成功: $backup_path"
    log_info "备份大小: $(du -sh "$backup_path" | cut -f1)"
}

# 恢复指定备份
restore_backup() {
    local backup_name=$1
    
    if [ -z "$backup_name" ]; then
        log_error "请指定备份名称"
        return 1
    fi
    
    local backup_path="$BACKUP_PATH/$backup_name"
    
    if [ ! -d "$backup_path" ]; then
        log_error "备份不存在: $backup_path"
        log_info "可用备份:"
        ls -la "$BACKUP_PATH" | grep "deployment_backup_" | awk '{print "  " $9}'
        return 1
    fi
    
    log_info "=== 恢复备份 ==="
    log_info "备份名称: $backup_name"
    log_info "备份路径: $backup_path"
    
    # 备份当前部署
    log_info "备份当前部署..."
    backup_deployment
    
    # 恢复备份
    log_info "恢复备份..."
    rm -rf "$STATIC_DEPLOY_PATH"
    cp -r "$backup_path" "$STATIC_DEPLOY_PATH"
    handle_error $? "恢复失败"
    
    log_success "备份恢复成功"
}

# 查看部署日志
view_logs() {
    log_info "=== 部署日志 ==="
    
    if [ ! -d "$LOG_PATH" ]; then
        log_warning "日志目录不存在: $LOG_PATH"
        return 1
    fi
    
    local log_files=$(find "$LOG_PATH" -name "*.log" -type f | sort -r | head -10)
    
    if [ -z "$log_files" ]; then
        log_info "没有找到日志文件"
        return 0
    fi
    
    echo "最近的日志文件:"
    echo "$log_files" | while read -r log_file; do
        local file_size=$(du -h "$log_file" | cut -f1)
        local file_time=$(stat -c %y "$log_file" 2>/dev/null || stat -f %Sm "$log_file" 2>/dev/null)
        echo "  $(basename "$log_file"): $file_size ($file_time)"
    done
    
    if [ "$VERBOSE" = true ]; then
        echo ""
        echo "最新日志内容:"
        echo "----------------------------------------"
        head -n 50 $(echo "$log_files" | head -n1) 2>/dev/null || true
    fi
}

# 健康检查
health_check() {
    log_info "=== 健康检查 ==="
    
    local issues=0
    
    # 检查必要命令
    local commands=("git" "npm" "node")
    for cmd in "${commands[@]}"; do
        if ! command -v $cmd &> /dev/null; then
            log_error "命令未安装: $cmd"
            ((issues++))
        fi
    done
    
    # 检查目录权限
    local directories=("$STATIC_DEPLOY_PATH" "$LOG_PATH" "$BACKUP_PATH")
    for dir in "${directories[@]}"; do
        if [ ! -d "$dir" ]; then
            log_error "目录不存在: $dir"
            ((issues++))
        elif [ ! -w "$dir" ]; then
            log_error "目录无写权限: $dir"
            ((issues++))
        fi
    done
    
    # 检查配置文件
    local config_files=("$PROJECT_ROOT/config/projects.conf" "$PROJECT_ROOT/config/environments.conf" "$PROJECT_ROOT/config/paths.conf")
    for file in "${config_files[@]}"; do
        if [ ! -f "$file" ]; then
            log_error "配置文件不存在: $file"
            ((issues++))
        fi
    done
    
    # 检查GitLab连接
    if ! test_gitlab; then
        log_error "GitLab连接失败"
        ((issues++))
    fi
    
    # 输出结果
    if [ $issues -eq 0 ]; then
        log_success "健康检查通过，没有发现问题"
        return 0
    else
        log_error "健康检查发现 $issues 个问题"
        return 1
    fi
}

# 解析命令行参数
parse_arguments() {
    COMMAND=""
    VERBOSE=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -*)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;
            *)
                if [ -z "$COMMAND" ]; then
                    COMMAND="$1"
                else
                    # 处理restore命令的参数
                    if [ "$COMMAND" = "restore" ]; then
                        RESTORE_BACKUP="$1"
                    fi
                fi
                shift
                ;;
        esac
    done
    
    if [ -z "$COMMAND" ]; then
        log_error "请指定命令"
        show_help
        exit 1
    fi
}

# 主函数
main() {
    case $COMMAND in
        "status")
            show_status
            ;;
        "config")
            show_config
            ;;
        "test")
            test_gitlab
            ;;
        "init")
            init_environment
            ;;
        "clean")
            clean_temp_files
            ;;
        "backup")
            backup_deployment
            ;;
        "restore")
            restore_backup "$RESTORE_BACKUP"
            ;;
        "logs")
            view_logs
            ;;
        "health")
            health_check
            ;;
        *)
            log_error "未知命令: $COMMAND"
            show_help
            exit 1
            ;;
    esac
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    parse_arguments "$@"
    main
fi
