#!/bin/bash
set -e

# 创建临时目录
mkdir -p openwrt/tmp

############################################
# 步骤1：下载原始iStoreOS镜像
############################################
ISTOREOS_URL="https://fw0.koolcenter.com/iStoreOS/alpha/x86_64_efi/istoreos-24.10.0-rc4-2025012013-x86-64-squashfs-combined-efi.img.gz"
ISTOREOS_OUTPUT="openwrt/istoreos.img.gz"
echo -e "\033[34m1. 正在下载iStoreOS镜像...\033[0m"
curl -# -L -o "$ISTOREOS_OUTPUT" "$ISTOREOS_URL" || {
    echo -e "\033[31m错误：iStoreOS镜像下载失败\033[0m"
    exit 1
}

############################################
# 步骤2：解压原始镜像
############################################
echo -e "\033[34m2. 正在解压镜像文件...\033[0m"
gzip -d "$ISTOREOS_OUTPUT" || {
    echo -e "\033[31m错误：镜像解压失败\033[0m"
    exit 1
}

############################################
# 步骤3：下载新内核文件
############################################
KERNEL_URL="https://github.com/ophub/kernel/releases/download/kernel_beta/6.6.81.tar.gz"
KERNEL_OUTPUT="openwrt/kernel.tar.gz"
echo -e "\033[34m3. 正在下载新内核...\033[0m"
curl -# -L -o "$KERNEL_OUTPUT" "$KERNEL_URL" || {
    echo -e "\033[31m错误：内核下载失败\033[0m"
    exit 1
}

############################################
# 步骤4：解压新内核
############################################
echo -e "\033[34m4. 正在解压内核文件...\033[0m"
tar -xzf "$KERNEL_OUTPUT" -C openwrt/tmp/ || {
    echo -e "\033[31m错误：内核解压失败\033[0m"
    exit 1
}

############################################
# 步骤5：处理squashfs文件系统
############################################
echo -e "\033[34m5. 正在修改文件系统...\033[0m"

# 安装必要工具
if ! command -v unsquashfs &> /dev/null || ! command -v mksquashfs &> /dev/null; then
    echo -e "\033[33m检测到需要安装squashfs-tools...\033[0m"
    sudo apt-get update && sudo apt-get install -y squashfs-tools
fi

# 解包squashfs
UNSQUASHFS_DIR="openwrt/squashfs-root"
sudo rm -rf "$UNSQUASHFS_DIR" 2>/dev/null || true
sudo unsquashfs -d "$UNSQUASHFS_DIR" openwrt/istoreos.img || {
    echo -e "\033[31m错误：squashfs解包失败\033[0m"
    exit 1
}

############################################
# 步骤6：替换内核文件
############################################
echo -e "\033[34m6. 正在替换内核...\033[0m"

# 替换内核模块
KERNEL_MODULES_PATH="openwrt/tmp/lib/modules/6.6.81"
if [ -d "$KERNEL_MODULES_PATH" ]; then
    sudo rm -rf "$UNSQUASHFS_DIR/lib/modules/"*
    sudo cp -r "$KERNEL_MODULES_PATH" "$UNSQUASHFS_DIR/lib/modules/"
else
    echo -e "\033[31m错误：内核模块路径不存在\033[0m"
    exit 1
fi

# 替换内核镜像（假设内核文件在boot目录）
KERNEL_IMAGE_PATH="openwrt/tmp/boot/vmlinuz-6.6.81"
if [ -f "$KERNEL_IMAGE_PATH" ]; then
    sudo mkdir -p "$UNSQUASHFS_DIR/boot"
    sudo cp "$KERNEL_IMAGE_PATH" "$UNSQUASHFS_DIR/boot/"
else
    echo -e "\033[33m警告：未找到内核镜像文件，可能需手动处理\033[0m"
fi

############################################
# 步骤7：重新打包文件系统
############################################
echo -e "\033[34m7. 正在重新打包镜像...\033[0m"
sudo mksquashfs "$UNSQUASHFS_DIR" openwrt/istoreos-modified.img -comp xz -noappend || {
    echo -e "\033[31m错误：squashfs打包失败\033[0m"
    exit 1
}

# 清理临时文件
sudo rm -rf "$UNSQUASHFS_DIR"
rm -rf openwrt/tmp

############################################
# 步骤8：替换原始镜像文件
############################################
mv openwrt/istoreos-modified.img openwrt/istoreos.img

############################################
# 步骤9：执行Docker构建流程
############################################
echo -e "\033[34m8. 启动Docker构建流程...\033[0m"
mkdir -p output
docker run --privileged --rm \
    -v $(pwd)/output:/output \
    -v $(pwd)/supportFiles:/supportFiles:ro \
    -v $(pwd)/openwrt/istoreos.img:/mnt/istoreos.img \
    debian:buster \
    /supportFiles/istoreos/build.sh

echo -e "\n\033[32m✔ 内核替换及构建流程已完成！\033[0m"
