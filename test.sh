#!/bin/bash
#
# т.к. моя хостовая система не debian подобная я сборку провожу в докере
# docker run -it --rm -v /dev:/dev --privileged=true -v $PWD/test:/root --name debian debian bash
#

SIZE_IMG=4096
IMAGE_NAME="build.img"
DISK="/dev/loop0"
DBS_DIR="/mnt/debootstrap"

BULD_DIR="/home/builder/build"
DBS_PKG="dpkg-dev "
CODENAME=${CODENAME:-bookworm}
REPO_URL="http://deb.debian.org/debian/"
ARCH=amd64
APT_SRC_LIST="/etc/apt/sources.list.d/debian.sources"
PKGS="bash gawk sed"

NEED_PKGS="parted udev fdisk debootstrap"

apt update
apt install -y ${NEED_PKGS}

# создаём тепп директорию для размещения образа с 
IMAGE_DIR=$(mktemp -d)

# если базовый образ подготовлен ранее, не тратим время))
if [[ -f ~/${IMAGE_NAME} ]]; then
	cp ~/${IMAGE_NAME} ${IMAGE_DIR}
	losetup --offset $[512*2048] ${DISK} ${IMAGE_DIR}/${IMAGE_NAME}
else
	# создаём пустой файл размером SIZE_IMG
	dd bs=1M count=0 seek=${SIZE_IMG} if=/dev/zero of=${IMAGE_DIR}/${IMAGE_NAME}
	# внутри файла создаём раздел начиная с 2048 сектора
	echo "y"|parted ${IMAGE_DIR}/${IMAGE_NAME} mklabel msdos
	echo "2048,,L" | sfdisk -N 1 ${IMAGE_DIR}/${IMAGE_NAME}
	# связываем наш файл с луп устройством
	losetup --offset $[512*2048] ${DISK} ${IMAGE_DIR}/${IMAGE_NAME}
	# создаём фс
	mkfs.ext4 -F ${DISK}
	# создаём, если ещё не существует директория для монтирования подготовленного образа
	[[ -d ${DBS_DIR} ]] || mkdir -p ${DBS_DIR}
	# монтируем образ (связанный с луп устройством) в директория для монтирования
	mount ${DISK} ${DBS_DIR}
	# устанавлтваем базовый набор пакетов debian
	debootstrap --arch=${ARCH}${DBS_PKG:+ --include=${DBS_PKG// /,}} ${CODENAME:-bookworm} ${DBS_DIR} ${REPO_URL}
	# добавляем запись о пакетах с исходниками
	cat <<EOF>${DBS_DIR}${APT_SRC_LIST}

Types: deb-src
URIs: ${REPO_URL}
Suites: ${CODENAME} ${CODENAME}-updates
Components: main
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF

	# выполняем в chroot установку пакета для установки зависимостей и добавления
	# пользователя для сборки
	chroot "${DBS_DIR}" /bin/bash -e -c "\
	apt update 2>/dev/null;
	apt install -y devscripts;
	useradd -s /bin/bash -m builder;
	mkdir ${BULD_DIR};
	chown -R builder\: ${BULD_DIR}"

	# отмонтируем настроенный базовый образ и копируем его в хомяк (/root)
	# для использования в последующих сборках
	umount "${DBS_DIR}"
	cp ${IMAGE_DIR}/${IMAGE_NAME} ~
fi

# перебираем в цикле пакеты для сборки
for pkg in ${PKGS}; do
	# создаём, если ещё не существует директория для монтирования подготовленного образа
	[[ -d ${DBS_DIR} ]] || mkdir ${DBS_DIR}

	# монтируем
	mount ${DISK} "${DBS_DIR}"
	mount -t proc chproc "${DBS_DIR}/proc"
	mount -t sysfs chsys "${DBS_DIR}/sys"
	mount -t devtmpfs chdev "${DBS_DIR}/dev" || mount --bind /dev "${DBS_DIR}/dev"
	mount -t devpts chpts "${DBS_DIR}/dev/pts"

	echo "Запуск сборки пакета <${pkg}> ..."

	# функция для выполнения процесса сборки, вынесена отдельно для удобства
	cat <<EOF>${DBS_DIR}/usr/bin/build_pkg
#!/bin/bash

export arg=\${1}
[[ -z \${arg} ]] && { echo "no arg"; exit 1; } || echo "arg: \${arg}"
su builder -m -c 'cd ${BULD_DIR}; apt source \${arg}'
cd \$(find ${BULD_DIR} -type d -name "\${arg}-*"|head -1)
echo "y"|mk-build-deps -ir
su builder -m -c 'cd \$(find ${BULD_DIR} -type d -name "\${arg}-*"|head -1); dpkg-buildpackage -b'
EOF
	# запускаем в chroot функцию сорки текущего пакета
	chroot ${DBS_DIR} /bin/bash -e -c "chmod +x /usr/bin/build_pkg; build_pkg ${pkg}"
	# готовый пакет переносим в хомяк
	mv ${DBS_DIR}${BULD_DIR}/${pkg}_*${ARCH}.deb ~

	# отмонтируем всё
	umount -l "${DBS_DIR}/dev/pts"
	umount -l "${DBS_DIR}/dev"
	umount -l "${DBS_DIR}/sys"
	umount -l "${DBS_DIR}/proc"
	umount -l "${DBS_DIR}"
	# очищаем папку
	rm -rf ${DBS_DIR}/*
	# восстанавливаем образ сборки из сохранённого для сборки следующего пакеты
	cp ~/${IMAGE_NAME} ${IMAGE_DIR}
done

# зчистка и освобождение луп устройства
rm -rf ${IMAGE_DIR}
losetup -D

# cd $(find /home/builder/build -type d -name "sed-*")
# echo "y"|mk-build-deps -ir
# su builder -c "cd \$(find /home/builder/build -type d -name \"bash-*\"); dpkg-buildpackage -b"

#head -3 \$(find ${BULD_DIR}/*/debian -name changelog)|grep "^\${arg}"
#grep "^\${arg}" \$(find ${BULD_DIR}/*/debian -name changelog)

#find ${BULD_DIR}/*/debian -name changelog -exec cat {} \;
#head -3 \$(find ${BULD_DIR}/*/debian -name changelog)|grep "^\${arg}"
#IFS=[\(\)]
#export ver=(\$(grep "^\${arg}" \$(find ${BULD_DIR}/*/debian -name changelog)))
#unset IFS
#echo "ver: \${ver[1]}"

#cd "${BULD_DIR}/\${arg}-\${ver}"
#su builder -m -c 'cd ${BULD_DIR}/\${arg}-\${ver}; dpkg-buildpackage -b'
