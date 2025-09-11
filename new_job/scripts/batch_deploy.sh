#!/bin/bash

# 批量部署脚本
# 作者: 系统管理员
# 日期: $(date +%Y-%m-%d)
# 描述: 批量部署多个项目

set -e

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
PARALLEL_JOBS=3

# 显示帮助信息
show_help() {
    cat << EOF
用法: $0 [选项] <项目列表> [环境]

选项:
    -h, --help          显示此帮助信息
    -b, --branch        指定Git分支 (默认: $DEFAULT_BRANCH)
    -e, --environment   指定部署环境 (默认: $DEFAULT_ENVIRONMENT)
    -j, --jobs          并行任务数 (默认: $PARALLEL_JOBS)
    -c, --clean         清理构建缓存
    -v, --verify        验证部署结果
    --no-backup         跳过备份
    --no-archive        跳过创建压缩包
    --continue-on-error 遇到错误继续执行

项目列表选项:
    all                 部署所有项目
    platform            部署平台相关项目 (pc-cust, pc-mgr, pc-seller, pc-lec, pc-router, pc-scs)
    standalone          部署独立项目 (pc-achievements, pc-opr)
    <项目1,项目2,...>   指定项目列表，用逗号分隔

环境选项:
    dev                 开发环境
    test                测试环境
    prod                生产环境
    ls_prod             联调生产环境

示例:
    $0 all test                          # 部署所有项目到测试环境
    $0 platform prod -j 5                # 部署平台项目到生产环境，5个并行任务
    $0 pc-cust,pc-mgr,pc-seller ls_prod  # 部署指定项目到联调环境

EOF
}

# 解析命令行参数
parse_arguments() {
    PROJECT_LIST=""
    ENVIRONMENT="$DEFAULT_ENVIRONMENT"
    BRANCH="$DEFAULT_BRANCH"
    CLEAN_CACHE=false
    VERIFY_DEPLOYMENT=false
    SKIP_BACKUP=false
    SKIP_ARCHIVE=false
    CONTINUE_ON_ERROR=false
    
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
            -j|--jobs)
                PARALLEL_JOBS="$2"
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
            --no-backup)
                SKIP_BACKUP=true
                shift
                ;;
            --no-archive)
                SKIP_ARCHIVE=true
                shift
                ;;
            --continue-on-error)
                CONTINUE_ON_ERROR=true
                shift
                ;;
            -*)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;
            *)
                if [ -z "$PROJECT_LIST" ]; then
                    PROJECT_LIST="$1"
                else
                    ENVIRONMENT="$1"
                fi
                shift
                ;;
        esac
    done
    
    if [ -z "$PROJECT_LIST" ]; then
        log_error "请指定项目列表"
        show_help
        exit 1
    fi
}

# 解析项目列表
parse_project_list() {
    local project_list=$1
    local projects=()
    
    case $project_list in
        "all")
            # 获取所有项目
            while IFS='|' read -r name repo_url local_path build_cmd output_name; do
                if [[ ! "$name" =~ ^#.*$ ]] && [[ -n "$name" ]]; then
                    projects+=("$name")
                fi
            done < "$PROJECT_ROOT/config/projects.conf"
            ;;
        "platform")
            projects=("pc-cust" "pc-mgr" "pc-seller" "pc-lec" "pc-router" "pc-scs")
            ;;
        "standalone")
            projects=("pc-achievements" "pc-opr")
            ;;
        *)
            # 逗号分隔的项目列表
            IFS=',' read -ra projects <<< "$project_list"
            ;;
    esac
    
    # 验证项目是否存在
    local valid_projects=()
    for project in "${projects[@]}"; do
        if grep -q "^${project}|" "$PROJECT_ROOT/config/projects.conf"; then
            valid_projects+=("$project")
        else
            log_warning "项目不存在或未配置: $project"
        fi
    done
    
    echo "${valid_projects[@]}"
}

# 单个项目部署函数
deploy_single_project() {
    local project_name=$1
    local environment=$2
    local branch=$3
    local clean_cache=$4
    local verify_deployment=$5
    local skip_backup=$6
    local skip_archive=$7
    
    local log_file="${LOG_PATH}/deploy_${project_name}_${environment}_$(date +%Y%m%d_%H%M%S).log"
    
    log_info "开始部署项目: $project_name (日志: $log_file)"
    
    # 构建部署命令
    local deploy_cmd="$SCRIPT_DIR/deploy.sh"
    deploy_cmd="$deploy_cmd -b $branch -e $environment"
    
    if [ "$clean_cache" = true ]; then
        deploy_cmd="$deploy_cmd -c"
    fi
    
    if [ "$verify_deployment" = true ]; then
        deploy_cmd="$deploy_cmd -v"
    fi
    
    if [ "$skip_backup" = true ]; then
        deploy_cmd="$deploy_cmd --no-backup"
    fi
    
    if [ "$skip_archive" = true ]; then
        deploy_cmd="$deploy_cmd --no-archive"
    fi
    
    deploy_cmd="$deploy_cmd $project_name"
    
    # 执行部署
    if eval "$deploy_cmd" > "$log_file" 2>&1; then
        log_success "项目部署成功: $project_name"
        return 0
    else
        log_error "项目部署失败: $project_name (日志: $log_file)"
        return 1
    fi
}

