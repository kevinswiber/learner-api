#!/bin/sh
GIT_REMOTE=$(git remote show)
if git show-ref --verify -d "refs/remotes/$GIT_REMOTE/$GIT_BRANCH" | grep -q "$GIT_COMMIT"; then
    echo branch
    exit 0
elif git show-ref --verify -d "refs/tags/$GIT_BRANCH" | grep -q "$GIT_COMMIT"; then
    echo tag
    exit 0
else
    echo unknown
    exit 1
fi