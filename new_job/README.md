# 前端项目部署系统

这是一个优化的前端项目部署系统，从原来的SVN版本控制迁移到GitLab，并提供了更好的脚本结构和功能。

## 目录结构

```
new_job/
├── config/                 # 配置文件目录
│   ├── projects.conf       # 项目配置
│   ├── environments.conf   # 环境配置
│   └── paths.conf         # 路径配置
├── utils/                  # 工具函数库
│   ├── common.sh          # 通用工具函数
│   ├── gitlab.sh          # GitLab操作函数
│   └── build.sh           # 构建工具函数
├── scripts/                # 部署脚本目录
│   ├── deploy.sh          # 统一部署脚本
│   ├── batch_deploy.sh    # 批量部署脚本
│   ├── manage.sh          # 管理脚本
│   ├── pkg_ui.sh          # 批量打包脚本
│   └── [项目名]_[环境]_restart.sh  # 各项目部署脚本
└── README.md              # 说明文档
```

## 主要改进

### 1. 版本控制迁移
- **从SVN迁移到GitLab**: 所有项目现在使用GitLab进行版本控制
- **支持分支管理**: 可以指定不同的Git分支进行部署
- **自动更新**: 自动拉取最新代码或切换到指定分支

### 2. 脚本结构优化
- **模块化设计**: 将功能拆分为独立的工具函数库
- **配置驱动**: 通过配置文件管理项目和环境信息
- **统一接口**: 所有部署脚本使用统一的接口和参数

### 3. 功能增强
- **并行部署**: 支持多个项目并行部署，提高效率
- **错误处理**: 完善的错误处理和日志记录
- **备份机制**: 自动备份和恢复功能
- **健康检查**: 系统状态监控和健康检查
- **部署验证**: 部署后自动验证结果

### 4. 用户体验改进
- **彩色日志**: 使用颜色区分不同类型的日志信息
- **详细帮助**: 每个脚本都提供详细的帮助信息
- **进度显示**: 显示部署进度和状态信息
- **灵活配置**: 支持多种部署选项和参数

## 快速开始

### 1. 初始化环境

```bash
# 进入脚本目录
cd new_job/scripts

# 初始化部署环境
./manage.sh init
```

### 2. 配置GitLab

编辑 `config/paths.conf` 文件，设置GitLab连接信息：

```bash
# GitLab 配置
GITLAB_TOKEN="your_gitlab_token_here"
GITLAB_URL="https://gitlab.company.com"
```

### 3. 测试连接

```bash
# 测试GitLab连接
./manage.sh test
```

### 4. 部署单个项目

```bash
# 部署pc-cust项目到测试环境
./deploy.sh pc-cust test

# 部署pc-seller项目到生产环境，使用release分支
./deploy.sh pc-seller prod -b release-1.0

# 部署时清理缓存并验证结果
./deploy.sh pc-mgr ls_prod -c -v
```

### 5. 批量部署

```bash
# 部署所有项目到测试环境
./batch_deploy.sh all test

# 部署平台项目到生产环境，使用5个并行任务
./batch_deploy.sh platform prod -j 5

# 部署指定项目到联调环境
./batch_deploy.sh pc-cust,pc-mgr,pc-seller ls_prod
```

## 配置说明

### 项目配置 (config/projects.conf)

```
# 格式: 项目名|GitLab仓库URL|本地路径|构建命令|输出目录名
pc-cust|https://gitlab.company.com/frontend/pc-cust.git|/root/app/intellect-static/intellect-platform/platform-qqcharger/pc-cust|npm run build|pccust
```

### 环境配置 (config/environments.conf)

```
# 格式: 环境名|构建命令后缀|描述
test|--test|测试环境
prod|--prod|生产环境
ls_prod|--ls_prod|联调生产环境
```

### 路径配置 (config/paths.conf)

```
# 静态文件部署路径
STATIC_DEPLOY_PATH="/root/static/qqcharger"

# 日志文件路径
LOG_PATH="/var/log/deployment"

# 备份路径
BACKUP_PATH="/root/backup/static"
```

