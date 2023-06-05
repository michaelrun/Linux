# A Visual Guide to SSH Tunnels: Local and Remote Port Forwarding
![image](https://user-images.githubusercontent.com/19384327/227448925-f6c693da-ea1f-4757-acf3-6b71fe11705f.png)
https://iximiuz.com/en/posts/ssh-tunnels/ \
https://goteleport.com/blog/ssh-tunneling-explained/ \
https://www.ssh.com/academy/ssh/tunneling-example


## ssh command:
```
ssh -v -i ${DIR}/vm_ssh_test_key root@host -p 22 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=30 -o PreferredAuthentications=publickey phoronix-test-suite result-file-to-csv cpio && mv /root/cpio.csv /root/efi-large.csv && cat /root/efi-large.csv && sync && sleep 2
```
