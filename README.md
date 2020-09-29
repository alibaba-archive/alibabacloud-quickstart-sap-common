English | [简体中文](README-CN.md)

<h1 align="center">sap-common</h1>

## Purpose

It is the core component,the general basic functions and Resource Orchestration Service(ROS) templates of the SAP automated installation tool,for installing S/4 HANA, SAP NetWeaver, SAP HANA systems.

## Directory Structure

```yaml
├── scripts # Scripts directory
│   ├── functions.sh # Basic script：Used to define log function, initialize the environment, download and decompress media, install and configure basic cloud resources,etc.
├── templates # ROS template directory
│   ├── CommonResources.json  # Optional ROS template：Used to create audit function, RDP machine,etc
│   |── Network_HA.json # ROS HA network template: Used to define VPC, business and heartbeat switch,etc.
│   │── Network_SingleNode.json # ROS single node network template: Used to define VPC,switch,etc.
```
## What solutions can be deployment

Using the SAP automated installation tool on Alibaba Cloud, you can deploy the following SAP solutions with one click:

1. SAP HANA single node and high availability deployment,please refer to：[alibabacloud-quickstart-sap-hana](https://github.com/aliyun/alibabacloud-quickstart-sap-hana)
2. SAP S/4 HANA single node and high availability deployment,please refer to：[alibabacloud-quickstart-sap-s4-hana](https://github.com/aliyun/alibabacloud-quickstart-sap-s4-hana)
3. SAP NetWeaver single node and high availability deployment,please refer to：[alibabacloud-quickstart-sap-netweaver](https://github.com/aliyun/alibabacloud-quickstart-sap-netweaver)