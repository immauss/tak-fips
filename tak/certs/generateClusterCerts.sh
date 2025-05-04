#!/bin/bash
set -u
if [ -z ${CA_NAME+x} ];
then
  echo "Please set the following variables before running this script: CA_NAME. \n"
  exit -1
else
  ./cert-metadata.sh
  ./makeRootCa.sh -fips --ca-name $CA_NAME
  ./makeCert.sh -fips server takserver
  ./makeCert.sh -fips client user
  ./makeCert.sh -fips client admin
fi