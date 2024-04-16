# fix yum/dnf error1
```
[root@22867049419a yum.repos.d]# yum install centos-release-scl
Failed to set locale, defaulting to C.UTF-8
Last metadata expiration check: 0:00:14 ago on Tue Apr 16 01:22:23 2024.
Module yaml error: Unexpected key in data: static_context [line 9 col 3]
Module yaml error: Unexpected key in data: static_context [line 9 col 3]
Module yaml error: Unexpected key in data: static_context [line 9 col 3]
Module yaml error: Unexpected key in data: static_context [line 9 col 3]
Module yaml error: Unexpected key in data: static_context [line 9 col 3]
Module yaml error: Unexpected key in data: static_context [line 9 col 3]
Module yaml error: Unexpected key in data: static_context [line 9 col 3]
Module yaml error: Unexpected key in data: static_context [line 9 col 3]
No match for argument: centos-release-scl
Error: Unable to find a match: centos-release-scl
```
The solution turned out to be a simple one. Update the libmodulemd first to correct the problem then perform the dnf updates as usual.\
`dnf update libmodulemd`
