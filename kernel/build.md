# build kernel
Let's take lts-v5.4.102-yocto as an example.

step1: Download the kernel.

          wget  -c  https://github.com/intel/linux-intel-lts/archive/refs/tags/lts-v5.4.102-yocto-210310T010318Z.tar.gz

step2: Extract and enter the directory.

          tar -zxvf lts-v5.4.102-yocto-210310T010318Z.tar.gz && cd linux-intel-lts-lts-v5.4.102-yocto-210310T010318Z/

step3: Copy the default kernel config file of Ubuntu.

          cp /boot/config-5.4.0-66-generic .config

step4: make oldconfig, in this step, select the default value for all the options.

          make oldconfig

step5: build kernel.

          make -j8

step6: make  modules_install ,this step must add the parameter "INSTALL_MOD_STRIP=1", otherwise it will cause too large "initrd" to boot kernel.

          sudo make INSTALL_MOD_STRIP=1 modules_install

step7: install kernel.

          sudo make install

Then edit the Linux kernel boot option and add “i915.force_probe=* i915.enable_guc=2” to force GPU module probe.
![image](https://github.com/michaelrun/Linux/assets/19384327/135091c7-c276-4dfe-815e-6761388049c6)
How to solve the problem of "No rule to make target 'debian/canonical-certs.pem', needed by 'certs/x509_certificate_list' " while make?
![image](https://github.com/michaelrun/Linux/assets/19384327/66ada88e-de67-4e57-b11c-5c266460ca62)
Solution: open the. Config file and comment out the line

             CONFIG_SYSTEM_TRUSTED_KEYS="debian/certs/benh@debian.org.cert.pem"
How to solve the problem of “can't allocate initrd" and "Unable to mount root fs on unknown-bolck", while the system booting on tgl ?
The problem is that your initrd file is too large. If you want to solve this problem, you must must add the parameter "INSTALL_MOD_STRIP=1" like step6.
