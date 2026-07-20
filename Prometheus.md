---
title: Prometheus监控部署
published: 2026-07-14
description: 这次是云原生监控工具：Prometheus + Grafana
image: " "
tags: [linux, Prometheus, Grafana]
category: 学习笔记
draft: false
---

## Prometheus 组件介绍

Prometheus 是一款开源的云原生监控系统，整个监控体系由多个组件配合工作：

- **Prometheus Server**：核心服务，负责数据采集、存储和查询
- **Node Exporter**：部署在被监控机器上，采集主机硬件和系统指标
- **Alertmanager**：告警管理，负责处理告警通知
- **Grafana**：可视化面板，将 Prometheus 的数据以图表形式展示

[Prometheus GitHub](https://github.com/prometheus)

![Prometheus下载页面](image-20260707142935664.png)

## Prometheus 安装

去官网下载 Linux amd64 版本的二进制压缩包，解压到目标目录：

```bash
tar xzvf <压缩包>
```

给 root 权限：

```bash
chown -R root:root <文件路径>
```

### 后台启动演示

测试阶段可以先直接用 nohup 后台启动：

```bash
nohup /usr/local/prometheus/prometheus-3.13.0.linux-amd64/prometheus \
  --config.file=/usr/local/prometheus/prometheus-3.13.0.linux-amd64/prometheus.yml &
```

### 配置自启动（systemd）

生产环境建议配置成系统服务来实现自启动。

创建服务文件：

```bash
vi /etc/systemd/system/prometheus.service
```

写入以下内容：

```ini
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=root
Group=root
Type=simple
ExecStart=/usr/local/prometheus/prometheus-3.13.0.linux-amd64/prometheus \
    --config.file=/usr/local/prometheus/prometheus-3.13.0.linux-amd64/prometheus.yml \
    --storage.tsdb.path=/usr/local/prometheus/prometheus-3.13.0.linux-amd64/data

Restart=always

[Install]
WantedBy=multi-user.target
```

加载并启动服务：

```bash
# 让系统识别刚刚创建的 service 文件
systemctl daemon-reload

# 启动 Prometheus
systemctl start prometheus

# 设置开机自启动
systemctl enable prometheus

# 查看运行状态
systemctl status prometheus
```

## Node Exporter 部署

Node Exporter 负责采集被监控主机的指标数据，同样配置为系统服务。

创建服务文件：

```bash
vi /etc/systemd/system/node_exporter.service
```

写入以下内容：

```ini
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=root
Group=root
Type=simple
ExecStart=/usr/local/prometheus/node_exporter-1.11.1.linux-amd64/node_exporter

Restart=always

[Install]
WantedBy=multi-user.target
```

加载并启动服务：

```bash
# 重新加载 systemd 配置
systemctl daemon-reload

# 启动 node_exporter
systemctl start node_exporter

# 设置开机自启动
systemctl enable node_exporter

# 查看运行状态
systemctl status node_exporter
```

## Prometheus 配置文件

编辑 Prometheus 的 YAML 配置文件：

```bash
vi /usr/local/prometheus/prometheus-3.13.0.linux-amd64/prometheus.yml
```

以下是完整的配置示例：

```yaml
# ==========================================
# 全局配置 (Global Config)
# ==========================================
global:
  scrape_interval: 15s      # 抓取间隔：每 15 秒拉取一次数据
  evaluation_interval: 15s  # 评估间隔：每 15 秒计算一次告警规则
  scrape_timeout: 10s       # 抓取超时：超过 10 秒未拉取到数据则作废

# ==========================================
# 告警配置 (Alerting Config) - 暂不开启
# ==========================================
alerting:
  alertmanagers:
    - static_configs:
        - targets:
          # - localhost:9093  # 安装 Alertmanager 后取消注释

# ==========================================
# 告警规则文件路径 (Rule Files) - 暂不开启
# ==========================================
rule_files:
  # - "alert_rules.yml"     # 后续可配置具体的告警条件

# ==========================================
# 抓取任务配置 (Scrape Configs) - 核心部分
# ==========================================
scrape_configs:

  # 任务 1：监控 Prometheus 自身状态
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]
        labels:
          role: "monitor-center"    # 标签：监控中心

  # 任务 2：监控 Linux 服务器 (Node Exporter)
  - job_name: "linux_nodes"
    static_configs:
      - targets: ["localhost:9100"]
        labels:
          env: "lab"                # 标签：实验环境
          hostname: "debian-实验机"  # 标签：主机名，方便在网页上区分

      # 后续添加新机器按以下格式：
      # - targets: ["192.168.1.100:9100"]
      #   labels:
      #     env: "prod"
      #     hostname: "web-server-01"
```

### 配置文件检查与重载

Prometheus 自带 `promtool` 工具，可以用来校验配置文件格式：

```bash
/usr/local/prometheus/prometheus-3.13.0.linux-amd64/promtool check config \
  /usr/local/prometheus/prometheus-3.13.0.linux-amd64/prometheus.yml
```

重启服务加载新配置：

```bash
sudo systemctl restart prometheus
```

也可以使用热加载（需要在配置文件中开启该功能）：

```bash
curl -X POST http://localhost:9090/-/reload
```

## Grafana 可视化

### Grafana 安装

去 [Grafana 官网](https://grafana.com/grafana/download) 找到对应系统的下载地址，在服务器上安装：

```bash
sudo apt-get install -y adduser libfontconfig1 musl
wget https://dl.grafana.com/grafana-enterprise/release/13.1.0/grafana-enterprise_13.1.0_28013217238_linux_amd64.deb
sudo dpkg -i grafana-enterprise_13.1.0_28013217238_linux_amd64.deb
```

### 启动 Grafana

```bash
# 启动 Grafana
sudo systemctl start grafana-server

# 设置开机自启动
sudo systemctl enable grafana-server

# 查看状态（看到绿色的 active running 就可以了）
sudo systemctl status grafana-server
```

### 配置 Grafana

浏览器访问 `IP:3000`，默认账号密码都是 `admin`。

登录后可以在 Profile 里修改界面语言：

![Grafana语言设置](image-20260712164130211.png)

来到"连接 → 数据源"，把 Prometheus 添加进去：

![添加数据源](image-20260712164226316.png)

填写 Prometheus 的 URL 地址并保存。

### 导入仪表盘

去仪表盘页面新建或导入，可以到 [Grafana 官网仪表盘库](https://grafana.com/grafana/dashboards/) 找现成的模板：

![导入仪表盘](image-20260712164839363.png)

复制模板 ID 后回到 Grafana 导入，选择对应的 Prometheus 数据源即可。

## 常见问题排查

### 端口占用

日志报错：
```
listen tcp :9100: bind: address already in use
```

解决方法——找到占用进程后杀掉，重启服务：

```bash
sudo ss -tulnp | grep 9100
sudo kill <pid>
systemctl restart node_exporter
```

### 路径配置错误

日志报错：
```
No such file or directory
```

解决方法——确认绝对路径是否匹配：

```bash
# 进入目录确认路径
cd /usr/local/prometheus/node_exporter-1.11.1.linux-amd64
pwd

# 检查并修改服务文件中配置的路径
vi /etc/systemd/system/node_exporter.service

# 重新加载并重启
sudo systemctl daemon-reload
sudo systemctl restart node_exporter
```