# 并行部署函数
parallel_deploy() {
    local projects=("$@")
    local pids=()
    local results=()
    local failed_projects=()
    
    log_info "开始并行部署 ${#projects[@]} 个项目，并行数: $PARALLEL_JOBS"
    
    # 创建命名管道用于控制并发数
    local fifo="/tmp/deploy_fifo_$$"
    mkfifo "$fifo"
    exec 3<>"$fifo"
    rm -f "$fifo"
    
    # 初始化信号量
    for ((i=0; i<PARALLEL_JOBS; i++)); do
        echo >&3
    done
    
    # 启动部署任务
    for project in "${projects[@]}"; do
        read -u 3
        {
            if deploy_single_project "$project" "$ENVIRONMENT" "$BRANCH" "$CLEAN_CACHE" "$VERIFY_DEPLOYMENT" "$SKIP_BACKUP" "$SKIP_ARCHIVE"; then
                echo "SUCCESS:$project" >&4
            else
                echo "FAILED:$project" >&4
            fi
            echo >&3
        } &
        pids+=($!)
    done
    
    # 创建结果管道
    local result_fifo="/tmp/result_fifo_$$"
    mkfifo "$result_fifo"
    exec 4<>"$result_fifo"
    rm -f "$result_fifo"
    
    # 收集结果
    for ((i=0; i<${#projects[@]}; i++)); do
        read -u 4 result
        results+=("$result")
        if [[ "$result" =~ ^FAILED: ]]; then
            failed_projects+=("${result#FAILED:}")
        fi
    done
    
    # 等待所有任务完成
    for pid in "${pids[@]}"; do
        wait "$pid"
    done
    
    # 关闭文件描述符
    exec 3<&-
    exec 4<&-
    
    # 输出结果统计
    local success_count=0
    local failed_count=0
    
    for result in "${results[@]}"; do
        if [[ "$result" =~ ^SUCCESS: ]]; then
            ((success_count++))
        else
            ((failed_count++))
        fi
    done
    
    log_info "=== 批量部署完成 ==="
    log_info "成功: $success_count 个项目"
    log_info "失败: $failed_count 个项目"
    
    if [ ${#failed_projects[@]} -gt 0 ]; then
        log_error "失败的项目: ${failed_projects[*]}"
        if [ "$CONTINUE_ON_ERROR" = false ]; then
            exit 1
        fi
    fi
}

# 顺序部署函数
sequential_deploy() {
    local projects=("$@")
    local failed_projects=()
    
    log_info "开始顺序部署 ${#projects[@]} 个项目"
    
    for project in "${projects[@]}"; do
        if ! deploy_single_project "$project" "$ENVIRONMENT" "$BRANCH" "$CLEAN_CACHE" "$VERIFY_DEPLOYMENT" "$SKIP_BACKUP" "$SKIP_ARCHIVE"; then
            failed_projects+=("$project")
            if [ "$CONTINUE_ON_ERROR" = false ]; then
                log_error "部署失败，停止执行"
                exit 1
            fi
        fi
    done
    
    # 输出结果统计
    local success_count=$((${#projects[@]} - ${#failed_projects[@]}))
    local failed_count=${#failed_projects[@]}
    
    log_info "=== 批量部署完成 ==="
    log_info "成功: $success_count 个项目"
    log_info "失败: $failed_count 个项目"
    
    if [ ${#failed_projects[@]} -gt 0 ]; then
        log_error "失败的项目: ${failed_projects[*]}"
        exit 1
    fi
}

# 主函数
main() {
    log_info "=== 开始批量部署 ==="
    log_info "项目列表: $PROJECT_LIST"
    log_info "环境: $ENVIRONMENT"
    log_info "分支: $BRANCH"
    log_info "并行任务数: $PARALLEL_JOBS"
    
    # 检查必要命令
    check_command "git"
    check_command "npm"
    check_command "node"
    
    # 确保必要目录存在
    ensure_directory "$LOG_PATH"
    
    # 解析项目列表
    local projects=($(parse_project_list "$PROJECT_LIST"))
    
    if [ ${#projects[@]} -eq 0 ]; then
        log_error "没有找到有效的项目"
        exit 1
    fi
    
    log_info "将部署以下项目: ${projects[*]}"
    
    # 选择部署方式
    if [ ${#projects[@]} -eq 1 ] || [ "$PARALLEL_JOBS" -eq 1 ]; then
        sequential_deploy "${projects[@]}"
    else
        parallel_deploy "${projects[@]}"
    fi
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    parse_arguments "$@"
    main
fi
