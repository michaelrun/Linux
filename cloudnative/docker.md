# Configure proxy for docker engine
Add below to /etc/docker/daemon.json
```

        "proxies": {
                "http-proxy": "http://child-prc.intel.com:913",
                "https-proxy": "http://child-prc.intel.com:913"
        }

}
```
validate the configuration:
```
dockerd --validate --config-file=/etc/docker/daemon.json
```
~/.docker/config.json is for docker client, set proxy:
```
        "proxies": {
                "default": {
                        "httpProxy": "http://proxy-prc.intel.com:912",
                        "httpsProxy": "http://proxy-prc.intel.com:912",
                        "noProxy": "127.0.0.1,localhost,intel.com",
                        "ftpProxy": "http://proxy-prc.intel.com:912"
                }
        }
```
