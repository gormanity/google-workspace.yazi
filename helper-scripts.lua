return {
	open = [===[
#!/bin/sh

CONFIG_HOME=${YAZI_CONFIG_HOME:-"$HOME/.config/yazi"}
CONFIG_PATH=$CONFIG_HOME/google-workspace.yazi.env

if [ -f "$CONFIG_PATH" ]; then
	. "$CONFIG_PATH"
fi

ASSUME_YES=${GOOGLE_WORKSPACE_ASSUME_YES:-}
UPLOAD_DIR=${GOOGLE_WORKSPACE_UPLOAD_DIR:-}
CONVERT=${GOOGLE_WORKSPACE_CONVERT:-}
DRIVE_CLI=${GOOGLE_WORKSPACE_DRIVE_CLI:-auto}
URL_OPENER=${GOOGLE_WORKSPACE_URL_OPENER:-}
OPEN_URL=

while [ "$#" -gt 0 ]; do
	case "$1" in
		--assume-yes)
			ASSUME_YES=1
			shift
			;;
		--convert)
			CONVERT=1
			shift
			;;
		--upload-dir-id)
			if [ "$#" -lt 2 ]; then
				printf '%s\n' "--upload-dir-id requires a value" >&2
				exit 1
			fi
			UPLOAD_DIR=$2
			shift 2
			;;
		--drive-cli)
			if [ "$#" -lt 2 ]; then
				printf '%s\n' "--drive-cli requires a value" >&2
				exit 1
			fi
			DRIVE_CLI=$2
			shift 2
			;;
		--url-opener)
			if [ "$#" -lt 2 ]; then
				printf '%s\n' "--url-opener requires a value" >&2
				exit 1
			fi
			URL_OPENER=$2
			shift 2
			;;
		--url)
			if [ "$#" -lt 2 ]; then
				printf '%s\n' "--url requires a value" >&2
				exit 1
			fi
			OPEN_URL=$2
			shift 2
			;;
		--)
			shift
			break
			;;
		-*)
			printf '%s\n' "Unknown option: $1" >&2
			exit 1
			;;
		*)
			break
			;;
	esac
done

notify() {
	title=$1
	message=$2

	if command -v osascript >/dev/null 2>&1; then
		osascript \
			-e 'on run argv' \
			-e 'display notification item 2 of argv with title item 1 of argv' \
			-e 'end run' \
			"$title" "$message" >/dev/null 2>&1 && return 0
	fi

	if command -v notify-send >/dev/null 2>&1; then
		notify-send "$title" "$message" >/dev/null 2>&1 && return 0
	fi

	printf '%s: %s\n' "$title" "$message" >&2
}

confirm_upload() {
	name=${1##*/}

	if [ "$ASSUME_YES" = "1" ]; then
		return 0
	fi

	if command -v osascript >/dev/null 2>&1; then
		osascript \
			-e 'on run argv' \
			-e 'set fileName to item 1 of argv' \
			-e 'display dialog "Google Workspace cannot open this local file directly. Upload “" & fileName & "” to Google Drive?" with title "Google Workspace" buttons {"Cancel", "Upload"} default button "Upload" cancel button "Cancel"' \
			-e 'end run' \
			"$name" >/dev/null 2>&1
		return $?
	fi

	if command -v zenity >/dev/null 2>&1; then
		zenity --question --title="Google Workspace" --text="Upload $name to Google Drive?" >/dev/null 2>&1
		return $?
	fi

	if command -v kdialog >/dev/null 2>&1; then
		kdialog --title "Google Workspace" --yesno "Upload $name to Google Drive?" >/dev/null 2>&1
		return $?
	fi

	if [ -t 0 ]; then
		printf 'Upload %s to Google Drive? [y/N] ' "$name" >&2
		read answer
		case "$answer" in
			y | Y | yes | YES)
				return 0
				;;
		esac
	fi

	notify "Google Workspace" "Could not confirm upload. Add --assume-yes or install zenity/kdialog."
	return 1
}

extension() {
	name=${1##*/}
	ext=${name##*.}

	if [ "$name" = "$ext" ]; then
		return 1
	fi

	printf '%s\n' "$ext" | tr '[:upper:]' '[:lower:]'
}

workspace_url() {
	ext=$2

	if ! command -v jq >/dev/null 2>&1; then
		return 1
	fi

	url=$(jq -r '.url // empty' "$1" 2>/dev/null)
	if [ -n "$url" ]; then
		printf '%s\n' "$url"
		return 0
	fi

	doc_id=$(jq -r '.doc_id // empty' "$1" 2>/dev/null)
	if [ -z "$doc_id" ]; then
		return 1
	fi

	case "$ext" in
		gdoc)
			url=https://docs.google.com/document/d/$doc_id/edit
			;;
		gsheet)
			url=https://docs.google.com/spreadsheets/d/$doc_id/edit
			;;
		gslides)
			url=https://docs.google.com/presentation/d/$doc_id/edit
			;;
		*)
			url=https://drive.google.com/open?id=$doc_id
			;;
	esac

	resource_key=$(jq -r '.resource_key // empty' "$1" 2>/dev/null)
	if [ -n "$resource_key" ]; then
		case "$url" in
			*\?*)
				url=$url\&resourcekey=$resource_key
				;;
			*)
				url=$url\?resourcekey=$resource_key
				;;
		esac
	fi

	printf '%s\n' "$url"
}

