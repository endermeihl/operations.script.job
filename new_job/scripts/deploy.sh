#!/bin/bash

# 统一部署脚本
# 作者: 系统管理员
# 日期: $(date +%Y-%m-%d)
# 描述: 从GitLab拉取代码，构建并部署前端项目

set -e  # 遇到错误立即退出

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 加载工具函数
source "$PROJECT_ROOT/utils/common.sh"
source "$PROJECT_ROOT/utils/gitlab.sh"
source "$PROJECT_ROOT/utils/build.sh"

# 加载配置文件
source "$PROJECT_ROOT/config/paths.conf"
source "$PROJECT_ROOT/config/projects.conf"
source "$PROJECT_ROOT/config/environments.conf"

# 默认参数
DEFAULT_BRANCH="main"
DEFAULT_ENVIRONMENT="dev"

# 显示帮助信息
show_help() {
    cat << EOF
用法: $0 [选项] <项目名> [环境]

选项:
    -h, --help          显示此帮助信息
    -b, --branch        指定Git分支 (默认: $DEFAULT_BRANCH)
    -e, --environment   指定部署环境 (默认: $DEFAULT_ENVIRONMENT)
    -c, --clean         清理构建缓存
    -v, --verify        验证部署结果
    -t, --tag           创建部署标签
    --no-backup         跳过备份
    --no-archive        跳过创建压缩包

环境选项:
    dev                 开发环境
    test                测试环境
    prod                生产环境
    ls_prod             联调生产环境

项目列表:
$(grep -v '^#' "$PROJECT_ROOT/config/projects.conf" | grep -v '^$' | cut -d'|' -f1 | sed 's/^/    /')

示例:
    $0 pc-cust test                    # 部署pc-cust项目到测试环境
    $0 pc-seller prod -b release-1.0   # 部署pc-seller项目到生产环境，使用release-1.0分支
    $0 pc-mgr ls_prod -c -v            # 部署pc-mgr项目到联调环境，清理缓存并验证

EOF
}

# 解析命令行参数
parse_arguments() {
    PROJECT_NAME=""
    ENVIRONMENT="$DEFAULT_ENVIRONMENT"
    BRANCH="$DEFAULT_BRANCH"
    CLEAN_CACHE=false
    VERIFY_DEPLOYMENT=false
    CREATE_TAG=false
    SKIP_BACKUP=false
    SKIP_ARCHIVE=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -b|--branch)
                BRANCH="$2"
                shift 2
                ;;
            -e|--environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -c|--clean)
                CLEAN_CACHE=true
                shift
                ;;
            -v|--verify)
                VERIFY_DEPLOYMENT=true
                shift
                ;;
            -t|--tag)
                CREATE_TAG=true
                shift
                ;;
            --no-backup)
                SKIP_BACKUP=true
                shift
                ;;
            --no-archive)
                SKIP_ARCHIVE=true
                shift
                ;;
            -*)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;
            *)
                if [ -z "$PROJECT_NAME" ]; then
                    PROJECT_NAME="$1"
                else
                    ENVIRONMENT="$1"
                fi
                shift
                ;;
        esac
    done
    
    if [ -z "$PROJECT_NAME" ]; then
        log_error "请指定项目名称"
        show_help
        exit 1
    fi
}

# 获取项目配置
get_project_config() {
    local project_name=$1
    local config_line=$(grep "^${project_name}|" "$PROJECT_ROOT/config/projects.conf")
    
    if [ -z "$config_line" ]; then
        log_error "未找到项目配置: $project_name"
        log_info "可用项目: $(grep -v '^#' "$PROJECT_ROOT/config/projects.conf" | grep -v '^$' | cut -d'|' -f1 | tr '\n' ' ')"
        exit 1
    fi
    
    IFS='|' read -r name repo_url local_path build_cmd output_name <<< "$config_line"
    
    PROJECT_REPO_URL="$repo_url"
    PROJECT_LOCAL_PATH="$local_path"
    PROJECT_BUILD_CMD="$build_cmd"
    PROJECT_OUTPUT_NAME="$output_name"
}

