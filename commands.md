# check distribution of ubuntu
Change the "Distribution" to the codename of the version of Ubuntu you're using, e.g. focal in Ubuntu 20.04 or it's displayed by `lsb_release -sc`

# Find the Largest Top 10 Files and Directories On a Linux
`du -hsx * | sort -rh | head -10` \
1. du command -h option : Display sizes in human readable format (e.g., 1K, 234M, 2G).
2. du command -s option : It shows only a total for each argument (summary).
3. du command -x option : Skip directories on different file systems.
4. sort command -r option : Reverse the result of comparisons.
5. sort command -h option : It compares human readable numbers. This is GNU sort specific option only.
6. head command -10 OR -n 10 option : It shows the first 10 lines.
