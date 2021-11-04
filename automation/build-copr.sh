#!/bin/bash -xe

MAVEN_SETTINGS="/etc/maven/settings.xml"

# Set the location of the JDK that will be used for maven
export JAVA_HOME="${JAVA_HOME:=/usr/lib/jvm/java-11}"

# Use ovirt mirror if able, fall back to central maven
mkdir -p "${MAVEN_SETTINGS%/*}"
cat >"$MAVEN_SETTINGS" <<EOS
<?xml version="1.0"?>
<settings xmlns="http://maven.apache.org/POM/4.0.0"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
          http://maven.apache.org/xsd/settings-1.0.0.xsd">

<mirrors>
        <mirror>
                <id>root-maven-repository</id>
                <name>Official maven repo</name>
                <url>https://repo.maven.apache.org/maven2</url>
                <mirrorOf>*</mirrorOf>
        </mirror>
</mirrors>
</settings>
EOS

# Build RPMs
mvn help:evaluate -Dexpression=project.version -gs "$MAVEN_SETTINGS" # downloads and installs the necessary jars

# Prepare the version string (with support for SNAPSHOT versioning)
VERSION=$(mvn help:evaluate -Dexpression=project.version -gs "$MAVEN_SETTINGS" 2>/dev/null| grep -v "^\[")
VERSION=${VERSION/-SNAPSHOT/-0.$(git rev-list HEAD | wc -l).$(date +%04Y%02m%02d%02H%02M)}
IFS='-' read -ra VERSION <<< "$VERSION"
RELEASE=${VERSION[1]-1}

# Prepare source archive
mkdir -p rpmbuild/SOURCES
git archive --format=tar HEAD | gzip -9 > rpmbuild/SOURCES/ovirt-engine-extensions-api-$VERSION.tar.gz

# Set version and release
sed \
    -e "s|@VERSION@|${VERSION}|g" \
    -e "s|@RELEASE@|${RELEASE}|g" \
    < ovirt-engine-extensions-api.spec.in \
    > ovirt-engine-extensions-api.spec

rpmbuild \
    -D "_topdir rpmbuild" \
    -bs --nodeps ovirt-engine-extensions-api.spec
