#!/bin/bash
set -x
set -e

CM_EXT_BRANCH=cm5-5.15.0
doris_version=1.2.2
parcel_version=${doris_version}-1
doris_csd_out="doris_csd_out"
doris_csd_bulid_path="doris_csd_bulid"
doris_parcel_out="doris_parcel_out"
doris_parcel_bulid_path=doris-$parcel_version
doris_csd_bulid_name="csd_out"
doris_parcel_name="$doris_parcel_bulid_path-el7.parcel"
doris_service_name="DORIS"
doris_package_fe_url="https://www.apache.org/dyn/mirrors/mirrors.cgi?action=download&filename=doris/1.2/1.2.2-rc01/apache-doris-fe-1.2.2-bin-x86_64.tar.xz"
doris_package_be_url="https://archive.apache.org/dist/doris/1.2/1.2.2-rc01/apache-doris-be-1.2.2-bin-x86_64.tar.xz"
doris_package_dependencies_url="https://archive.apache.org/dist/doris/1.2/1.2.2-rc01/apache-doris-dependencies-1.2.2-bin-x86_64.tar.xz"
doris_fe_package="$( basename $doris_package_fe_url )"
doris_be_package="$( basename $doris_package_be_url )"
doris_dependencies_package="$( basename $doris_package_dependencies_url )"
CM_EXT=../cm_ext

#Checkout if dir does not exist
if [ ! -d ${CM_EXT} ]; then
  git clone https://github.com/cloudera/cm_ext.git
fi
if [ ! -f $CM_EXT/validator/target/validator.jar ]; then
  cd $CM_EXT
  git checkout "$CM_EXT_BRANCH"
  mvn package
  cd ../bin
fi

function get_doirs_package {
if [ ! -d "${doris_parcel_bulid_path}" ];then
  mkdir ${doris_parcel_bulid_path}
  if [ ! -f "$doris_fe_package" ]; then
    echo $doris_package_fe_url
    wget --no-check-certificate $doris_package_fe_url
  fi
  tar -xvf ${doris_fe_package}
  mv apache-doris-fe-${doris_version}-bin-x86_64  fe
  mv fe ${doris_parcel_bulid_path}
  if [ ! -f "$doris_be_package" ]; then
    wget $doris_package_be_url
  fi
  tar -xvf ${doris_be_package}
  mv apache-doris-be-${doris_version}-bin-x86_64  be
  mv be ${doris_parcel_bulid_path}
  if [ ! -f "$doris_dependencies_package" ]; then
    wget $doris_package_dependencies_url
  fi
  tar -xvf ${doris_dependencies_package}
  mv apache-doris-dependencies-${doris_version}-bin-x86_64/apache_hdfs_broker  $doris_parcel_bulid_path
  mv apache-doris-dependencies-${doris_version}-bin-x86_64/java-udf*  $doris_parcel_bulid_path/be/lib/
fi
}
function build_doris_parcel {
  rm -rf ../parcel/$doris_parcel_bulid_path
  cp -r ../parcel/doris-parcel-src/meta $doris_parcel_bulid_path
  sed -i -e "s/%PARCELVERSION%/$parcel_version/" ./$doris_parcel_bulid_path/meta/parcel.json
  java -jar $CM_EXT/validator/target/validator.jar -d ./$doris_parcel_bulid_path
  mkdir -p $doris_parcel_out
  tar zcvhf ./$doris_parcel_out/$doris_parcel_name $doris_parcel_bulid_path --owner=root --group=root
  java -jar $CM_EXT/validator/target/validator.jar -f ./$doris_parcel_out/$doris_parcel_name
  python $CM_EXT/make_manifest/make_manifest.py ./$doris_parcel_out
  mv $doris_parcel_bulid_path ../parcel
  mv $doris_parcel_out ../parcel
}

function build_doris_csd {
  JARNAME=${doris_service_name}-${doris_version}.jar
  if [ -f "$JARNAME" ]; then
    return
  fi
  rm -rf ../csd/${doris_csd_bulid_path}
  rm -rf ../csd/$doris_csd_out
  mkdir ${doris_csd_bulid_path}
  mkdir $doris_csd_out
  cp -a ../csd/doris-csd-src/* ${doris_csd_bulid_path}
  sed -i -e "s/%CSDVERSION%/$doris_version/" ${doris_csd_bulid_path}/descriptor/service.sdl
  java -jar $CM_EXT/validator/target/validator.jar -s ${doris_csd_bulid_path}/descriptor/service.sdl
  jar -cvf ./$JARNAME -C ${doris_csd_bulid_path} .
  mv $JARNAME $doris_csd_out
  mv ${doris_csd_bulid_path} ../csd
  mv $doris_csd_out ../csd
}


case $1 in
parcel)
  get_doirs_package
  build_doris_parcel
  ;;
csd)
  build_doris_csd
  ;;
all)
  build_doris_csd
  build_doris_parcel
  ;;
*)
  echo "Usage: $0 [parcel|csd|all]"
  ;;
esac
