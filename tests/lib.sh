require_command() {
	if ! command -v "$1" >/dev/null 2>&1; then
		printf '%s\n' "$1 is required for these tests." >&2
		exit 1
	fi
}

cleanup() {
	rm -rf "$tmp"
}

test_init() {
	require_command jq
	require_command lua
	require_command luac
	require_command expect
	require_command yazi

	tmp=${TMPDIR:-/tmp}/google-workspace-tests.$$
	bin=$tmp/bin
	cfg=$tmp/yazi-config
	home=$tmp/home
	log=$tmp/log
	pass_count=0
	fail_count=0

	trap cleanup EXIT HUP INT TERM

	mkdir -p "$bin" "$cfg" "$home" "$log"

	ORIGINAL_PATH=$PATH
	PATH=$bin:$ORIGINAL_PATH
	HOME=$home
	YAZI_CONFIG_HOME=$cfg
	TEST_LOG_DIR=$log
	export PATH HOME YAZI_CONFIG_HOME TEST_LOG_DIR
	unset YAZI_ID

	write_fake_url_opener
	write_fake_gog
	write_fake_gws
}

write_fake_url_opener() {
	cat >"$bin/fake-open" <<'SH'
#!/bin/sh
printf '%s\n' "$1" >>"$TEST_LOG_DIR/opened"
SH
	chmod +x "$bin/fake-open"
}

write_fake_gog() {
	cat >"$bin/gog" <<'SH'
#!/bin/sh
printf 'gog' >>"$TEST_LOG_DIR/gog"
for arg do
	printf '\t%s' "$arg" >>"$TEST_LOG_DIR/gog"
done
printf '\n' >>"$TEST_LOG_DIR/gog"

if [ "${1:-}" != "drive" ]; then
	printf '%s\n' "unexpected gog command" >&2
	exit 2
fi

case "${2:-}" in
	upload)
		shift 2
		file=
		name=
		replace=
		convert_to=
		while [ "$#" -gt 0 ]; do
			case "$1" in
				--replace)
					replace=$2
					shift 2
					;;
				--name)
					name=$2
					shift 2
					;;
				--convert-to)
					convert_to=$2
					shift 2
					;;
				--parent)
					shift 2
					;;
				--json | --results-only | --no-input)
					shift
					;;
				*)
					if [ -z "$file" ]; then
						file=$1
					fi
					shift
					;;
			esac
		done
		if [ -z "$name" ]; then
			name=${file##*/}
		fi
		if [ -z "$replace" ]; then
			id=uploaded-id
		else
			id=$replace
		fi
		jq -cn \
			--arg id "$id" \
			--arg name "$name" \
			--arg convert_to "$convert_to" \
			--arg url "https://drive.example/$name" \
			'{id: $id, name: $name, convert_to: $convert_to, webViewLink: $url, mimeType: "application/octet-stream"}'
		;;
	ls)
		if [ -n "${TEST_EXISTING_NAME:-}" ]; then
			jq -cn \
				--arg id "${TEST_EXISTING_ID:-existing-id}" \
				--arg name "$TEST_EXISTING_NAME" \
				'{files: [{id: $id, name: $name, trashed: false, webViewLink: "https://drive.example/existing"}]}'
		else
			printf '%s\n' '{"files":[]}'
		fi
		;;
	get)
		case "${3:-}" in
			folder-child)
				printf '%s\n' '{"id":"folder-child","name":"Invoices","mimeType":"application/vnd.google-apps.folder","parents":["folder-root"]}'
				;;
			folder-root)
				printf '%s\n' '{"id":"folder-root","name":"My Drive","mimeType":"application/vnd.google-apps.folder","parents":[]}'
				;;
			*)
				printf '%s\n' "unknown fake folder id: ${3:-}" >&2
				exit 2
				;;
		esac
		;;
	*)
		printf '%s\n' "unexpected gog drive command: ${2:-}" >&2
		exit 2
		;;
esac
SH
	chmod +x "$bin/gog"
}

