#!/bin/bash
###############################################################################
#
# CRATE Utilities: https://github.com/crate/crate-utils
#
# Licensed to CRATE Technology GmbH ("Crate") under one or more contributor
# license agreements.  See the NOTICE file distributed with this work for
# additional information regarding copyright ownership.  Crate licenses
# this file to you under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.  You may
# obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
# License for the specific language governing permissions and limitations
# under the License.
#
# However, if you have executed another commercial license agreement
# with Crate these terms will supersede the license and you may use the
# software solely pursuant to the terms of the relevant commercial agreement.
#
###############################################################################
#
# Crate Try script

set -e

INV="\033[7m"
BRN="\033[33m"
RED="\033[31m"
END="\033[0m\033[27m"

function wait_for_user() {
    read -p "Press RETURN to continue or any other key to abort" -n1 -s x
    if [[ "$x" != '' ]]; then
        exit 1
    fi
}

function prf() {
    printf "$INV$BRN$1$END\n"
}

function on_error() {
    printf "$RED
It looks like you hit an issue when trying Crate.

Troubleshooting and basic usage information for Crate are available at:

    https://crate.io/docs/
$END"
}
trap on_error ERR

function on_exit() {
    # kill crate on exit
    kill $(jobs -p)
}

function pre_start_cmd() {
    # display info about crate admin on non gui systems
    if [[ ! $OS = "Darwin" && ! -n $DISPLAY ]]; then
        [ $(hostname -d) ] && HOST=$(hostname -f) || HOST=$(hostname)
        prf "Crate will get started in foreground. To open crate admin goto

    http://$HOST:4200/admin\n"
    fi
}

function post_start_cmd() {
    # open crate admin if system has gui
    if [[ $OS = "Darwin" || -n $DISPLAY ]]; then
        open http://localhost:4200/admin
    fi
}

function wait_until_running() {
    # wait until crate is listening on port 4200
    while ! nc -vz localhost 4200 > /dev/null 2>&1 /dev/null; do
        sleep 0.1
    done
}


# OS/Distro Detection
if [ -f /etc/debian_version ]; then
    OS=Debian
elif [ -f /etc/redhat-release ]; then
    # Just mark as RedHat and we'll use Python version detection
    # to know what to install
    OS=RedHat
elif [ -f /etc/lsb-release ]; then
    . /etc/lsb-release
    OS=$DISTRIB_ID
elif [ -f /etc/os-release ]; then
    # Arch Linux
    . /etc/os-release
    OS=$ID
else
    OS=$(uname -s)
fi

function has_java() {
    if [ $OS = "Darwin" ]; then
        /usr/libexec/java_home &> /dev/null || {
            return 1
        }
    else
        if [ ! $(which java) ]; then
            return 1
        fi
    fi
    return 0
}

has_java || {
    # check if java is installed
    if [ $OS = "Darwin" ]; then
        printf "\n$RED Please make sure you have java installed and it is on your path.\n"
        printf "\n To install java goto http://www.oracle.com/technetwork/java/javase/downloads/index.html$END\n\n"

        open http://www.oracle.com/technetwork/java/javase/downloads/index.html
    elif [ $OS = "RedHat" ]; then
            printf "\n$RED Please make sure you have java installed and it is on your path.$END\n\n"
            printf "$RED You can install it by running

        sudo yum install java-1.7.0-openjdk$END\n\n"
    elif [ $OS = "Debian" -o $OS = "Ubuntu" ]; then
            printf "\n$RED Please make sure you have java installed and it is on your path.$END\n\n"
            printf "$RED You can install it by running

        sudo apt-get install openjdk-7-jdk$END\n\n"
    elif [ $OS = "arch" ]; then
            printf "\n$RED Please make sure you have java installed and it is on your path.$END\n\n"
            printf "$RED You can install it by running

        sudo sudo pacman -S jdk7-openjdk$END\n\n"
    fi
    wait_for_user
    has_java || {
        printf "\n$RED \n Java is still not installed. Aborting.$END\n\n"
        exit 1
    }
}


# check if java version > 1.7 is installed
if [ has_java ]; then
    JAVA_VER=$(java -version 2>&1 | sed 's/.* version "\(.*\)\.\(.*\)\..*"/\1\2/; 1q')
    if [ ${#JAVA_VER} -gt 10 ]; then
        exit 1
    fi
    if [ ! "$JAVA_VER" -ge 17 ]; then
        printf "\n$RED Crate requires java version >= 1.7.$END\n\n"
        exit 1
    fi
fi

trap on_exit EXIT

if [ ! -d crate-0.30.0 ]; then
    prf "\n* Downloading CRATE...\n"
    curl -f https://cdn.crate.io/downloads/releases/crate-0.30.0.tar.gz > crate-0.30.0.tar.gz
    tar xzf crate-0.30.0.tar.gz
else
    prf "\n* CRATE has already been downloaded."
fi

prf "\n* Starting CRATE...\n"
pre_start_cmd
crate-0.30.0/bin/crate &
wait_until_running
post_start_cmd
wait
