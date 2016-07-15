#!/bin/sh

INCLUDE_SEQUENCE=1

MODULE_LIST_TESTMANAGER=(\
	IATestManager/Foreign/Lua           lua         \
	IATestManager/Foreign/ToLua         tolua++     \
	IATestManager/Launcher              Launcher     \
)

MODULE_LIST_BUILD_SMOKESCREEN=(\
	IATestManager/Foreign/Lua           lua         \
	IATestManager/Foreign/ToLua         tolua++     \
	IATestManager/Launcher              Launcher     \
)

NO_DITTO=( lua tolua++ ) #不拷贝到发布目录

findme()
{
	dir=$(dirname "$1")
	cd "${dir}"
	pwd
}

contains()
{
    local n=$#
    local value=${!n}

    for ((i=1;i < $#;i++)) {
        if [ "${!i}" == "${value}" ]; then
            return 0
        fi
    }

    return 1
}

global_anchor=/tmp/TestManager

cmd=install
mode=Debug
project=TestManager

do_all=yes;
package=yes;

while [ $# != 0 ] #处理输入的命令行参数
do
	case $1 in
		build) cmd="";;
		clean) cmd=clean;;
		install) cmd=install;;

		debug) mode=Debug;;
		release) mode=Release;;

		root) dstroot="DSTROOT=/";;

		tm)   project=TestManager;;
		tool) project=Tool;;
		
		xxx) pkgmaker=/Developer/usr/bin/packagemaker;;
		
		*) project=$(echo "$1" | tr - _); echo "Assuming $1 is a project name";;
	esac
	shift
done

srcroot=$(findme "$0") #当前source code所在路径
sympath="${global_anchor}/Symroot"-${mode}-$(md5 -qs "${srcroot}")
dstpath="${global_anchor}/Dstroot"-${mode}-$(md5 -qs "${srcroot}")
symroot="SYMROOT=${sympath}"
dstroot="DSTROOT=${dstpath}/\${PROJECT_NAME}.dst"

pkgmaker="${srcroot}"/InstallPackage/PackageMaker.app/Contents/MacOS/PackageMaker

if [ "${BUILD_ID}"0 = 0 ]
then
	if [ -d "${global_anchor}" ]
	then
		last=$(
			find "${global_anchor}" -name REDIST-\* -maxdepth 1 | 
			sed 's/.*REDIST-\([0-9][0-9]*\)/\1/g'               |
			sed 's/^00*\([1-9][0-9]*\)/\1/g'                    |
			sort -n                                             |
			tail -1
		)
	fi

	if [ "${last}xxx" = "xxx" ]
	then
		last=0
	fi
	
	BUILD_ID=$(printf %05d $(( ${last} + 1 )))
	echo $BUILD_ID
fi

if [ "${SUDO_PASSWD}"0 = 0 ]
then
	SUDO="sudo"
else
	SUDO="silent_sudo"
fi
echo $SUDO

silent_sudo()
{
	echo "${SUDO_PASSWD}" | sudo -S $@
}

MODULE_LIST_NAME=MODULE_LIST_$(echo $project | tr a-z A-Z) #项目名称转换为大写

eval MODULE_LIST=\( \${${MODULE_LIST_NAME}[@]} \) #MODULE_LIST_NAME＝MODULE_LIST_TESTMANAGER    MODULE_LIST＝IATestManager/Foreign/Lua

