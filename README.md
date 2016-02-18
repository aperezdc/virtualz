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


## Installation & Setup

The recommended way is to use a plugin manager. By default, the location where VirtualZ looks for virtualenvs is `~/.virtualenvs`. This can be changed by setting the desired path in the `${VIRTUALZ_HOME}` variable.

With [zgen](https://github.com/tarjoilija/zgen), add the following to your `.zshrc`:

```sh
zgen load aperezdc/virtualz
```
