#!/bin/bash

# 构建工具函数库
# 作者: 系统管理员
# 日期: $(date +%Y-%m-%d)

# 加载通用函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# 加载配置文件
CONFIG_DIR="$(dirname "$SCRIPT_DIR")/config"
source "$CONFIG_DIR/paths.conf"

# 构建项目
build_project() {
    local project_path=$1
    local build_command=$2
    local environment=$3
    
    log_info "开始构建项目: $project_path"
    log_info "构建命令: $build_command"
    log_info "环境: $environment"
    
    # 检查项目目录
    if [ ! -d "$project_path" ]; then
        log_error "项目目录不存在: $project_path"
        return 1
    fi
    
    cd "$project_path" || return 1
    
    # 检查package.json
    if [ ! -f "package.json" ]; then
        log_error "package.json 不存在: $project_path"
        return 1
    fi
    
    # 安装依赖
    log_info "安装npm依赖..."
    npm install
    handle_error $? "npm install 失败"
    
    # 执行构建
    log_info "执行构建命令: $build_command"
    eval "$build_command"
    handle_error $? "构建失败"
    
    # 检查构建产物
    if [ ! -d "dist" ]; then
        log_error "构建产物目录 'dist' 不存在"
        return 1
    fi
    
    log_success "项目构建成功: $project_path"
    return 0
}

# 部署静态文件
deploy_static_files() {
    local source_path=$1
    local target_name=$2
    local environment=$3
    
    log_info "部署静态文件: $source_path -> $target_name"
    
    local target_path="${STATIC_DEPLOY_PATH}/${target_name}"
    local backup_path="${BACKUP_PATH}/${target_name}"
    
    # 备份现有文件
    if [ -d "$target_path" ]; then
        log_info "备份现有文件..."
        backup_directory "$target_path" "$backup_path"
    fi
    
    # 清理目标目录
    log_info "清理目标目录: $target_path"
    rm -rf "$target_path"
    
    # 复制新文件
    log_info "复制构建产物..."
    cp -r "$source_path" "$target_path"
    handle_error $? "复制文件失败"
    
    # 设置权限
    chmod -R 755 "$target_path"
    
    log_success "静态文件部署成功: $target_path"
    return 0
}

# 创建压缩包
create_archive() {
    local source_dir=$1
    local archive_name=$2
    local target_dir=$3
    
    log_info "创建压缩包: $archive_name"
    
    cd "$target_dir" || return 1
    
    # 删除旧的压缩包
    rm -f "${archive_name}.tar.gz"
    
    # 创建新的压缩包
    tar -zcvf "${archive_name}.tar.gz" "./${archive_name}/"
    handle_error $? "创建压缩包失败"
    
    # 显示压缩包信息
    local archive_size=$(du -h "${archive_name}.tar.gz" | cut -f1)
    log_success "压缩包创建成功: ${archive_name}.tar.gz (大小: $archive_size)"
    
    return 0
}

# 验证部署
verify_deployment() {
    local target_path=$1
    local expected_files=("index.html" "static")
    
    log_info "验证部署: $target_path"
    
    if [ ! -d "$target_path" ]; then
        log_error "部署目录不存在: $target_path"
        return 1
    fi
    
    for file in "${expected_files[@]}"; do
        if [ ! -e "$target_path/$file" ]; then
            log_warning "预期文件不存在: $target_path/$file"
        else
            log_info "✓ 文件存在: $file"
        fi
    done
    
    # 检查文件数量
    local file_count=$(find "$target_path" -type f | wc -l)
    log_info "部署文件总数: $file_count"
    
    if [ $file_count -gt 0 ]; then
        log_success "部署验证通过"
        return 0
    else
        log_error "部署验证失败: 没有找到任何文件"
        return 1
    fi
}

# 清理构建缓存
cleanup_build_cache() {
    local project_path=$1
    
    log_info "清理构建缓存: $project_path"
    
    cd "$project_path" || return 1
    
    # 清理node_modules（可选）
    if [ -d "node_modules" ]; then
        log_info "清理node_modules..."
        rm -rf node_modules
    fi
    
    # 清理npm缓存
    log_info "清理npm缓存..."
    npm cache clean --force
    
    log_success "构建缓存清理完成"
    return 0
}

# 获取构建信息
get_build_info() {
    local project_path=$1
    
    cd "$project_path" || return 1
    
    echo "=== 构建信息 ==="
    echo "项目路径: $project_path"
    echo "Node版本: $(node --version)"
    echo "NPM版本: $(npm --version)"
    echo "构建时间: $(date)"
    
    if [ -f "package.json" ]; then
        echo "项目名称: $(grep '"name"' package.json | cut -d'"' -f4)"
        echo "项目版本: $(grep '"version"' package.json | cut -d'"' -f4)"
    fi
    
    if [ -d "dist" ]; then
        echo "构建产物大小: $(du -sh dist | cut -f1)"
        echo "构建文件数量: $(find dist -type f | wc -l)"
    fi
}