cd "${srcroot}" && #srcroot=.../testmanager
(
	for i in $(seq 0 2 $(( ${#MODULE_LIST[@]} - 1)))
	do
		(
			dir="${MODULE_LIST[$(( $i + 0))]}"
			tgt="${MODULE_LIST[$(( $i + 1))]}"
			cd "${dir}"
			xcodebuild ${symroot} ${dstroot} -configuration "${mode}" "${cmd}" -target "${tgt}"
		) || exit $?
	done
	
	echo "hello 1"
) && #here all projects compilation would be finished


(
	redist_anchor="${global_anchor}/REDIST-${BUILD_ID}" #redist_anchor存放每一个项目编译出来的target文件 redist_anchor=/tmp/TestManager/REDIST-00001

	if [ "${redist}" = "yes" -o "${package}" = "yes" ]
	then
		
		for i in $(seq 0 2 $(( ${#MODULE_LIST[@]} - 1))) #i=0 2 4 ... 38
		do
			dir="${MODULE_LIST[$(( $i + 0))]}" #table MODULE_LIST的第一列内容
			xcodeproj="$(basename $(find ${dir} -iname \*.xcodeproj -maxdepth 1) .xcodeproj)"
			echo $xcodeproj 
			tgt="${MODULE_LIST[$(( $i + 1))]}" #table MODULE_LIST的第二列内容
			echo $tgt
			
			if $(contains "${NO_DITTO[@]}" "${tgt}")
			then
				true
			else
				printf "ditto %-40s --> %s\n" "/${dstpath}/${xcodeproj}.dst" "${redist_anchor}"
				ditto "/${dstpath}/${xcodeproj}.dst" "${redist_anchor}" #拷贝所有的target文件到临时发布目录
			fi
		done
	fi&&
	
	
	if [ "${package}" = "yes" ]
	then
		echo "hello 200"
		intelligent_stem="Library/IntelligentAutomation"
		
		${SUDO} /usr/bin/true &&
		
		sudo chown -R root "${redist_anchor}" &&
		
		sudo mkdir "${redist_anchor}"/Library/IntelligentAutomation/Applications/{Script,Log,Config} &&
		sudo chmod a+rwx "${redist_anchor}"/Library/IntelligentAutomation/Applications/{Script,Log,Config} &&
		
		sudo mkdir -p "${redist_anchor}"/usr/local
		sudo chmod a+rwx "${redist_anchor}"/usr/local
		sudo mkdir -p "${redist_anchor}"/Library/Python/2.7
		sudo chmod a+rwx "${redist_anchor}"/Library/Python/2.7
		basepath=$(cd `dirname $0`; pwd)
		ialib_path="${basepath}/ialibs" 
		echo ""
		echo "ialib_path = ${ialib_path}"
		
		#sudo -i cp -r "${ialib_path}/testlib" "${redist_anchor}"/usr/local
		
		sudo -i cp -r "${ialib_path}/lib" "${redist_anchor}"/usr/local
		sudo -i cp -r "${ialib_path}/bin" "${redist_anchor}"/usr/local
		sudo -i cp -r "${ialib_path}/share" "${redist_anchor}"/usr/local
		sudo -i cp -r "${ialib_path}/site-packages" "${redist_anchor}"/Library/Python/2.7
		
		#sudo mkdir -p "${redist_anchor}"/"${intelligent_stem}"/Applications/Profile
		
		if [ "$INCLUDE_SEQUENCE" -eq 1 ]
		then
			echo "hello 300"
		fi
				
		echo "${srcroot}"/InstallPackage/PackageMaker.app/Contents/MacOS/PackageMaker \
			--verbose \
			--no-recommend \
			--no-relocate \
			--filter "\.DS_Store" \
			--target 10.5 \
			--root "${redist_anchor}"  \
			--scripts "${srcroot}"/InstallPackage/TestManager/Scripts \
			--out "${global_anchor}/IntelligentAutomation-TestManager-ALL.pkg"  \
			--id Intelligent.FactoryAutomationIO  \
			--title "Intelligent's TestManager"  \
			--version 1.0
			
		"${srcroot}"/InstallPackage/PackageMaker.app/Contents/MacOS/PackageMaker \
			--verbose \
			--no-recommend \
			--no-relocate \
			--filter "\.DS_Store" \
			--target 10.5 \
			--root "${redist_anchor}"  \
			--scripts "${srcroot}"/InstallPackage/TestManager/Scripts \
			--out "${global_anchor}/IntelligentAutomation-TestManager.pkg"  \
			--id Intelligent.FactoryAutomationIO  \
			--title "Intelligent's TestManager"  \
			--version 1.0
		
	fi&&

	true
) &&

true
open $global_anchor