# 获取环境配置
get_environment_config() {
    local env=$1
    local config_line=$(grep "^${env}|" "$PROJECT_ROOT/config/environments.conf")
    
    if [ -z "$config_line" ]; then
        log_warning "未找到环境配置: $env，使用默认构建命令"
        ENV_BUILD_SUFFIX=""
        ENV_DESCRIPTION="$env"
    else
        IFS='|' read -r env_name build_suffix description <<< "$config_line"
        ENV_BUILD_SUFFIX="$build_suffix"
        ENV_DESCRIPTION="$description"
    fi
}

# 主部署流程
main() {
    log_info "=== 开始部署流程 ==="
    log_info "项目: $PROJECT_NAME"
    log_info "环境: $ENVIRONMENT ($ENV_DESCRIPTION)"
    log_info "分支: $BRANCH"
    
    # 检查必要命令
    check_command "git"
    check_command "npm"
    check_command "node"
    
    # 检查GitLab连接
    if ! check_gitlab_connection; then
        log_error "GitLab连接失败，请检查配置"
        exit 1
    fi
    
    # 确保必要目录存在
    ensure_directory "$STATIC_DEPLOY_PATH"
    ensure_directory "$LOG_PATH"
    ensure_directory "$BACKUP_PATH"
    
    # 克隆或更新代码
    log_info "=== 步骤1: 更新代码 ==="
    gitlab_clone_or_update "$PROJECT_REPO_URL" "$PROJECT_LOCAL_PATH" "$BRANCH"
    
    # 显示仓库信息
    log_info "仓库信息:"
    get_repo_info "$PROJECT_LOCAL_PATH" | sed 's/^/  /'
    
    # 构建项目
    log_info "=== 步骤2: 构建项目 ==="
    local full_build_cmd="${PROJECT_BUILD_CMD}${ENV_BUILD_SUFFIX}"
    build_project "$PROJECT_LOCAL_PATH" "$full_build_cmd" "$ENVIRONMENT"
    
    # 显示构建信息
    get_build_info "$PROJECT_LOCAL_PATH" | sed 's/^/  /'
    
    # 部署静态文件
    log_info "=== 步骤3: 部署静态文件 ==="
    if [ "$SKIP_BACKUP" = false ]; then
        deploy_static_files "$PROJECT_LOCAL_PATH/dist" "$PROJECT_OUTPUT_NAME" "$ENVIRONMENT"
    else
        log_info "跳过备份，直接部署..."
        local target_path="${STATIC_DEPLOY_PATH}/${PROJECT_OUTPUT_NAME}"
        rm -rf "$target_path"
        cp -r "$PROJECT_LOCAL_PATH/dist" "$target_path"
        chmod -R 755 "$target_path"
    fi
    
    # 创建压缩包
    if [ "$SKIP_ARCHIVE" = false ]; then
        log_info "=== 步骤4: 创建压缩包 ==="
        create_archive "$PROJECT_OUTPUT_NAME" "$PROJECT_OUTPUT_NAME" "$STATIC_DEPLOY_PATH"
    fi
    
    # 验证部署
    if [ "$VERIFY_DEPLOYMENT" = true ]; then
        log_info "=== 步骤5: 验证部署 ==="
        verify_deployment "${STATIC_DEPLOY_PATH}/${PROJECT_OUTPUT_NAME}"
    fi
    
    # 创建部署标签
    if [ "$CREATE_TAG" = true ]; then
        log_info "=== 步骤6: 创建部署标签 ==="
        local version=$(date +%Y%m%d-%H%M%S)
        create_deployment_tag "$PROJECT_LOCAL_PATH" "$ENVIRONMENT" "$version"
    fi
    
    # 清理构建缓存
    if [ "$CLEAN_CACHE" = true ]; then
        log_info "=== 步骤7: 清理构建缓存 ==="
        cleanup_build_cache "$PROJECT_LOCAL_PATH"
    fi
    
    # 清理旧备份
    cleanup_old_backups "$BACKUP_PATH"
    
    log_success "=== 部署完成 ==="
    log_info "部署路径: ${STATIC_DEPLOY_PATH}/${PROJECT_OUTPUT_NAME}"
    if [ "$SKIP_ARCHIVE" = false ]; then
        log_info "压缩包: ${STATIC_DEPLOY_PATH}/${PROJECT_OUTPUT_NAME}.tar.gz"
    fi
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    parse_arguments "$@"
    get_project_config "$PROJECT_NAME"
    get_environment_config "$ENVIRONMENT"
    main
fi
