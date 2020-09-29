[English](README.md) | 简体中文

<h1 align="center">sap-common</h1>

## 用途

SAP自动化安装部署工具中的通用基础功能以及资源编排（ROS）模版，是安装S/4 HANA、SAP NetWeaver、SAP HANA等系统的核心组件。

## 目录结构

```yaml
├── scripts # 脚本目录
│   ├── functions.sh # 基础脚本：用于定义日志，初始化环境，下载解压介质，安装配置基础云资源等基础功能
├── templates # ROS模板目录
│   ├── CommonResources.json  # 可选资源ROS模板：用于创建操作审计，RDP远程机等可选云资源
│   |── Network_HA.json # ROS高可用集群网络模版：VPC，业务以及心跳交换机等云资源
│   │── Network_SingleNode.json # ROS单节点网络模版：定义VPC，交换机等云资源
```
## 部署方案

在阿里云上使用SAP自动化安装部署工具可以一键部署如下SAP解决方案：

1. SAP HANA单节点以及高可用集群部署请参考：[alibabacloud-quickstart-sap-hana](https://github.com/aliyun/alibabacloud-quickstart-sap-hana)
2. SAP S/4 HANA单节点以及高可用集群部署请参考：[alibabacloud-quickstart-sap-s4-hana](https://github.com/aliyun/alibabacloud-quickstart-sap-s4-hana)
3. SAP NetWeaver单节点以及高可用集群部署请参考：[alibabacloud-quickstart-sap-netweaver](https://github.com/aliyun/alibabacloud-quickstart-sap-netweaver)