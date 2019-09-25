#!/bin/sh

set -e

last_tag=$(git describe --abbrev=0 --tags)

github-release release --user mdom --repo morepub --tag $last_tag

sh pack

github-release upload --user mdom --repo morepub --tag $last_tag --name morepub --file morepub
