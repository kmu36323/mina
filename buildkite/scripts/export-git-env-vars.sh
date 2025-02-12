#!/bin/bash
set -euo pipefail

echo "Exporting Variables: "

function find_most_recent_numeric_tag() {
    TAG=$(git describe --always --abbrev=0 $1 | sed 's!/!-!g; s!_!-!g')
    if [[ $TAG != [0-9]* ]]; then
        TAG=$(find_most_recent_numeric_tag $TAG~)
    fi
    echo $TAG
}

export GITHASH=$(git rev-parse --short=7 HEAD)
export GITBRANCH=$(git rev-parse --symbolic-full-name --abbrev-ref HEAD |  sed 's!/!-!g; s!_!-!g' )
# GITTAG is the closest tagged commit to this commit, while THIS_COMMIT_TAG only has a value when the current commit is tagged
export GITTAG=$(find_most_recent_numeric_tag HEAD)
export THIS_COMMIT_TAG=$(git tag --points-at HEAD)
export PROJECT="mina"

set +u
export BUILD_NUM=${BUILDKITE_BUILD_NUM}
export BUILD_URL=${BUILDKITE_BUILD_URL}
set -u

export MINA_DEB_CODENAME=${MINA_DEB_CODENAME:=bullseye}

[[ -n "$BUILDKITE_BRANCH" ]] && export GITBRANCH=$(echo "$BUILDKITE_BRANCH" | sed 's!/!-!g; s!_!-!g')

if [[ -n "${THIS_COMMIT_TAG}" ]]; then # If the commit is tagged
    export MINA_DEB_VERSION="${GITTAG}-${GITHASH}"
    export MINA_DOCKER_TAG="$(echo "${MINA_DEB_VERSION}-${MINA_DEB_CODENAME}" | sed 's!/!-!g; s!_!-!g')"
else
    export MINA_DEB_VERSION="${GITTAG}-${GITBRANCH}-${GITHASH}"
    export MINA_DOCKER_TAG="$(echo "${MINA_DEB_VERSION}-${MINA_DEB_CODENAME}" | sed 's!/!-!g; s!_!-!g')"
fi


# Determine deb repo to use
case $GITBRANCH in
    berkeley|rampup|compatible|master|release*) # whitelist of branches that can be tagged
        case "${THIS_COMMIT_TAG}" in
          *alpha*) # any tag including the string `alpha`
            RELEASE=alpha ;;
          *beta*) # any tag including the string `beta`
            RELEASE=beta ;;
          *rampup*) # any tag including the string `rampup`
            RELEASE=rampup ;;
          ?*) # Any other non-empty tag. ? matches a single character and * matches 0 or more characters.
            RELEASE=stable ;;
          "") # No tag
            RELEASE=unstable ;;
          *) # The above set of cases should be exhaustive, if they're not then still set RELEASE=unstable
            RELEASE=unstable
            echo "git tag --points-at HEAD may have failed, falling back to unstable. Value: \"$(git tag --points-at HEAD)\""
            ;;
        esac ;;
    *)
        RELEASE=unstable ;;
esac

# Determine the packages to build (mainnet y/N)
case $GITBRANCH in
    compatible|master|release/1*) # whitelist of branches that are "mainnet-like"
      MINA_BUILD_MAINNET=true ;;
    *) # Other branches
      MINA_BUILD_MAINNET=false ;;
esac

echo "Publishing on release channel \"${RELEASE}\" based on branch \"${GITBRANCH}\" and tag \"${THIS_COMMIT_TAG}\""
[[ -n ${THIS_COMMIT_TAG} ]] && export MINA_COMMIT_TAG="${THIS_COMMIT_TAG}"
export MINA_DEB_RELEASE="${RELEASE}"
