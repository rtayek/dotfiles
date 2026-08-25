#!/bin/sh
set -eu

# Edit these three values for the browser window you want to open.
url_one='https://chatgpt.com'
url_two='https://github.com'
url_three='https://news.ycombinator.com'

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec "$script_dir/open-three-urls.sh" chrome "$url_one" "$url_two" "$url_three"
