# sspanel shadowsocks-mod 安装脚本

## 特色

* 使用 [SSPanel-UIM 配套的 Shadowsocksr 后端程序](https://github.com/Anankke/shadowsocks-mod)，理论适配 SSPanelUIM为基础的所有 SSPanel 衍化版本
* 仅在 Debian 11 上进行测试，可能支持 Ubuntu 和 CentOS
* 只有安装，没有管理

## 安装
```
bash <(curl -sSL "https://raw.githubusercontent.com/TheOrdinaryWow/sspanel-setup-script/master/ssmod-install.sh")
```

## 相关指令

后端默认安装目录: `/usr/local/shadowsocks`

supervisor默认配置目录: `/etc/supervisor/conf.d/shadowsocks.conf （Centos:/etc/supervisord.conf）`

运行ssmod: `supervisorctl start shadowsocks-mod`
停止ssmod: `supervisorctl stop shadowsocks-mod`
查看ssmod状态: `supervisorctl status shadowsocks-mod`
重载supervisor配置文件: `supervisorctl update`

## ？

写到一半不想写了，sspanel不好用，弃坑，不过这repo还是能用的。

## Credit

* [SSR-manyuser_glzjin_shell](https://github.com/wulabing/SSR-manyuser_glzjin_shell)
* [shadowsocks-mod](https://github.com/Anankke/shadowsocks-mod)