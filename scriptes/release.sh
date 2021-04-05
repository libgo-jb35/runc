#!/bin/bash
# Copyright (C) 2017 SUSE LLC.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e


## --->
# Project-specific options and functions. In *theory* you shouldn't need to
# touch anything else in this script in order to use this elsewhere.
project="runc"
root="$(readlink -f "$(dirname "${BASH_SOURCE}")/..")"

# Cette fonction prend un chemin de sortie comme argument, 
# où le binaire construit (de préférence statique) doit être placé.
function build_project() {
	builddir="$(dirname "$1")"

	make -C "$root" COMMIT_NO= static
	mv "$root/$project" "$1"
}
# End of the easy-to-configure portion.
## <---

# Affiche une aide sur l'utilisation du scriptes
function usage() {
	echo "Utilisation: release.sh [-S <id-clef-gpg>] [-c <commit-ish>] [-r <release-dir>] [-v <version>]" >&2
	exit 1
}

# log un message dans stderr.
function log() {
	echo "[*] $*" >&2
}

# log un message dans stderr, puis quite le programme.
function bail() {
	log "$@"
	exit 0
}

# Conduct a sanity-check to make sure that GPG provided with the given
# arguments can sign something. Inability to sign things is not a fatal error.
function gpg_cansign() {
	gpg "$@" --clear-sign </dev/null >/dev/null
}

# Lors de la création de versions, nous devons créer des binaires statiques, 
# une archive du commit actuel et générer des signatures détachées pour les deux.
keyid=""
commit="HEAD"
version=""
releasedir=""
hashcmd=""
while getopts "S:c:r:v:h:" opt; do
	case "$opt" in
	S)
		keyid="$OPTARG"
		;;
	c)
		commit="$OPTARG"
		;;
	r)
		releasedir="$OPTARG"
		;;
	v)
		version="$OPTARG"
		;;
	h)
		hashcmd="$OPTARG"
		;;
	\:)
		echo "Argument manquant: -$OPTARG" >&2
		usage
		;;
	\?)
		echo "Option invalide: -$OPTARG" >&2
		usage
		;;
	esac
done

version="${version:-$(<"$root/VERSION")}"
releasedir="${releasedir:-release/$version}"
hashcmd="${hashcmd:-sha256sum}"
goarch="$(go env GOARCH || echo "amd64")"

log "céation $project release dans '$releasedir'"
log "  version: $version"
log "   commit: $commit"
log "      key: ${keyid:-DEFAULT}"
log "     hash: $hashcmd"

# Expliquez ce que nous faisons.
set -x

# Créez le répertoire de la realease.
rm -rf "$releasedir" && mkdir -p "$releasedir"

# Construction du projet
build_project "$releasedir/$project.$goarch"

# Création de l'archive tar
git archive --format=tar --prefix="$project-$version/" "$commit" | xz >"$releasedir/$project.tar.xz"

# Génère une clef somme de contrôle sha256 de l'archive
(
	cd "$releasedir"
	"$hashcmd" "$project".{"$goarch",tar.xz} >"$project.$hashcmd"
)

# Set up the gpgflags.
[[ "$keyid" ]] && export gpgflags="--default-key $keyid"
gpg_cansign $gpgflags || bail "Impossible de trouver la clé GPG appropriée, saut de l'étape de signature."

# Sign everything.
gpg $gpgflags --detach-sign --armor "$releasedir/$project.$goarch"
gpg $gpgflags --detach-sign --armor "$releasedir/$project.tar.xz"
gpg $gpgflags --clear-sign --armor \
	--output "$releasedir/$project.$hashcmd"{.tmp,} &&
	mv "$releasedir/$project.$hashcmd"{.tmp,}
