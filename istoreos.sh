#!/bin/bash
mkdir -p openwrt

# 直接使用固定的镜像下载地址
DOWNLOAD_URL="https://fw0.koolcenter.com/iStoreOS/alpha/x86_64_efi/istoreos-24.10.0-rc4-2025012013-x86-64-squashfs-combined-efi.img.gz"
OUTPUT_PATH="openwrt/istoreos.img.gz"

echo "下载地址: $DOWNLOAD_URL"
echo "下载文件 -> $OUTPUT_PATH"
curl -L -o "$OUTPUT_PATH" "$DOWNLOAD_URL"

if [[ $? -eq 0 ]]; then
  echo "下载istoreos成功!"
  echo "正在解压为:istoreos.img"
  gzip -d openwrt/istoreos.img.gz
  ls -lh openwrt/
  echo "准备合成 istoreos 安装器"
else
  echo "下载失败！"
  exit 1
fi

mkdir -p output
docker run --privileged --rm \
        -v $(pwd)/output:/output \
        -v $(pwd)/supportFiles:/supportFiles:ro \
        -v $(pwd)/openwrt/istoreos.img:/mnt/istoreos.img \
        debian:buster \
        /supportFiles/istoreos/build.sh
