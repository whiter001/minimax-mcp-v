# 容器镜像监控地址汇总

> 来源：https://status.anye.xyz/
> 更新时间：2026-04-08

---

## Docker Hub

**描述**：Docker 官方镜像仓库，全球最大的容器镜像仓库，包含数百万个镜像

**监控站点总数**：28 | **正常运行**：21 | **响应缓慢**：1 | **离线数量**：6

### 在线镜像源列表

| 镜像名称 | URL | 标签 |
|---------|-----|------|
| Docker Hub (官方) | https://registry-1.docker.io | CloudFront |
| 腾讯云镜像仓库 | https://mirror.ccs.tencentyun.com | 腾讯云（仅限腾讯云内网） |
| 毫秒镜像（免费版） | https://docker.1ms.run | 木雷坞 CloudFlare |
| 毫秒镜像（付费版） | https://docker.1ms.run | 木雷坞 CDN（需登陆/高可用） |
| 1Panel | https://docker.1panel.live | 1Panel CloudFlare |
| CNIX Internal | https://docker.m.ixdev.cn | 国家(深圳·前海)新型互联网交换中心 Nginx 广东BGP |
| 耗子面板 | https://hub.rat.dev | 耗子面板 CloudFlare |
| 轩辕镜像（免费版） | https://docker.xuanyuan.me | 源码跳动 CloudFlare |
| 轩辕镜像（专业版） | https://docker.xuanyuan.run | 源码跳动 白山云 CDN（需登陆） |
| 轩辕镜像（专业版） | https://docker.xuanyuan.dev | 源码跳动 CloudFlare（需登陆） |
| DockerProxy | https://dockerproxy.net | DockerProxy Oracle CDN |
| 奶昔论坛 | https://docker-registry.nmqu.com | 奶昔论坛 CloudFlare |
| 爱铭网络 1 | https://hub.amingg.com | 爱铭网络 CloudFlare |
| 爱铭网络 2 | https://docker.amingg.com | 爱铭网络 CloudFlare |
| 厚浪云 | https://docker.hlmirror.com | 厚浪云 CloudFlare |
| 棉花云 1 | https://hub1.nat.tf | 美国西海岸节点 Nginx |
| 棉花云 2 | https://hub2.nat.tf | 香港BGP节点 Nginx |
| 棉花云 3 | https://hub3.nat.tf | 日本东京节点 Nginx |
| 棉花云 4 | https://hub4.nat.tf | 美国东海岸备用节点 Nginx |
| 天云港云 | https://run-docker.cn/ | 天云港云 CloudFlare |
| DaoCloud | https://docker.m.daocloud.io | DaoCloud 阿里云（限速） |
| 科技 lion | https://docker.kejilion.pro | 自媒体 UP 主 Nginx |
| 1Panel 三方镜像源 | https://docker.367231.xyz | 1Panel 核心用户 GXL 驱动 CloudFlare |
| 1Panel 三方镜像源 | https://hub.1panel.dev | 1Panel 核心用户无名驱动 CloudFlare |
| SUNBALCONY 1 | https://dockerproxy.cool | ipip.icu 博主 EdgeOne |
| apiba | https://docker.apiba.cn | apiba.cn CloudFlare |
| mxjia | https://proxy.vvvv.ee | NodeSeek大佬 Nginx |
| 飞牛 NAS | https://docker.fnnas.com | 飞牛 NAS Nginx（需登陆） |

### 推荐配置（daemon.json）

```json
{
  "registry-mirrors": [
    "https://docker.1ms.run",
    "https://docker.1panel.live",
    "https://hub.rat.dev",
    "https://dockerproxy.net",
    "https://docker-registry.nmqu.com"
  ]
}
```

---

## GitHub Container Registry (GHCR)

**描述**：GitHub 提供的容器镜像仓库，用于存储和分发 Docker 镜像

**监控站点总数**：8 | **正常运行**：7 | **响应缓慢**：0 | **离线数量**：1

