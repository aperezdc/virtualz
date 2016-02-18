# VirtualZ

A [Z shell](http://zsh.org) wrapper for Ian Bicking's [virtualenv](https://virtualenv.pypa.io/en/latest/), loosely based on Adam Brenecki's [virtualfish](https://github.com/adambrenecki) for the [Fish shell](http://fishshell.com).

## Quickstart

Once installed, VirtualZ provides the `vz` command. Try the following:

```
vz new myvirtualenv
echo ${VIRTUAL_ENV}
which python
vz new othervirtualenv
echo ${VIRTUAL_ENV}
vz deactivate
vz rm myvirtualenv
vz rm othervirtualenv
```
