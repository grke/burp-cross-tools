function check_md5sum() {
	local package="$1"

	cd "$WORK_DIR/source"
	if md5sum -c $package.md5sum ; then
		echo "$package md5sum is correct."
		cd -
		return 0
	fi
	echo "$package md5sum is incorrect."
	cd -
	return 1
}

function maybe_download() {
	local package="$1"
	local url="$2"

	check_md5sum "$package" && return 0

	echo "Downloading from $url/$package"
	wget -O "$WORK_DIR/source/$package" "$url/$package"

	check_md5sum "$package" && return 0

	echo "Giving up."

	return 1
}

function extract() {
	local archive_name="$1"
	local archive_type=
	local path="$WORK_DIR/source/$archive_name"
	if [ ! -f "$path" ] ; then
		echo "$path does not exist" 1>&2
		exit 1
	fi
	[[ "$path" =~ ".bz2$" ]] && archive_type="j"
	[[ "$path" =~ ".gz$" ]] && archive_type="z"
	[[ "$path" =~ ".xz$" ]] && archive_type="J"
	tar -xv"$archive_type"f "$path"
}
