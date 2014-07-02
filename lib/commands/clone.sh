#!/bin/bash

function clone {
	[[ ! $1 ]] && help_err clone
	local git_repo=$(git_shorthand "$1")
	local repo_path=$repos"/"$(repo_basename "$git_repo")
	pending 'clone' "$git_repo"
	test -e "$repo_path" && err $EX_ERR "$repo_path already exists"

	local git_out
	version_compare $GIT_VERSION 1.6.5
	if [[ $? != 2 ]]; then
		git_out=$(git clone --recursive "$git_repo" "$repo_path" 2>&1)
		[[ $? == 0 ]] || err $EX_SOFTWARE "Unable to clone $git_repo. Git says:" "$git_out"
		success
	else
		git_out=$(git clone "$git_repo" "$repo_path" 2>&1)
		[[ $? == 0 ]] || err $EX_SOFTWARE "Unable to clone $git_repo. Git says:" "$git_out"
		success

		pending 'submodules' "$git_repo"
		git_out=$(cd "$repo_path"; git submodule update --init 2>&1)
		[[ $? == 0 ]] || err $EX_SOFTWARE "Unable to clone submodules for $git_repo. Git says:" "$git_out"
		success
	fi
	return $EX_SUCCESS
}

function symlink_cloned_files {
	local cloned_castles=()
	while [[ $# -gt 0 ]]; do
		local git_repo=$(git_shorthand "$1")
		local castle=$(repo_basename "$git_repo")
		shift
		local repo="$repos/$castle"
		if [[ ! -d $repo/home ]]; then
			continue;
		fi
		local num_files=$(find "$repo/home" -mindepth 1 -maxdepth 1 | wc -l | tr -dc "0123456789")
		if [[ $num_files > 0 ]]; then
			cloned_castles+=("$castle")
		fi
	done
	ask_symlink ${cloned_castles[*]}
	return $EX_SUCCESS
}

# Convert username/repo into https://github.com/username/repo.git
function git_shorthand {
	if [[ $1 =~ \.git$ ]]; then
		printf -- "$1"
		return
	fi
	if [[ $1 =~ ^([0-9A-Za-z-]+/[0-9A-Za-z_\.-]+)$ ]]; then
		printf -- "https://github.com/$1.git"
		return
	fi
	printf -- "$1"
}

# Get the repo name from an URL
function repo_basename {
if [[ $1 =~ ^[^/:]+: ]]; then
	# For scp-style syntax like '[user@]host.xz:path/to/repo.git/',
	# remove the '[user@]host.xz:' part.
	basename "${1#*:}" .git
else
	basename "$1" .git
fi
}