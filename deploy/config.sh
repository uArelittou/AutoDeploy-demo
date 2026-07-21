# config.sh —— 部署配置文件
# 作用：把「会变的东西」（镜像地址、端口、容器名）集中放这里
# 主脚本 deploy.sh 通过 source config.sh 读这些变量
# 好处：换服务器/换镜像/换端口，只改这里，deploy.sh 一行不动（配置与逻辑分离）


# 镜像地址（不含 tag，tag 在 deploy.sh 里动态拼，方便回滚到不同版本）
# 用南大加速源（官方 ghcr.io 国内拉不动）
# 注意：用户名强制小写 uarelittou，GHCR 规定
IMAGE=ghcr.nju.edu.cn/uarelittou/autodeploy-demo

# 对外暴露的端口（宿主机端口:容器端口）
# 8044 和 Dockerfile 里 EXPOSE 8044 一致
PORT=8044

# 容器名字，方便 stop/rm 时引用
# 不写名字的话 docker 会随机起名，你停不掉
CONTAINER=deploy-app

# 健康检查的探活次数和间隔
# 连续探 MAX_RETRIES 次，每次间隔 RETRY_INTERVAL 秒
# 全部失败才算应用挂了，触发回滚
# 避免应用刚启动那几秒没就绪就误判挂了
MAX_RETRIES=5
RETRY_INTERVAL=3

# 版本记录文件路径，存当前版本和上一版本，回滚时知道退到哪
# 放在项目文件夹同级，不在 git 仓库里，避免 git pull 冲突
# ${BASH_SOURCE[0]%/*} 是 deploy.sh 所在目录（项目内）
# ${...%/*} 再往上一级就是项目文件夹的父目录（项目同级）
# 文件名中文，更直观知道是啥
VERSIONS_FILE="${BASH_SOURCE[0]%/*}/../AutoDeploy-demo部署更新日志"
