# Forward TCP Connections
```
cat /root/forward.sh
echo "Usage: ./forward.sh localIP localPort remoteIP remotePort"
if [ $# == 4 ]
then
echo iptables -t nat -A PREROUTING -d $1 -p tcp --dport $2 -j DNAT --to $3:$4
iptables -t nat -A PREROUTING -d $1 -p tcp --dport $2 -j DNAT --to $3:$4
echo iptables -t nat -A POSTROUTING -s $3 -p tcp --sport $4 -j SNAT --to $1:$2
iptables -t nat -A POSTROUTING -s $3 -p tcp --sport $4 -j SNAT --to $1:$2
else
echo "Parameter NOT correct!"
fi

```
