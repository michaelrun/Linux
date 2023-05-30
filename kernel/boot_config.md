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
## make defconfig
