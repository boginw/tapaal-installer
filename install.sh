#!/bin/bash

INSTALL_DIR=/opt/tapaal
EXEC_DIR=/usr/bin
DESKTOP_DIR=/usr/share/applications
JAVA_MIN_VERSION=11

#TAPAAL_LINK=https://download.tapaal.net/tapaal/tapaal-3.7/tapaal-3.7.1-linux64.zip
#TAPAAL_DIR=tapaal-3.7.1-linux64

WARNING='\033[0;33m'
ERROR='\033[0;31m'
INFO='\033[0;32m'
NC='\033[0m'

# Need to operate as super user
if [[ $EUID -ne 0 ]]; then
   printf "${ERROR}Error:${NC} "
   echo "This script must be run as root" 
   exit 1
fi

help() {
   echo "Usage sudo ./install.sh [OPTION]"
   echo "    -h     Show all available options"
   echo "    -i     Install TAPAAL from the current directory"
   echo "    -u     Uninstall all files created by this installer"
   echo "    -d     Download, unpack, and install TAPAAL"
   exit 1
}

invalid() {
   printf "${ERROR}Error:${NC} "
   echo "Invalid options"
   help
}

uninstall() {
   rm -f $DESKTOP_DIR/tapaal.desktop
   rm -f $EXEC_DIR/tapaal
   rm -rf $INSTALL_DIR
   exit 0
}

sdkman_warning() {
   echo ""
   echo "    If you are using SDKMAN and have a new version of Java installed,"
   echo "    try initializing SDKMAN in ~/.profile as well as in ~/.bash_profile"
}

install() {
   # Check if Java is installed and loaded without .bashrc
   if [[ -z $(bash --norc -c "which java") ]]; then
      printf "${WARNING}Warning:${NC} "
      echo "Java is required but does not seem to be installed"
      sdkman_warning
   fi

   JAVA_VERSION_NORC=$(bash --norc << EOM
java -version 2>&1 | head -1 | cut -d'"' -f2 | sed '/^1\./s///' | cut -d'.' -f1
EOM
   )

   JAVA_VERSION=$(java -version 2>&1 | head -1 | cut -d'"' -f2 | sed '/^1\./s///' | cut -d'.' -f1)

   if [[ $JAVA_VERSION_NORC != $JAVA_VERSION ]]; then
      printf "${WARNING}Warning:${NC} "
      sdkman_warning
      echo ${NC}
   fi

   # Check if the Java version used when .bashrc is not loaded satisfies minimal requirements
   if [[ $JAVA_VERSION -lt $JAVA_MIN_VERSION ]]; then
      printf "${WARNING}Warning:${NC} "
      echo "The currently installed Java version (version $JAVA_VERSION) is too old"
      echo "    The minimal requirement is Java $JAVA_MIN_VERSION"
      sdkman_warning
   fi

   # Install into correct dir
   mkdir -p $INSTALL_DIR
   cp -R * $INSTALL_DIR/
   cd $INSTALL_DIR/
   chmod -R 777 *

   # Create launcher
   tee $EXEC_DIR/tapaal > /dev/null << EOM
#!/bin/sh
cd /opt/tapaal
./tapaal
EOM

   # Make launcher executable
   chmod +x $EXEC_DIR/tapaal

   # Create .desktop file
   tee tapaal.desktop > /dev/null << EOM
[Desktop Entry]
Name=TAPAAL
Comment=Tool for Verification of Timed-Arc Petri Nets
TryExec=${EXEC_DIR}/tapaal
Exec=${EXEC_DIR}/tapaal
Icon=${INSTALL_DIR}/icon.png
Terminal=false
Type=Application
Categories=Utility;Application;
EOM
   chmod +x tapaal.desktop

   # Validate and install desktop file
   desktop-file-install --dir=$DESKTOP_DIR tapaal.desktop

   printf "${INFO}Info:${NC} Successfully Installed TAPAAL\n"
}

download() {
   if [ -z ${TAPAAL_LINK+x} ]; then
      printf "${INFO}Info:${NC} Fetching newest TAPAAL version\n"
      TAPAAL_LINK=${TAPAAL_LINK:=$(curl -s http://www.tapaal.net/download/ | grep -Eo "https://download.tapaal.net/tapaal/tapaal-[^/]*/tapaal-[^/]*-linux64.zip")}
      TAPAAL_DIR=${TAPAAL_DIR:=$(basename $TAPAAL_LINK | sed 's/\.[^.]*$//')}
      printf "${INFO}Info:${NC} Found TAPAAL version \"$TAPAAL_DIR\"\n"
   fi
   printf "${INFO}Info:${NC} Downloading TAPAAL\n"
   wget -q $TAPAAL_LINK
   printf "${INFO}Info:${NC} Extracting TAPAAL\n"
   unzip -q $TAPAAL_DIR.zip
   rm -f $TAPAAL_DIR.zip
   RET=$PWD
   cd $TAPAAL_DIR
   printf "${INFO}Info:${NC} Downloading TAPAAL icon\n"
   wget -q https://github.com/TAPAAL/tapaal-gui/raw/master/src/resources/Images/tapaal-icon.png
   mv tapaal-icon.png icon.png
   printf "${INFO}Info:${NC} Extracting TAPAAL\n"
   install
   printf "${INFO}Info:${NC} Cleanup\n"
   cd $RET
   rm -rf $TAPAAL_DIR
   exit 0
}

# Check if we should uninstall
if [ $# -gt 0 ]; then
   [[ $# -gt 1 ]] && invalid

   getopts ":hudi" opt
   case ${opt} in
      u ) uninstall
         ;;
      d ) download
         ;;
      h ) help
         ;;
      i ) install
         ;;
      \? ) invalid
         ;;
   esac
else
   download
fi
