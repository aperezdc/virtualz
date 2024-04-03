#! /bin/zsh
#
# virtualz.plugin.zsh
# Copyright (C) 2016 Adrian Perez <aperez@igalia.com>
#
# Distributed under terms of the GPLv3 license.
#

: ${VIRTUALZ_HOME:=${HOME}/.virtualenvs}

typeset -gr _virtualz_dir=${0:A:h}

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
		return 1
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

	virtualz-venv "$@" "${venv_path}"
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

virtualz-_exists () {
	if [[ $# -lt 1 ]] ; then
		echo 'No virtualenv specified.' 1>&2
		return 1
	fi
	[[ -x ${VIRTUALZ_HOME}/$1/bin/python ]]
}

virtualz-cd () {
	if [[ ${VIRTUAL_ENV:+set} != set ]] ; then
		echo 'No virtualenv is active.' 1>&2
		return 1
	fi
	cd "${VIRTUAL_ENV}"
}

virtualz-current () { 
	if [[ ${VIRTUAL_ENV:+set} != set ]] ; then
		echo 'No virtualenv is active.' 1>&2
		return 1
	fi
	echo "${VIRTUAL_ENV_NAME}"
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

virtualz-_detect () {
	emulate -L zsh

	# Is _virtualz-venv already defined? Note that passing
	# -f/--force will remove the function and try anyway.
	#
	if [[ ${#_virtualz_venv_cmd[@]} -gt 0 ]] ; then
		if [[ $# -eq 1 && ( $1 = -f || $1 = --force ) ]] ; then
			typeset +r _virtualz_venv_cmd
			unset _virtualz_venv_cmd
		else
			return
		fi
	fi

	# Prefer to invoke virtualenv through the Python interpreter, now that
	# recent versions include the module as part of the standard library
	# even if there are no external commands.
	#
	local python
	while read -r python ; do
		# Check that we are really dealing with Python 3.x; this is needed
		# in case we are checking an unversioned binary that may be older.
		local python_version
		python_version=$("${python}" -c 'import sys; sys.stdout.write(sys.version[0])')
		[[ ${python_version} -ge 3 ]] || continue

		# Define the helper function, this is eval'd to make the full
		# path to the program be part of the function body.
		if "${python}" -m venv -h > /dev/null ; then
			typeset -gra _virtualz_venv_cmd=(command "${python}" -m venv)
			echo "Using '${_virtualz_venv_cmd[*]}'" 1>&2
			return
		fi
	done < <(builtin whence -p python3 python)

	# Fallback to finding an external command. In general, a versioned
	# command corresponding to Python 3 is preferred. Try to choose the most
	# likely binary that gives us what we want:
	#
	#   - Many systems have versioned "virtualenv2" and/or "virtualenv3".
	#   - A few systems have versioned "virtualenv-2" and/or "virtualenv-3".
	#   - Some systems have a plain "virtualenv" program, unversioned, which
	#     can be either Python 2 or Python 3.
	#
	local -a try_venv=(
		virtualenv3
		virtualenv-3
		virtualenv
		virtualenv2
		virtualenv-2
	)

	if [[ -n ${VIRTUALZ_VIRTUALENV:-} ]] ; then
		try_venv=( "${VIRTUALZ_VIRTUALENV}" "${try_venv[@]}" )
	fi

	local venv_cmd
	for venv_cmd in "${try_venv[@]}" ; do
		local venv_cmd_path=$(builtin whence -p "${venv_cmd}")
		if [[ -x ${venv_cmd_path} ]] ; then
			typeset -gra _virtualz_venv_cmd=(command "${venv_cmd_path}")
			echo "Using '${_virtualz_venv_cmd[*]}'" 1>&2
			return
		fi
	done

	echo 'No suitable virtualenv command found.' 1>&2
	typeset -gra _virtualz_venv_cmd=(false)
}

virtualz-venv () {
	emulate -L zsh
	virtualz-_detect
	"${_virtualz_venv_cmd[@]}" "$@"
}
