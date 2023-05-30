# Kernel config
## make menuconfig
```
1. make menuconfig
2. scripts/kconfig/mconf  Kconfig, it souces many configs, one of them: crypto/Kconfig
3. crypto/Kconfig contains:
    menuconfig CRYPTO
            tristate "Cryptographic API"
    ...
    source "drivers/crypto/Kconfig"
    ...
4. drivers/crypto/Kconfig contains:
    menuconfig CRYPTO_HW
      bool "Hardware crypto devices"
      ...
      source "drivers/crypto/qat/Kconfig"
      ...
      
5. drivers/crypto/qat/Kconfig contains:
    config CRYPTO_DEV_QAT_4XXX
            tristate "Support for Intel(R) QAT_4XXX"
            depends on X86 && PCI
            select CRYPTO_DEV_QAT
            help
              Support for Intel(R) QuickAssist Technology QAT_4xxx
              for accelerating crypto and compression workloads.

              To compile this as a module, choose M here: the module
              will be called qat_4xxx.
```
relate source code to generate .config

                name = conf_get_configname();
                in = zconf_fopen(name); //name = .config
                if (in)
                        goto load; //if exists already, load it directly
                conf_set_changed(true);

                env = getenv("KCONFIG_DEFCONFIG_LIST"); //if .config doesn't exist, 
                
   KCONFIG_DEFCONFIG_LIST is set to: \
   `/lib/modules/5.18.0/.config /etc/kernel-config /boot/config-5.18.0 arch/x86/configs/x86_64_defconfig` \
   find sequentially until any one exists. 

## make defconfig

```
make defconfig
```


which config file is used during kernel build, please check: \
`/usr/src/kernels/linux-5.18/.config`  or `/lib/modules/5.18.0/build/.config` \

![image](https://github.com/michaelrun/Linux/assets/19384327/9a266c8f-6028-4f1e-a778-6e5e1f84d77f)


on one machine(41): \
![image](https://github.com/michaelrun/Linux/assets/19384327/2d97c2a4-b9e5-492e-a758-ebe9cfd79bac)

on another machine(21): \
![image](https://github.com/michaelrun/Linux/assets/19384327/dc57f670-e582-48c7-be17-90084e87725d)

