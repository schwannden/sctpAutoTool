#!/bin/bash
# Author: schwannden
# For bugs/questions/contact, please email: schwannden@gmail.com
# This is a simple autotool that download/confiure/install 
# lksctp and libsnp to a TI's TCI-6638k2k board.


########################################
# define help message                  #
########################################
thisFile=`basename $0`
read -d '' help <<- EOF
Usage: ./$thisFile
options:
     -m  mode [default is copy]
         [configure | get]
     -f  files to copy [default is all]
         [all | lksctp | libsnp | example]
     -h  display this message
EOF

########################################
# Set default values                   #
########################################
mode='configure'
target='all'
lksctpURL='http://sourceforge.net/projects/lksctp/files/lksctp-tools/lksctp-tools-1.0.16.tar.gz'
libsnpURL='https://github.com/schwannden/libsnp'
exampleURL='https://github.com/schwannden/sctp'
response=n
port=22

########################################
# detect operating system              #
########################################
function detectOS
{
  if [ "$OSTYPE" == "linux-gnu" ]
  then
    sedFlag='-i '
    echo "operating system: linux"
  elif [[ $OSTYPE == darwin* ]]
  then
    sedFlag="-i '' "
    echo "operating system: darwin"
  else
    echo "un-recognized operating system"
    exit
  fi
}

########################################
# make script based on target user     #
########################################
function makeScript
{
  SCTPDIR="/home/$userName/sctp/"
  read -d '' initScript <<- EOF
  'mkdir -p $SCTPDIR;
  sudo apt-get install build-essential libtool automake;'
EOF
  read -d '' lksctpScript <<- EOF
  'source /etc/profile;
  cd $SCTPDIR;
  tar -xzvf lksctp-tools-1.0.16.tar.gz;
  cd lksctp-tools-1.0.16;
  ./bootstrap;
  ./configure;
  make;
  sudo make install;'
EOF
  read -d '' libsnpScript <<- EOF
  'source /etc/profile;
  cd $SCTPDIR;
  cd libsnp;
  make;
  sudo make install;'
EOF
  read -d '' exampleScript <<- EOF
  'source /etc/profile;
  cd $SCTPDIR;
  cd sctp;
  make;'
EOF
}

########################################
# get options                          #
########################################
function getOptions
{
  if [ $# -eq 0 ]
  then
    echo "$help"
    exit
  fi
  
  while getopts ":m:f:h" opt
  do
    case $opt in
      m)
        if [ "$OPTARG" = "configure" ]
        then
          mode='configure'
        elif [ "$OPTARG" = "get" ]
        then
          mode='get'
        else
          echo "option -$opt must be one of [copy | configure]"
          echo "$help"
          exit
        fi
        ;;
      f)
        if [ "$OPTARG" = "all" ]
        then
          target='all'
        elif [ "$OPTARG" = "lksctp" ]
        then
          target='lksctp'
        elif [ "$OPTARG" = "libsnp" ]
        then
          target='libsnp'
        elif [ "$OPTARG" = "example" ]
        then
          target='example'
        else
          echo "option -$opt must be one of [all, lksctp, libsnp, example]"
          echo "$help"
          exit
        fi
        ;;
      h)
        echo "$help"
        exit
        ;;
      :)
        echo "option -$OPTARG requires an argument"
        echo "$help"
        exit
        ;;
      \?)
        echo un-recognized option
        echo "$help"
        exit
        ;;
    esac
  done
}

########################################
# get : get image or toolchain         #
########################################
function get {
  getHelp='true'
  if [ $target == all -o $target == lksctp ]
  then
    wget $lksctpURL
    getHelp='false'
  fi
  if [ $target == all -o $target == libsnp ]
  then
    git clone $libsnpURL
    getHelp='false'
  fi
  if [ $target == all -o $target == example ]
  then
    git clone $exampleURL
    getHelp='false'
  fi

  if [ $getHelp == true ]
  then
    echo "    Usage: ./$thisFile -m get [all, lksctp, libsnp, example]"
    echo "    to obtain lksctp"
    echo "       ./$thisFile -m get lksctp"
    echo "    to obtain libsnp"
    echo "       ./$thisFile -m get libsnp"
    exit
  fi
}

########################################
# setupToolchain detect and setup tool #
########################################
function setupToolchain {
if [ -e root.tar.gz ]
then
  echo "detecting tool chain installed in" `pwd`
  printf "do you want to use this toolchain? [y]"
  read response
  if [ $response == y ]
  then
    if [ -e root ]
    then 
      :
    else
      echo "decompressing tool chain"
      tar -xzvf root.tar.gz
    fi
    response='root'
  fi
fi

if [ $response != root ]
then
  if [ -e /opt/ndn/environment-setup-i586-poky-linux-uclibc ]
  then
    echo "detecting tool chain installed in /opt/ndn"
    printf "do you want to use this toolchain? [y]"
    read response
    if [ $response == y ]
    then
      echo "continuing....."
      source /opt/ndn/environment-setup-i586-poky-linux-uclibc
      response=yocto
    else
      printf "download headers, libraries, and binaries? [y]"
      read response
    fi
  else
    echo "can not detect toolchain, download headers, libraries, and binaries? [y]"
    read response
  fi
fi

if [ $response == y ]
then
  wget $rootURL
  tar -xzvf root.tar.gz
  cd root
  export PKG_CONFIG_SYSROOT_DIR=`pwd`
elif [ $response == root ]
then
  cd root
  export PKG_CONFIG_SYSROOT_DIR=`pwd`
elif [ $response == yocto ]
then
  :
else
  echo "Good bye then~"
  exit
fi
}

########################################
# Wrapper function                     #
########################################
function Scp {
  scp -P $port "$@"
}

########################################
# GetIP : get ssh IP and port          #
########################################
function getIP {
  printf "Enter your Board IP (deault port is 22, specify it by IP:port): "
  read BoardIP
  t=`echo $BoardIP | cut -d ":" -f2`
  if [ $t != $BoardIP ]
  then
    BoardIP=`echo $BoardIP | cut -d ":" -f1`
    port=$t
  fi

  printf "Enter username (default is root):"
  read userName
  if [ -z userName ]
  then
    userName='root'
  fi
}

########################################
# main program                         #
########################################
getOptions "$@"

if [ $mode == get ]
then
  get
  exit
fi

if [ $mode == configure ]
then
  getIP
  makeScript
  echo "The following commands will be run:"
  echo $initScript
  ssh -p $port -t $userName@$BoardIP bash -c "$initScript"
  echo "copying lksctp to $userName@$BoardIP:$SCTPDIR..."
  echo "copying libsnp"
  echo "copying example"
  Scp -r lksctp-tools-1.0.16.tar.gz libsnp sctp $userName@$BoardIP:$SCTPDIR
  # Scp -r libsnp $userName@$BoardIP:$SCTPDIR
  # Scp -r sctp $userName@$BoardIP:$SCTPDIR
  echo "The following commands will be run:"
  echo $lksctpScript
  ssh -p $port -t $userName@$BoardIP bash -c "$lksctpScript"
  echo "The following commands will be run:"
  echo $libsnpScript
  ssh -p $port -t $userName@$BoardIP bash -c "$libsnpScript"
  echo "The following commands will be run:"
  echo $exampleScript
  ssh -p $port -t $userName@$BoardIP bash -c "$exampleScript"
fi