open_url() {
	url=$1

	if [ -n "$URL_OPENER" ]; then
		"$URL_OPENER" "$url"
		return $?
	fi

	case "$(uname -s 2>/dev/null)" in
		Darwin)
			open "$url"
			return $?
			;;
	esac

	if command -v xdg-open >/dev/null 2>&1; then
		xdg-open "$url"
		return $?
	fi

	if command -v gio >/dev/null 2>&1; then
		gio open "$url"
		return $?
	fi

	printf '%s\n' "No URL opener found. Install xdg-open or gio." >&2
	return 1
}

target_mime() {
	case "$1" in
		doc | docx | odt | rtf)
			if [ "$CONVERT" = "1" ]; then
				printf '%s\n' "application/vnd.google-apps.document"
			else
				return 1
			fi
			;;
		odp | pot | potx | pps | ppsx | ppt | pptx)
			if [ "$CONVERT" = "1" ]; then
				printf '%s\n' "application/vnd.google-apps.presentation"
			else
				return 1
			fi
			;;
		ods | xls | xlsm | xlsx | xsv)
			if [ "$CONVERT" = "1" ]; then
				printf '%s\n' "application/vnd.google-apps.spreadsheet"
			else
				return 1
			fi
			;;
		*)
			return 1
			;;
	esac
}

target_kind() {
	case "$1" in
		application/vnd.google-apps.document)
			printf '%s\n' "doc"
			;;
		application/vnd.google-apps.presentation)
			printf '%s\n' "slides"
			;;
		application/vnd.google-apps.spreadsheet)
			printf '%s\n' "sheet"
			;;
		*)
			return 1
			;;
	esac
}

drive_cli() {
	case "$DRIVE_CLI" in
		gws)
			command -v gws >/dev/null 2>&1 && {
				printf '%s\n' "gws"
				return 0
			}
			notify "Google Workspace" "gws is not installed."
			return 1
			;;
		gog)
			command -v gog >/dev/null 2>&1 && {
				printf '%s\n' "gog"
				return 0
			}
			notify "Google Workspace" "gog is not installed."
			return 1
			;;
		auto)
			if command -v gws >/dev/null 2>&1; then
				printf '%s\n' "gws"
				return 0
			fi
			if command -v gog >/dev/null 2>&1; then
				printf '%s\n' "gog"
				return 0
			fi
			notify "Google Workspace" "Install googleworkspace-cli or gogcli and complete Drive auth first."
			return 1
			;;
		*)
			notify "Google Workspace" "Unsupported Drive CLI: $DRIVE_CLI"
			return 1
			;;
	esac
}

