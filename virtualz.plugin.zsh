#! /bin/zsh
#
# virtualz.plugin.zsh
# Copyright (C) 2016 Adrian Perez <aperez@igalia.com>
#
# Distributed under terms of the GPLv3 license.
#

: ${VIRTUALZ_HOME:=${HOME}/.virtualenvs}

typeset -gA _virtualz_cmd

vz () {
	if [[ $# -eq 0 || $1 = --help || $1 == -h ]] ; then
		vz help
		return
	fi

	local cmd=$1 fname="virtualz-$1"
	shift

	if typeset -fz "${fname}" ; then
		"${fname}" "$@"
	else
		echo "The subcommand '${cmd}' is not defined" 1>&2
	fi
}

_virtualz_cmd[activate]='Activate a virtualenv'
virtualz-activate () {
	if [[ $# -ne 1 ]] ; then
		echo 'No virtualenv specified.' 1>&2
		return 1
	fi

	local venv_path="${VIRTUALZ_HOME}/$1"
	if [[ ! -d ${venv_path} ]] ; then
		echo "The virtualenv '$1' does not exist." 1>&2
		return 2
	fi

	# If a virtualenv is in use, deactivate it first
	if [[ ${VIRTUAL_ENV:+set} = set ]] ; then
		virtualz-deactivate
	fi

	VIRTUAL_ENV_NAME=$1
	VIRTUAL_ENV=${venv_path}

	path=( "${VIRTUAL_ENV}/bin" "${path[@]}" )

	# Hide PYTHONHOME
	if [[ ${PYTHONHOME:+set} = set ]] ; then
		_VIRTUALZ_OLD_PYTHONHOME=${PYTHONHOME}
		unset PYTHONHOME
	fi
}

_virtualz_cmd[deactivate]='Deactivate the active virtualenv'
virtualz-deactivate () {
	if [[ ${VIRTUAL_ENV:+set} != set ]] ; then
		echo 'No virtualv is active.' 1>&2
		return 1
	fi

	# Remove element from $PATH
	local venv_bin="${VIRTUAL_ENV}/bin"
	local -a new_path=( )
	for path_item in "${path[@]}" ; do
		if [[ ${path_item} != ${venv_bin} ]] ; then
			new_path=( "${new_path[@]}" "${path_item}" )
		fi
	done
	path=( "${new_path[@]}" )

	# Restore PYTHONHOME
	if [[ ${_VIRTUALZ_OLD_PYTHONHOME:+set} = set ]] ; then
		export PYTHONHOME=${_VIRTUALZ_OLD_PYTHONHOME}
		unset _VIRTUALZ_OLD_PYTHONHOME
	fi

	unset VIRTUAL_ENV VIRTUAL_ENV_NAME
}

_virtualz_cmd[new]='Create a new virtualenv'
virtualz-new () {
	if [[ $# -lt 1 ]] ; then
		echo 'No virtualenv specified.' 1>&2
		return 1
	fi

	local venv_name=$1
	local venv_path="${VIRTUALZ_HOME}/${venv_name}"
	shift

	virtualenv "$@" "${venv_path}"
	local venv_status=$?

	if [[ ${venv_status} -eq 0 && -d ${venv_path} ]] ; then
		virtualz-activate "${venv_name}"
	else
		echo "virtualenv returned status ${venv_status}" 1>&2
		return ${venv_status}
	fi
}

_virtualz_cmd[rm]='Delete a virtualenv'
virtualz-rm () {
	if [[ $# -lt 1 ]] ; then
		echo 'No virtualenv specified.' 1>&2
		return 1
	fi
	if [[ ${VIRTUAL_ENV_NAME} = $1 ]] ; then
		echo 'Cannot delete virtualenv while in use' 1>&2
		return 2
	fi

	local venv_path="${VIRTUALZ_HOME}/$1"
	if [[ ! -d ${venv_path} ]] ; then
		echo "The virtualenv '$1' does not exist." 1>&2
		return 3
	fi

	rm -rf "${venv_path}"
}

_virtualz_cmd[ls]='List available virtualenvs'
virtualz-ls () {
	if [[ -d ${VIRTUALZ_HOME} ]] ; then
		pushd -q "${VIRTUALZ_HOME}"
		for item in */bin/python ; do
			echo "${item%/bin/python}"
		done
		popd -q
	fi
}

_virtualz_cmd[cd]='Change to the directory of the active virtualenv'
virtualz-cd () {
	if [[ ${VIRTUAL_ENV:+set} != set ]] ; then
		echo 'No virtualv is active.' 1>&2
		return 1
	fi
	cd "${VIRTUAL_ENV}"
}

_virtualz_cmd[help]='Show usage information'
virtualz-help () {
	cat <<-EOF
	Usage: vz <command> [<args>]

	Available commands:

	EOF
	for cmd in ${(k)_virtualz_cmd[@]} ; do
		printf "  %-12s %s\n" "${cmd}" "${_virtualz_cmd[${cmd}]}"
	done
	echo
}

readonly _virtualz_cmd
