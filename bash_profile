echo start ~ bash profile
#set -x
## source the users bashrc if it exists
if [ -f "${HOME}/.bashrc" ] ; then
  source "${HOME}/.bashrc"
fi
# if [ -d "${HOME}/bin" ] ; then
#   PATH="${HOME}/bin:${PATH}"
# fi
export SHELLOPTS
set -o igncr
if [ -d "${HOME}/man" ]; then
  MANPATH="${HOME}/man:${MANPATH}"
fi
if [ -d "${HOME}/info" ]; then
  INFOPATH="${HOME}/info:${INFOPATH}"
fi

export myroot=/c/dfromrays8350 # will become /d/
export GRADLE_HOME=/c/Gradle/gradle-9.1.0
echo $GRADLE_HOME
mypath=
mypath=$myroot/bin:$mypath
echo mypath: "$mypath"
mypath=$GRADLE_HOME/bin:$mypath
echo mypath: "$mypath"
export mypath
export PATH=$mypath:$PATH   
#echo PATH: $PATH
cd $myroot