upload_with_gws() {
	path=$1
	ext=$2
	name=${path##*/}
	stem=${name%.*}
	dir=${path%/*}
	target=$(target_mime "$ext") || target=

	if [ -n "$UPLOAD_DIR" ] && [ -n "$target" ]; then
		metadata=$(jq -cn --arg name "$stem" --arg mimeType "$target" --arg parent "$UPLOAD_DIR" '{name: $name, mimeType: $mimeType, parents: [$parent]}')
	elif [ -n "$UPLOAD_DIR" ]; then
		metadata=$(jq -cn --arg name "$name" --arg parent "$UPLOAD_DIR" '{name: $name, parents: [$parent]}')
	elif [ -n "$target" ]; then
		metadata=$(jq -cn --arg name "$stem" --arg mimeType "$target" '{name: $name, mimeType: $mimeType}')
	else
		metadata=$(jq -cn --arg name "$name" '{name: $name}')
	fi
	params='{"fields":"id,name,mimeType,webViewLink"}'
	if [ "$dir" = "$path" ]; then
		dir=.
	fi

	cd "$dir" && gws drive files create --params "$params" --json "$metadata" --upload "$name"
}

upload_with_gog() {
	path=$1
	ext=$2
	name=${path##*/}
	stem=${name%.*}
	target=$(target_mime "$ext") || target=

	set -- drive upload "$path" --json --results-only --no-input
	if [ -n "$UPLOAD_DIR" ]; then
		set -- "$@" --parent "$UPLOAD_DIR"
	fi
	if [ -n "$target" ] && kind=$(target_kind "$target"); then
		set -- "$@" --convert-to "$kind" --name "$stem"
	elif [ "$name" != "$stem" ]; then
		set -- "$@" --name "$name"
	fi

	gog "$@"
}

json_field() {
	jq -r "$1 // .result$1 // .data$1 // empty"
}

upload_and_open() {
	path=$1
	ext=$2
	target=$(target_mime "$ext") || target=
	cli=$(drive_cli) || return 1

	if ! command -v jq >/dev/null 2>&1; then
		notify "Google Workspace" "jq is required to build and parse Drive JSON responses."
		return 1
	fi

	result=$(upload_with_"$cli" "$path" "$ext" 2>&1)
	code=$?

	if [ "$code" -ne 0 ]; then
		printf '%s\n' "$result" >&2
		notify "Google Workspace" "Upload failed. Check $cli authentication and Drive permissions."
		return 1
	fi

	json=$(printf '%s\n' "$result" | sed -n '/^{/,$p')
	if ! printf '%s\n' "$json" | jq -e . >/dev/null 2>&1; then
		printf '%s\n' "$result" >&2
		notify "Google Workspace" "Upload succeeded, but the Drive CLI returned an unreadable response."
		return 1
	fi

	url=$(printf '%s\n' "$json" | json_field ".webViewLink")
	id=$(printf '%s\n' "$json" | json_field ".id")

	if [ -z "$url" ] && [ -n "$id" ] && [ -n "$target" ]; then
		case "$target" in
			application/vnd.google-apps.document)
				url="https://docs.google.com/document/d/$id/edit"
				;;
			application/vnd.google-apps.presentation)
				url="https://docs.google.com/presentation/d/$id/edit"
				;;
			application/vnd.google-apps.spreadsheet)
				url="https://docs.google.com/spreadsheets/d/$id/edit"
				;;
		esac
	fi

	if [ -z "$url" ] && [ -n "$id" ]; then
		url="https://drive.google.com/file/d/$id/view"
	fi

	if [ -z "$url" ]; then
		notify "Google Workspace" "Upload succeeded, but no openable URL was returned."
		return 1
	fi

	open_url "$url"
}

if [ "$#" -eq 0 ]; then
	if [ -n "$OPEN_URL" ]; then
		open_url "$OPEN_URL"
		exit $?
	fi

	notify "Google Workspace" "No file was provided."
	exit 1
fi

status=0

for path do
	ext=$(extension "$path") || ext=

		case "$ext" in
			gdoc | gdraw | gform | glink | gmap | gsheet | gsite | gslides)
				url=$(workspace_url "$path" "$ext")
			if [ -n "$url" ]; then
				open_url "$url" || status=1
			else
				open_url "$path" || status=1
			fi
			;;
		doc | docx | odp | ods | odt | pot | potx | pps | ppsx | ppt | pptx | rtf | xls | xlsm | xlsx | xsv)
			if confirm_upload "$path"; then
				upload_and_open "$path" "$ext" || status=1
			else
				status=1
			fi
			;;
		*)
			if [ -f "$path" ]; then
				if confirm_upload "$path"; then
					upload_and_open "$path" "$ext" || status=1
				else
					status=1
				fi
			else
				notify "Google Workspace" "Unsupported path: $(basename "$path")"
				status=1
			fi
			;;
	esac
done

exit "$status"
]===],
	resolve_upload_dir = [===[
#!/bin/sh

config_home=${YAZI_CONFIG_HOME:-"$HOME/.config/yazi"}
config_path=$config_home/google-workspace.yazi.env

if [ -f "$config_path" ]; then
	. "$config_path"
fi

folder_id=${GOOGLE_WORKSPACE_UPLOAD_DIR:-}
drive_root=${GOOGLE_WORKSPACE_DRIVE_ROOT:-}
drive_cli=${GOOGLE_WORKSPACE_DRIVE_CLI:-auto}

while [ "$#" -gt 0 ]; do
	case "$1" in
		--upload-dir-id)
			if [ "$#" -lt 2 ]; then
				printf '%s\n' "--upload-dir-id requires a value" >&2
				exit 1
			fi
			folder_id=$2
			shift 2
			;;
		--drive-root)
			if [ "$#" -lt 2 ]; then
				printf '%s\n' "--drive-root requires a value" >&2
				exit 1
			fi
			drive_root=$2
			shift 2
			;;
		--drive-cli)
			if [ "$#" -lt 2 ]; then
				printf '%s\n' "--drive-cli requires a value" >&2
				exit 1
			fi
			drive_cli=$2
			shift 2
			;;
		--)
			shift
			break
			;;
		-*)
			printf '%s\n' "Unknown option: $1" >&2
			exit 1
			;;
		*)
			break
			;;
	esac
done

