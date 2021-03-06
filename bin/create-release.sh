#!/usr/bin/env bash
set -o errexit
set -o nounset

ROOT="$( unset CDPATH ; cd "$( dirname "${BASH_SOURCE[0]}" )/../" && pwd )"

if [[ $# -lt 2 || -z "${1:-}" || -z "${2:-}" ]]; then
  cat <<HELP
  Usage: create-release.sh <RELEASE_PATH> <RELEASE_NAME>"
  RELEASE_PATH must be relative to the root of the infrastructure
HELP
  exit 1
fi

release_path="$1"
release_name="$2"

ensure_valid_dev_build_index() {
	local dev_build_dir="$1"
	local cache_dir="$2"

	if [[ ! -e "${dev_build_dir}" ]]
	then
		return
	fi

	local indexes=$(find "${dev_build_dir}" -name index.yml)

	for index in ${indexes}
	do
		local sha1=$(awk '/sha1/ {print $2}' < "${index}")
		if [[ ! -e "${cache_dir}/${sha1}" ]]
		then
			rm "${index}"
		fi
	done
}

stampy "${ROOT}/scf_metrics.csv" "${BASH_SOURCE[0]}" "create-release::${release_name}" start

mkdir -p "${FISSILE_CACHE_DIR}"

# bosh create release calls `git status` (twice), but we don't need to
# know if the repo is dirty, so stub it out.

# import proxy information, if any, what there is.
# Note, the http:// schema prefix is intentional.
# Most of our bosh releases apparently do not understand the form without it.
proxies=
MO=
for var in http_proxy https_proxy no_proxy HTTP_PROXY HTTPS_PROXY NO_PROXY ; do
  if test -n "${!var:-}" ; then

      # Notes
      # - Accept only http and https as schemata. And if there is no
      #   schema, then we add http back in.
      # - Without a port, use the default 80/443 for http/https
      # - Strip trailing slash

      proxyspec=${!var}

      case ${proxyspec} in
	  http://*)
	      pproto=http
	      proxyspec=${proxyspec##http://}
	      ;;
	  https://*)
	      pproto=https
	      proxyspec=${proxyspec##https://}
	      ;;
	  *://*)
	      echo Found unsupported proxy protocol in $proxyspec
	      false
	      ;;
	  *)
	      # No protocol, default to http
	      pproto=http
	      ;;
      esac
      proxyspec=${proxyspec%%/}
      proxies="${proxies} --env ${var}=${pproto}://${proxyspec}"

      # Non-standard work for java/maven. Extract host/port
      # information and reassemble. This code assumes that schema and
      # trailing slash were stripped, see above.
      #
      # Notes: As the host part may contain colons (ipv6) host is
      # extracted by removing shortest string to colon from end, and
      # port is by removing longest string to colon from beginning.

      phost=${proxyspec%:*}
      pport=${proxyspec##*:}

      if [ "${pport}" == "${proxyspec}" ] ; then
	  # No port found, use protocol-specific default
	  case ${pproto} in
	      https) pport=443 ;;
	      http)  pport=80 ;;
	  esac
      fi

      case ${var} in
	  http_*|HTTP_*)
	  MO="${MO} -Dhttp.proxyHost=${phost} -Dhttp.proxyPort=${pport} -Dhttp.proxyProtocol=${pproto}"
	  ;;
	  https_*|HTTPS_*)
	  MO="${MO} -Dhttps.proxyHost=${phost} -Dhttps.proxyPort=${pport} -Dhttp.proxyProtocol=${pproto}"
	  ;;
      esac
  fi
done

# Notes
# - JAVA_OPTS  - cf-release
# - MAVEN_OPTS - open-autoscaler-release

# Deletes all dev releases before creating a new one.
#
# This is because by default fissile will use the latest (based on semver) dev
# release available when working with a BOSH release.
#
# This is undesirable when working with newer releases, then switching back
# to older ones
rm -rf ${ROOT}/${release_path}/dev_releases
# BOSH will fail to create-release if the BOSH cache was manually deleted. Deleting
# the index files causes the BOSH cache to be regenerated.
ensure_valid_dev_build_index "${ROOT}/${release_path}/.dev_builds" "${FISSILE_CACHE_DIR}"

if test -n "$(find "${ROOT}/${release_path}/blobs/" -type l 2>/dev/null)"; then
  # Migrating from BOSH CLI v1 (ruby) to BOSH CLI v2 (golang)
  docker run \
    --interactive \
    --rm \
    --volume "${FISSILE_CACHE_DIR}":/bosh-cache \
    --volume "${ROOT}/:${ROOT}/" \
    --volume "${ROOT}/bin/dev/fake-git":/usr/local/bin/git:ro \
    --env RUBY_VERSION="${RUBY_VERSION:-2.2.3}" \
    ${proxies} \
    --env MAVEN_OPTS="$MO" \
    --env JAVA_OPTS="$MO" \
    "splatform/bosh-cli:${BOSH_CLI_VERSION:-latest}" \
    /usr/local/bin/bosh.sh \
        "$(id -u)" "$(id -g)" /bosh-cache reset-release --dir="${ROOT}/${release_path}"
fi

docker run \
    --interactive \
    --rm \
    --volume "${FISSILE_CACHE_DIR}":/bosh-cache \
    --volume "${ROOT}/:${ROOT}/" \
    --volume "${ROOT}/bin/dev/fake-git":/usr/local/bin/git:ro \
    --env RUBY_VERSION="${RUBY_VERSION:-2.2.3}" \
    ${proxies} \
    --env MAVEN_OPTS="$MO" \
    --env JAVA_OPTS="$MO" \
    "splatform/bosh-cli:${BOSH_CLI_VERSION:-latest}" \
    /usr/local/bin/bosh.sh \
        "$(id -u)" "$(id -g)" /bosh-cache create-release --dir="${ROOT}/${release_path}" --force --name "${release_name}"

stampy ${ROOT}/scf_metrics.csv "${BASH_SOURCE[0]}" create-release::${release_name} done