### 在线镜像源列表

| 镜像名称 | URL | 标签 |
|---------|-----|------|
| GHCR (官方) | https://ghcr.io | Azure |
| 毫秒镜像（免费版） | https://ghcr.1ms.run | 木雷坞 CloudFlare |
| 毫秒镜像（付费版） | https://ghcr.1ms.run | 木雷坞 CDN（需登陆/高可用） |
| 南京大学 | https://ghcr.nju.edu.cn | 南大e-Science中心 南大教育网 |
| CNIX Internal | https://ghcr.m.ixdev.cn | 国家(深圳·前海)新型互联网交换中心 Nginx 广东BGP |
| 轩辕镜像（专业版） | https://xxx-ghcr.xuanyuan.run | 源码跳动 白山云 CDN（需登陆） |
| DockerProxy | https://ghcr.dockerproxy.net | DockerProxy Oracle CDN |
| DaoCloud | https://ghcr.m.daocloud.io | DaoCloud 阿里云（限速） |

> ⚠️ 注意：Docker 的 registry-mirrors 配置对 GHCR 不生效，请使用镜像前缀方式拉取

---

## Quay.io

**描述**：Red Hat 提供的容器镜像仓库，提供安全扫描和构建集成功能

**监控站点总数**：7 | **正常运行**：6 | **响应缓慢**：0 | **离线数量**：1

### 在线镜像源列表

| 镜像名称 | URL | 标签 |
|---------|-----|------|
| Quay (官方) | https://quay.io | CloudFront |
| 南京大学 | https://quay.nju.edu.cn | 南大e-Science中心 南大教育网 |
| CNIX Internal | https://quay.m.ixdev.cn | 国家(深圳·前海)新型互联网交换中心 Nginx 广东BGP |
| 毫秒镜像（付费版） | https://quay.1ms.run | 木雷坞 CDN（需登陆/高可用） |
| 轩辕镜像（专业版） | https://xxx-quay.xuanyuan.run | 源码跳动 白山云 CDN（需登陆） |
| DockerProxy | https://quay.dockerproxy.net | DockerProxy Oracle CDN |
| DaoCloud | https://quay.m.daocloud.io | DaoCloud 阿里云（限速） |

---

## Microsoft Container Registry (MCR)

**描述**：微软官方容器镜像仓库，提供 Windows 容器镜像和各种微软产品的容器版本

**监控站点总数**：6 | **正常运行**：5 | **响应缓慢**：0 | **离线数量**：1

### 在线镜像源列表

| 镜像名称 | URL | 标签 |
|---------|-----|------|
| MCR (官方) | https://mcr.microsoft.com | Azure |
| CNIX Internal | https://mcr.m.ixdev.cn | 国家(深圳·前海)新型互联网交换中心 Nginx 广东BGP |
| 毫秒镜像（付费版） | https://mcr.1ms.run | 木雷坞 CDN（需登陆/高可用） |
| 轩辕镜像（专业版） | https://xxx-mcr.xuanyuan.run | 源码跳动 白山云 CDN（需登陆） |
| DockerProxy | https://mcr.dockerproxy.net | DockerProxy Oracle CDN |
| DaoCloud | https://mcr.m.daocloud.io | DaoCloud 阿里云（限速） |

---

## Kubernetes Container Registry (K8s)

**描述**：Kubernetes 官方镜像仓库，存储 Kubernetes 组件的容器镜像

**监控站点总数**：7 | **正常运行**：6 | **响应缓慢**：0 | **离线数量**：1

### 在线镜像源列表

