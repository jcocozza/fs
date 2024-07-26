#!/bin/bash
#
# Build fs binary

VERSION="$1"
if [[ -z "${VERSION}" ]]; then
    echo "version required"
    exit 1
fi

CHECKVERSION=$(cat ../main.go | grep "const version" | sed 's/.*= "\(.*\)"/\1/')

if [[ ${VERSION} != ${CHECKVERSION} ]]; then
    echo "version mismatch"
    echo "main.go has version: ${CHECKVERSION}"
    echo "you passed: ${VERSION}"
    exit 1
fi

echo "creating builds for version: ${VERSION}"
binary="fs"

cd ..
GOOS=linux GOARCH=amd64 go build -o "${binary}_linux_amd64"
GOOS=linux GOARCH=arm64 go build -o "${binary}_linux_aarch64"

GOOS=darwin GOARCH=amd64 go build -o "${binary}_darwin_amd64"
GOOS=darwin GOARCH=arm64 go build -o "${binary}_darwin_arm64"

GOOS=windows GOARCH=amd64 go build -o "${binary}_windows_amd64"
GOOS=windows GOARCH=arm64 go build -o "${binary}_windows_arm64"

BINDIR="bin/${VERSION}"
mkdir -p "${BINDIR}"
mv ${binary}_* "${BINDIR}"
echo "builds moved to ${BINDIR}"

echo "copying binaries to vim plugin"
cp -r ${BINDIR} "plugin/bin"
