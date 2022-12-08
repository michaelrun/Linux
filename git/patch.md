# generate and apply git patch

`git diff` for unstaged changes.  

`git diff --cached` for staged changes.

`git diff HEAD` for both staged and unstaged changes.

If you haven't yet commited the changes, then:

    git diff > mypatch.patch

But sometimes it happens that part of the stuff you're doing are new files that are untracked and won't be in your `git diff` output. So, one way to do a patch is to stage everything for a new commit (`git add` each file, or just `git add .`) but don't do the commit, and then:

    git diff --cached > mypatch.patch

Add the 'binary' option if you want to add binary files to the patch (e.g. mp3 files):

    git diff --cached --binary > mypatch.patch

You can later apply the patch:

    git apply mypatch.patch

