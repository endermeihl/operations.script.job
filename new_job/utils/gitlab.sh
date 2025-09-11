#!/bin/bash

# GitLab 操作工具函数库
# 作者: 系统管理员
# 日期: $(date +%Y-%m-%d)

# 加载通用函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# 加载配置文件
CONFIG_DIR="$(dirname "$SCRIPT_DIR")/config"
source "$CONFIG_DIR/paths.conf"

# GitLab API 函数
gitlab_api() {
    local method=$1
    local endpoint=$2
    local data=$3
    
    local url="${GITLAB_URL}/api/v4${endpoint}"
    local headers=(-H "PRIVATE-TOKEN: ${GITLAB_TOKEN}")
    
    if [ -n "$data" ]; then
        headers+=(-H "Content-Type: application/json")
        curl -s -X "$method" "${headers[@]}" -d "$data" "$url"
    else
        curl -s -X "$method" "${headers[@]}" "$url"
    fi
}

# 克隆或更新GitLab仓库
gitlab_clone_or_update() {
    local repo_url=$1
    local local_path=$2
    local branch=${3:-main}
    
    log_info "处理仓库: $repo_url"
    
    if [ -d "$local_path" ]; then
        # 目录存在，检查是否为Git仓库
        if validate_git_repo "$local_path"; then
            log_info "更新现有仓库: $local_path"
            cd "$local_path" || return 1
            
            # 检查是否有未提交的更改
            if ! check_uncommitted_changes "$local_path"; then
                log_warning "仓库有未提交的更改，正在暂存..."
                git stash push -m "Auto-stash before update $(date)"
            fi
            
            # 拉取最新代码
            git fetch origin
            handle_error $? "Git fetch 失败"
            
            git checkout "$branch"
            handle_error $? "Git checkout 失败"
            
            git pull origin "$branch"
            handle_error $? "Git pull 失败"
            
            log_success "仓库更新成功: $local_path"
        else
            log_error "目录存在但不是Git仓库: $local_path"
            return 1
        fi
    else
        # 目录不存在，克隆仓库
        log_info "克隆新仓库: $repo_url -> $local_path"
        ensure_directory "$(dirname "$local_path")"
        
        git clone -b "$branch" "$repo_url" "$local_path"
        handle_error $? "Git clone 失败"
        
        log_success "仓库克隆成功: $local_path"
    fi
}

# 获取仓库信息
get_repo_info() {
    local repo_path=$1
    cd "$repo_path" || return 1
    
    local current_branch=$(git branch --show-current)
    local last_commit=$(git log -1 --format="%h - %s (%an, %ar)")
    local remote_url=$(git remote get-url origin)
    
    echo "分支: $current_branch"
    echo "最新提交: $last_commit"
    echo "远程地址: $remote_url"
}

# 创建部署标签
create_deployment_tag() {
    local repo_path=$1
    local environment=$2
    local version=$3
    
    cd "$repo_path" || return 1
    
    local tag_name="deploy-${environment}-${version}-$(date +%Y%m%d-%H%M%S)"
    
    log_info "创建部署标签: $tag_name"
    git tag -a "$tag_name" -m "Deploy to $environment environment"
    handle_error $? "创建标签失败"
    
    git push origin "$tag_name"
    handle_error $? "推送标签失败"
    
    log_success "部署标签创建成功: $tag_name"
    echo "$tag_name"
}

# 检查GitLab连接
check_gitlab_connection() {
    log_info "检查GitLab连接..."
    
    local response=$(gitlab_api "GET" "/user")
    if echo "$response" | grep -q "id"; then
        local username=$(echo "$response" | grep -o '"username":"[^"]*"' | cut -d'"' -f4)
        log_success "GitLab连接成功，用户: $username"
        return 0
    else
        log_error "GitLab连接失败"
        echo "$response"
        return 1
    fi
}

# 获取项目信息
get_project_info() {
    local project_id=$1
    gitlab_api "GET" "/projects/$project_id"
}

# 触发CI/CD流水线
trigger_pipeline() {
    local project_id=$1
    local ref=$2
    local variables=$3
    
    local data="{\"ref\":\"$ref\""
    if [ -n "$variables" ]; then
        data="$data,\"variables\":$variables"
    fi
    data="$data}"
    
    gitlab_api "POST" "/projects/$project_id/pipeline" "$data"
}
