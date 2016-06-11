#! /bin/zsh
#
# virtualz.plugin.zsh
# Copyright (C) 2016 Adrian Perez <aperez@igalia.com>
#
# Distributed under terms of the GPLv3 license.
#

: ${VIRTUALZ_HOME:=${HOME}/.virtualenvs}

typeset -gr _virtualz_dir=$(realpath "$(dirname "$0")")

vz () {
	if [[ $# -eq 0 || $1 = --help || $1 == -h ]] ; then
		vz help
		return
	fi

	local cmd=$1 fname="virtualz-$1"
	shift

	if typeset -fz "${fname}" ; then
		if [[ $1 == --help || $1 = -h ]] ; then
			vz help "${cmd}"
		else
			"${fname}" "$@"
		fi
	elif [[ -d ${VIRTUALZ_HOME}/${cmd} ]] ; then
		vz activate "${cmd}"
	else
		echo "The subcommand '${cmd}' is not defined" 1>&2
	fi
}

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

virtualz-deactivate () {
	if [[ ${VIRTUAL_ENV:+set} != set ]] ; then
		echo 'No virtualenv is active.' 1>&2
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

virtualz-ls () {
	if [[ -d ${VIRTUALZ_HOME} ]] ; then
		pushd -q "${VIRTUALZ_HOME}"
		for item in */bin/python ; do
			echo "${item%/bin/python}"
		done
		popd -q
	fi
}

virtualz-cd () {
	if [[ ${VIRTUAL_ENV:+set} != set ]] ; then
		echo 'No virtualenv is active.' 1>&2
		return 1
	fi
	cd "${VIRTUAL_ENV}"
}

virtualz-help () {
	if [[ $# -eq 0 || $1 = commands ]] ; then
		if [[ $# -eq 0 ]] ; then
			echo 'Usage: vz <command> [<args>]'
			echo
		fi
		echo 'Available commands:'
		echo
		for file in "${_virtualz_dir}"/doc/cmd-*.txt ; do
			local cmd=${file#*/cmd-}
			printf "  %-12s " "${cmd%.txt}"
			read -re < "${file}"
		done
		echo
	elif [[ $# -eq 1 && $1 = topics ]] ; then
		echo 'Available topics:'
		echo
		for file in "${_virtualz_dir}"/doc/topic-*.txt ; do
			local topic=${file#*/topic-}
			printf "  %-12s " "${topic%.txt}"
			read -re < "${file}"
		done
		echo
	elif [[ $# -eq 1 ]] ; then
		if [[ -r ${_virtualz_dir}/doc/cmd-$1.txt ]] ; then
			cat "${_virtualz_dir}/doc/cmd-$1.txt"
		elif [[ -r ${_virtualz_dir}/doc/topic-$1.txt ]] ; then
			cat "${_virtualz_dir}/doc/topic-$1.txt"
		else
			cat 1>&2 <<-EOF
			No such topic or command: $1
			Tip: use "vz help topics" for a list topics, or "vz help commands" for a list of commands.
			EOF
			return 1
		fi
	else
		echo 'Usage: vz <command> [<args>]' 1>&2
		return 1
	fi
}
