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

	echo "Downloading from $url"
	wget -O "$WORK_DIR/source/$package" "$url"

	check_md5sum "$package" && return 0

	echo "Giving up."

	return 1
}

function extract() {
	local archive_name="$1"
	local path="$WORK_DIR/source/$archive_name"
	if [ ! -f "$path" ] ; then
		echo "$path does not exist" 1>&2
		exit 1
	fi

	echo "Extracting $path"

	[[ "$path" =~ bz2$ ]] && tar -jxf "$path" && return 0
	[[ "$path" =~ gz$ ]] && tar -zxf "$path" && return 0
	[[ "$path" =~ xz$ ]] && tar -Jxf "$path" && return 0
	[[ "$path" =~ zip$ ]] && unzip "$path" && return 0

	echo "Unable to extract $path"
	return 1
}