| 镜像名称 | URL | 标签 |
|---------|-----|------|
| K8s Registry (官方) | https://registry.k8s.io | Google Cloud |
| 南京大学 | https://k8s.nju.edu.cn | 南大e-Science中心 南大教育网 |
| CNIX Internal | https://k8s.m.ixdev.cn | 国家(深圳·前海)新型互联网交换中心 Nginx 广东BGP |
| 毫秒镜像（付费版） | https://k8s.1ms.run | 木雷坞 CDN（需登陆/高可用） |
| 轩辕镜像（专业版） | https://xxx-k8s.xuanyuan.run | 源码跳动 白山云 CDN（需登陆） |
| DockerProxy | https://k8s.dockerproxy.net | DockerProxy Oracle CDN |
| DaoCloud | https://k8s.m.daocloud.io | DaoCloud 阿里云（限速） |

---

## Google Container Registry (GCR)

**描述**：Google Cloud 提供的容器镜像仓库，支持私有和公共镜像

**监控站点总数**：6 | **正常运行**：6 | **响应缓慢**：0 | **离线数量**：0

### 在线镜像源列表

| 镜像名称 | URL | 标签 |
|---------|-----|------|
| GCR (官方) | https://gcr.io | Google Cloud |
| 南京大学 | https://gcr.nju.edu.cn | 南大e-Science中心 南大教育网 |
| DaoCloud | https://gcr.m.daocloud.io | DaoCloud 阿里云（限速） |
| 毫秒镜像（付费版） | https://gcr.1ms.run | 木雷坞 CDN（需登陆/高可用） |
| 轩辕镜像（专业版） | https://xxx-gcr.xuanyuan.run | 源码跳动 白山云 CDN（需登陆） |
| DockerProxy | https://gcr.dockerproxy.net | DockerProxy Oracle CDN |

---

## Elastic Container Registry

**描述**：Elastic 官方镜像仓库，提供 Elasticsearch、Kibana 等产品的容器镜像

**监控站点总数**：5 | **正常运行**：4 | **响应缓慢**：0 | **离线数量**：1

### 在线镜像源列表

| 镜像名称 | URL | 标签 |
|---------|-----|------|
| Elastic (官方) | https://docker.elastic.co | Google Cloud |
| CNIX Internal | https://elastic.m.ixdev.cn | 国家(深圳·前海)新型互联网交换中心 Nginx 广东BGP |
| DaoCloud | https://elastic.m.daocloud.io | DaoCloud 阿里云（限速） |
| 毫秒镜像（付费版） | https://elastic.1ms.run | 木雷坞 CDN（需登陆/高可用） |
| 轩辕镜像（专业版） | https://xxx-elastic.xuanyuan.run | 源码跳动 白山云 CDN（需登陆） |

---

## NVIDIA Container Registry (NVCR)

**描述**：NVIDIA 官方容器镜像仓库，提供 CUDA、TensorFlow 等 GPU 相关容器镜像

**监控站点总数**：6 | **正常运行**：5 | **响应缓慢**：0 | **离线数量**：1

### 在线镜像源列表

| 镜像名称 | URL | 标签 |
|---------|-----|------|
| NVCR (官方) | https://nvcr.io | CloudFront |
| 南京大学 | https://ngc.nju.edu.cn | 南大e-Science中心 南大教育网 |
| CNIX Internal | https://nvcr.m.ixdev.cn | 国家(深圳·前海)新型互联网交换中心 Nginx 广东BGP |
| 毫秒镜像（付费版） | https://nvcr.1ms.run | 木雷坞 CDN（需登陆/高可用） |
| 轩辕镜像（专业版） | https://xxx-nvcr.xuanyuan.run | 源码跳动 白山云 CDN（需登陆） |
| DaoCloud | https://nvcr.m.daocloud.io | DaoCloud 阿里云（限速） |

---

## 使用建议

1. **建议选择 3-5 个镜像源以保证稳定性**
2. 国内用户推荐使用：1Panel、DaoCloud、南京大学等国内镜像源
3. 部分镜像源需要登录才能使用完整功能
4. 定期检查 https://status.anye.xyz/ 获取最新状态

---

> 📌 网站来源：https://status.anye.xyz/
> © 2025 Anye. All Rights Reserved.