expand_path() {
	case "$1" in
		\~)
			printf '%s\n' "$HOME"
			;;
		\~/*)
			printf '%s\n' "$HOME/${1#\~/}"
			;;
		'$HOME')
			printf '%s\n' "$HOME"
			;;
		'$HOME'/*)
			printf '%s\n' "$HOME/${1#\$HOME/}"
			;;
		'${HOME}')
			printf '%s\n' "$HOME"
			;;
		'${HOME}'/*)
			printf '%s\n' "$HOME/${1#\$\{HOME\}/}"
			;;
		*)
			printf '%s\n' "$1"
			;;
	esac
}

local_drive_root() {
	if [ -n "$drive_root" ]; then
		root=$(expand_path "$drive_root")
		if [ -d "$root" ]; then
			printf '%s\n' "$root"
			return 0
		fi

		printf '%s\n' "Configured local Drive root does not exist: $root" >&2
		return 1
	fi

	root=$HOME/Google\ Drive/My\ Drive
	if [ -d "$root" ]; then
		printf '%s\n' "$root"
		return 0
	fi

	root=$HOME/Google\ Drive
	if [ -d "$root" ]; then
		printf '%s\n' "$root"
		return 0
	fi

	case "$(uname -s 2>/dev/null)" in
		Darwin)
			for root in "$HOME"/Library/CloudStorage/GoogleDrive-*/My\ Drive; do
				if [ -d "$root" ]; then
					printf '%s\n' "$root"
					return 0
				fi
			done

			printf '%s\n' "Could not find local Google Drive root. Configure drive_root in init.lua." >&2
			;;
		*)
			printf '%s\n' "Could not find local Google Drive root. Configure drive_root in init.lua." >&2
			;;
	esac

	return 1
}

if [ -z "$folder_id" ]; then
	local_drive_root
	exit $?
fi

if ! command -v jq >/dev/null 2>&1; then
	printf '%s\n' "jq is not installed." >&2
	exit 1
fi

drive_cli() {
	case "$drive_cli" in
		gws)
			command -v gws >/dev/null 2>&1 && {
				printf '%s\n' "gws"
				return 0
			}
			printf '%s\n' "gws is not installed." >&2
			return 1
			;;
		gog)
			command -v gog >/dev/null 2>&1 && {
				printf '%s\n' "gog"
				return 0
			}
			printf '%s\n' "gog is not installed." >&2
			return 1
			;;
		auto)
			if command -v gws >/dev/null 2>&1; then
				printf '%s\n' "gws"
				return 0
			fi
			if command -v gog >/dev/null 2>&1; then
				printf '%s\n' "gog"
				return 0
			fi
			printf '%s\n' "Install googleworkspace-cli or gogcli and complete Drive auth first." >&2
			return 1
			;;
		*)
			printf '%s\n' "Unsupported Drive CLI: $drive_cli" >&2
			return 1
			;;
	esac
}

drive_get() {
	case "$1" in
		gws)
			params=$(jq -cn --arg fileId "$2" '{fileId: $fileId, fields: "id,name,parents,mimeType"}')
			gws drive files get --params "$params"
			;;
		gog)
			gog drive get "$2" --fields "id,name,parents,mimeType" --json --results-only --no-input
			;;
	esac
}

json_field() {
	jq -r "$1 // .result$1 // .data$1 // empty"
}

cli=$(drive_cli) || exit 1
names=
current=$folder_id

while [ -n "$current" ]; do
	result=$(drive_get "$cli" "$current" 2>&1) || {
		printf '%s\n' "$result" >&2
		exit 1
	}

	json=$(printf '%s\n' "$result" | sed -n '/^{/,$p')
	if ! printf '%s\n' "$json" | jq -e . >/dev/null 2>&1; then
		printf '%s\n' "$result" >&2
		exit 1
	fi

	mime_type=$(printf '%s\n' "$json" | json_field ".mimeType")
	name=$(printf '%s\n' "$json" | json_field ".name")
	parent=$(printf '%s\n' "$json" | jq -r '.parents[0] // .result.parents[0] // .data.parents[0] // empty')

	if [ "$current" = "$folder_id" ] && [ "$mime_type" != "application/vnd.google-apps.folder" ]; then
		printf '%s\n' "Configured Google Drive upload ID does not point to a Drive folder." >&2
		exit 1
	fi

	if [ -z "$name" ] || [ "$name" = "My Drive" ]; then
		break
	fi

	if [ -z "$names" ]; then
		names=$name
	else
		names=$name/$names
	fi

	current=$parent
done

root=$(local_drive_root) || exit $?
path=$root
if [ -n "$names" ]; then
	path=$path/$names
fi

if [ -d "$path" ]; then
	printf '%s\n' "$path"
	exit 0
fi

printf '%s\n' "Could not find the Drive folder locally. Confirm your Drive sync folder or mount is available." >&2
exit 1
]===],
}