## 脚本使用说明

### 统一部署脚本 (deploy.sh)

```bash
./deploy.sh [选项] <项目名> [环境]

选项:
    -h, --help          显示帮助信息
    -b, --branch        指定Git分支
    -e, --environment   指定部署环境
    -c, --clean         清理构建缓存
    -v, --verify        验证部署结果
    -t, --tag           创建部署标签
    --no-backup         跳过备份
    --no-archive        跳过创建压缩包
```

### 批量部署脚本 (batch_deploy.sh)

```bash
./batch_deploy.sh [选项] <项目列表> [环境]

项目列表选项:
    all                 部署所有项目
    platform            部署平台相关项目
    standalone          部署独立项目
    <项目1,项目2,...>   指定项目列表
```

### 管理脚本 (manage.sh)

```bash
./manage.sh <命令> [选项]

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
```

### 批量打包脚本 (pkg_ui.sh)

```bash
./pkg_ui.sh [选项] [项目列表]

选项:
    -c, --clean         清理旧的压缩包
    -v, --verbose       显示详细信息
```

## 兼容性说明

为了保持与原有脚本的兼容性，新系统提供了对应的包装脚本：

- `pcachievements-ui_test_restart.sh` → 调用 `deploy.sh pc-achievements test`
- `pccust-ui_prod_restart.sh` → 调用 `deploy.sh pc-cust prod`
- `pcmgr-ui_test_restart.sh` → 调用 `deploy.sh pc-mgr test`
- 等等...

原有的调用方式仍然有效，但建议逐步迁移到新的统一接口。

## 日志和监控

### 日志文件

部署日志保存在 `$LOG_PATH` 目录下，按项目、环境和时间命名：

```
/var/log/deployment/deploy_pc-cust_test_20240101_120000.log
```

### 系统监控

使用管理脚本进行系统监控：

```bash
# 查看系统状态
./manage.sh status

# 健康检查
./manage.sh health

# 查看部署日志
./manage.sh logs
```

## 故障排除

### 常见问题

1. **GitLab连接失败**
   - 检查 `GITLAB_TOKEN` 和 `GITLAB_URL` 配置
   - 运行 `./manage.sh test` 测试连接

2. **项目部署失败**
   - 检查项目配置是否正确
   - 查看部署日志了解详细错误信息
   - 运行 `./manage.sh health` 进行健康检查

3. **权限问题**
   - 确保脚本有执行权限：`chmod +x *.sh`
   - 确保对部署目录有写权限

4. **构建失败**
   - 检查Node.js和npm版本
   - 清理构建缓存：`./deploy.sh <项目> <环境> -c`

### 获取帮助

每个脚本都提供详细的帮助信息：

```bash
./deploy.sh --help
./batch_deploy.sh --help
./manage.sh --help
```

## 迁移指南

### 从旧脚本迁移

1. **备份现有部署**
   ```bash
   ./manage.sh backup
   ```

2. **更新配置文件**
   - 根据实际环境修改 `config/paths.conf`
   - 更新 `config/projects.conf` 中的GitLab仓库地址

3. **测试新系统**
   ```bash
   ./manage.sh init
   ./manage.sh test
   ./deploy.sh pc-cust test
   ```

4. **逐步迁移**
   - 先在测试环境验证新脚本
   - 确认无误后迁移生产环境

## 维护和更新

### 定期维护

```bash
# 清理临时文件
./manage.sh clean

# 备份当前部署
./manage.sh backup

# 健康检查
./manage.sh health
```

### 更新配置

修改配置文件后，建议运行健康检查确认配置正确：

```bash
./manage.sh config
./manage.sh health
```

## 技术支持

如有问题，请：

1. 查看部署日志
2. 运行健康检查
3. 检查配置文件
4. 联系系统管理员

---

**注意**: 这是一个从SVN迁移到GitLab的优化版本，保持了原有功能的兼容性，同时提供了更好的可维护性和扩展性。
