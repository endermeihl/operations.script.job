#!/bin/bash

# 批量打包脚本
# 作者: 系统管理员
# 日期: $(date +%Y-%m-%d)
# 描述: 批量创建多个项目的压缩包

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
用法: $0 [选项] [项目列表]

选项:
    -h, --help          显示此帮助信息
    -c, --clean         清理旧的压缩包
    -v, --verbose       显示详细信息

项目列表选项:
    all                 打包所有项目
    platform            打包平台相关项目 (pcseller, pcmgr, pclec, pccust)
    <项目1,项目2,...>   指定项目列表，用逗号分隔

示例:
    $0 all                    # 打包所有项目
    $0 platform               # 打包平台项目
    $0 pcseller,pcmgr,pclec   # 打包指定项目

EOF
}

# 解析命令行参数
parse_arguments() {
    PROJECT_LIST="all"
    CLEAN_OLD=false
    VERBOSE=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -c|--clean)
                CLEAN_OLD=true
                shift
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
                PROJECT_LIST="$1"
                shift
                ;;
        esac
    done
}

# 解析项目列表
parse_project_list() {
    local project_list=$1
    local projects=()
    
    case $project_list in
        "all")
            projects=("pcseller" "pcmgr" "pclec" "pccust" "pcachievements" "pcopr" "pcrouter" "pcscs")
            ;;
        "platform")
            projects=("pcseller" "pcmgr" "pclec" "pccust")
            ;;
        *)
            # 逗号分隔的项目列表
            IFS=',' read -ra projects <<< "$project_list"
            ;;
    esac
    
    echo "${projects[@]}"
}

# 创建单个项目的压缩包
create_project_archive() {
    local project_name=$1
    local source_dir="${STATIC_DEPLOY_PATH}/${project_name}"
    local target_dir="$STATIC_DEPLOY_PATH"
    
    if [ ! -d "$source_dir" ]; then
        log_warning "项目目录不存在，跳过: $source_dir"
        return 1
    fi
    
    log_info "创建压缩包: $project_name"
    
    cd "$target_dir" || return 1
    
    # 删除旧的压缩包
    if [ -f "${project_name}.tar.gz" ]; then
        rm -f "${project_name}.tar.gz"
        if [ "$VERBOSE" = true ]; then
            log_info "删除旧压缩包: ${project_name}.tar.gz"
        fi
    fi
    
    # 创建新的压缩包
    if [ "$VERBOSE" = true ]; then
        tar -zcvf "${project_name}.tar.gz" "./${project_name}/"
    else
        tar -zcf "${project_name}.tar.gz" "./${project_name}/"
    fi
    
    if [ $? -eq 0 ]; then
        local archive_size=$(du -h "${project_name}.tar.gz" | cut -f1)
        log_success "压缩包创建成功: ${project_name}.tar.gz (大小: $archive_size)"
        return 0
    else
        log_error "压缩包创建失败: $project_name"
        return 1
    fi
}

# 清理旧的压缩包
cleanup_old_archives() {
    log_info "清理旧的压缩包..."
    
    cd "$STATIC_DEPLOY_PATH" || return 1
    
    local old_archives=$(find . -name "*.tar.gz" -mtime +7 2>/dev/null || true)
    
    if [ -n "$old_archives" ]; then
        echo "$old_archives" | while read -r archive; do
            log_info "删除旧压缩包: $archive"
            rm -f "$archive"
        done
        log_success "旧压缩包清理完成"
    else
        log_info "没有找到需要清理的旧压缩包"
    fi
}

# 显示压缩包统计信息
show_archive_stats() {
    log_info "=== 压缩包统计信息 ==="
    
    cd "$STATIC_DEPLOY_PATH" || return 1
    
    local total_size=0
    local archive_count=0
    
    for archive in *.tar.gz; do
        if [ -f "$archive" ]; then
            local size=$(du -b "$archive" | cut -f1)
            local size_human=$(du -h "$archive" | cut -f1)
            total_size=$((total_size + size))
            archive_count=$((archive_count + 1))
            
            if [ "$VERBOSE" = true ]; then
                log_info "  $archive: $size_human"
            fi
        fi
    done
    
    local total_size_human=$(numfmt --to=iec $total_size)
    log_info "总计: $archive_count 个压缩包，总大小: $total_size_human"
}

# 主函数
main() {
    log_info "=== 开始批量打包 ==="
    log_info "项目列表: $PROJECT_LIST"
    
    # 确保目录存在
    ensure_directory "$STATIC_DEPLOY_PATH"
    
    # 清理旧的压缩包
    if [ "$CLEAN_OLD" = true ]; then
        cleanup_old_archives
    fi
    
    # 解析项目列表
    local projects=($(parse_project_list "$PROJECT_LIST"))
    
    if [ ${#projects[@]} -eq 0 ]; then
        log_error "没有找到有效的项目"
        exit 1
    fi
    
    log_info "将打包以下项目: ${projects[*]}"
    
    # 创建压缩包
    local success_count=0
    local failed_count=0
    local failed_projects=()
    
    for project in "${projects[@]}"; do
        if create_project_archive "$project"; then
            ((success_count++))
        else
            ((failed_count++))
            failed_projects+=("$project")
        fi
    done
    
    # 显示统计信息
    show_archive_stats
    
    # 输出结果
    log_info "=== 批量打包完成 ==="
    log_info "成功: $success_count 个项目"
    log_info "失败: $failed_count 个项目"
    
    if [ ${#failed_projects[@]} -gt 0 ]; then
        log_error "失败的项目: ${failed_projects[*]}"
        exit 1
    fi
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    parse_arguments "$@"
    main
fi