write_fake_gws() {
	cat >"$bin/gws" <<'SH'
#!/bin/sh
printf 'gws' >>"$TEST_LOG_DIR/gws"
for arg do
	printf '\t%s' "$arg" >>"$TEST_LOG_DIR/gws"
done
printf '\n' >>"$TEST_LOG_DIR/gws"

if [ "${1:-}" != "drive" ] || [ "${2:-}" != "files" ]; then
	printf '%s\n' "unexpected gws command" >&2
	exit 2
fi

parse_json_arg() {
	key=$1
	shift
	while [ "$#" -gt 0 ]; do
		if [ "$1" = "$key" ]; then
			printf '%s\n' "$2"
			return 0
		fi
		shift
	done
	return 1
}

case "${3:-}" in
	create)
		metadata=$(parse_json_arg --json "$@") || metadata='{}'
		name=$(printf '%s\n' "$metadata" | jq -r '.name // "uploaded"')
		jq -cn --arg id uploaded-id --arg name "$name" --arg url "https://drive.example/$name" \
			'{id: $id, name: $name, webViewLink: $url, mimeType: "application/octet-stream"}'
		;;
	update)
		metadata=$(parse_json_arg --json "$@") || metadata='{}'
		params=$(parse_json_arg --params "$@") || params='{}'
		name=$(printf '%s\n' "$metadata" | jq -r '.name // "uploaded"')
		id=$(printf '%s\n' "$params" | jq -r '.fileId // "updated-id"')
		jq -cn --arg id "$id" --arg name "$name" --arg url "https://drive.example/$name" \
			'{id: $id, name: $name, webViewLink: $url, mimeType: "application/octet-stream"}'
		;;
	list)
		if [ -n "${TEST_EXISTING_NAME:-}" ]; then
			jq -cn \
				--arg id "${TEST_EXISTING_ID:-existing-id}" \
				--arg name "$TEST_EXISTING_NAME" \
				'{files: [{id: $id, name: $name, trashed: false, webViewLink: "https://drive.example/existing"}]}'
		else
			printf '%s\n' '{"files":[]}'
		fi
		;;
	get)
		params=$(parse_json_arg --params "$@") || params='{}'
		file_id=$(printf '%s\n' "$params" | jq -r '.fileId // empty')
		case "$file_id" in
			folder-child)
				printf '%s\n' '{"id":"folder-child","name":"Invoices","mimeType":"application/vnd.google-apps.folder","parents":["folder-root"]}'
				;;
			folder-root)
				printf '%s\n' '{"id":"folder-root","name":"My Drive","mimeType":"application/vnd.google-apps.folder","parents":[]}'
				;;
			*)
				printf '%s\n' "unknown fake folder id: $file_id" >&2
				exit 2
				;;
		esac
		;;
	*)
		printf '%s\n' "unexpected gws drive files command: ${3:-}" >&2
		exit 2
		;;
esac
SH
	chmod +x "$bin/gws"
}

reset_case() {
	rm -rf "$cfg" "$home" "$log"
	mkdir -p "$cfg" "$home" "$log"
	TEST_LOG_DIR=$log
	export TEST_LOG_DIR
	unset TEST_EXISTING_ID TEST_EXISTING_NAME
}

write_config() {
	upload_dir=$1
	drive_root=$2
	drive_cli=$3
	url_opener=$4
	convert=$5
	assume_yes=$6
	overwrite=$7

	{
		printf "GOOGLE_WORKSPACE_UPLOAD_DIR='%s'\n" "$upload_dir"
		printf "GOOGLE_WORKSPACE_DRIVE_ROOT='%s'\n" "$drive_root"
		printf "GOOGLE_WORKSPACE_DRIVE_CLI='%s'\n" "$drive_cli"
		printf "GOOGLE_WORKSPACE_URL_OPENER='%s'\n" "$url_opener"
		printf "GOOGLE_WORKSPACE_CONVERT='%s'\n" "$convert"
		printf "GOOGLE_WORKSPACE_ASSUME_YES='%s'\n" "$assume_yes"
		printf "GOOGLE_WORKSPACE_OVERWRITE_POLICY='%s'\n" "$overwrite"
	} >"$cfg/google-workspace.yazi.env"
}

run_capture() {
	stdout_path=$tmp/stdout
	stderr_path=$tmp/stderr
	"$@" >"$stdout_path" 2>"$stderr_path"
	cmd_status=$?
	cmd_stdout=$(cat "$stdout_path")
	cmd_stderr=$(cat "$stderr_path")
}

fail() {
	printf '%s\n' "  $1" >&2
	return 1
}

assert_status() {
	expected=$1
	if [ "$cmd_status" -ne "$expected" ]; then
		fail "expected status $expected, got $cmd_status; stderr: $cmd_stderr"
		return 1
	fi
	return 0
}

assert_eq() {
	expected=$1
	actual=$2
	label=$3
	if [ "$actual" != "$expected" ]; then
		fail "$label: expected '$expected', got '$actual'"
		return 1
	fi
	return 0
}

assert_contains() {
	haystack=$1
	needle=$2
	label=$3
	case "$haystack" in
		*"$needle"*)
			return 0
			;;
	esac
	fail "$label: expected to contain '$needle'; got '$haystack'"
	return 1
}

assert_not_contains() {
	haystack=$1
	needle=$2
	label=$3
	case "$haystack" in
		*"$needle"*)
			fail "$label: expected not to contain '$needle'; got '$haystack'"
			return 1
			;;
	esac
	return 0
}

file_contents() {
	if [ -f "$1" ]; then
		cat "$1"
	fi
}

register_test() {
	TESTS="$TESTS $1"
}

run_test() {
	name=$1
	printf '%s\n' "test: $name"
	if "$name"; then
		pass_count=$((pass_count + 1))
		printf '%s\n' "  ok"
	else
		fail_count=$((fail_count + 1))
		printf '%s\n' "  FAILED"
	fi
}

test_summary() {
	printf '%s\n' "tests complete: $pass_count passed, $fail_count failed"

	if [ "$fail_count" -ne 0 ]; then
		exit 1
	fi
}
