BOARD_DIR=$(dirname $0)
BIN_DIR=$1
dfu_suffix=$HOST_DIR/bin/dfu-suffix
mkimage=$HOST_DIR/bin/mkimage
bootgen=$HOST_DIR/bin/bootgen

DEVICE_VID=0x0456
DEVICE_PID=0xb673

echo "generating the boot.img"

cp $BOARD_DIR/bitstream/fsbl.elf $BIN_DIR

cp $BIN_DIR/u-boot $BIN_DIR/u-boot.elf
echo "img : {[bootloader] $BIN_DIR/fsbl.elf $BIN_DIR/u-boot.elf}" >  $BIN_DIR/boot.bif
bootgen -image $BIN_DIR/boot.bif -w -o i $BIN_DIR/boot.img

echo "generating the boot.frm"
cat $BIN_DIR/boot.img $BIN_DIR/uboot-env.bin $BOARD_DIR/target_mtd_info.key | \
	tee $BIN_DIR/boot.frm | md5sum | cut -d ' ' -f1 | tee -a $BIN_DIR/boot.frm

echo "generating boot.dfu"
cp $BIN_DIR/boot.img $BIN_DIR/boot.bin.tmp
$dfu_suffix -a $BIN_DIR/boot.bin.tmp -v $DEVICE_VID -p $DEVICE_PID
mv $BIN_DIR/boot.bin.tmp $BIN_DIR/boot.dfu

echo "generating uboot-env.dfu"
mkenvimage -s 0x20000 -o $BIN_DIR/uboot-env.bin $BOARD_DIR/uboot-env.txt
cp $BIN_DIR/uboot-env.bin $BIN_DIR/uboot-env.bin.tmp
$dfu_suffix -a $BIN_DIR/uboot-env.bin.tmp -v $DEVICE_VID -p $DEVICE_PID
mv $BIN_DIR/uboot-env.bin.tmp $BIN_DIR/uboot-env.dfu

echo "generatind sd"
SDIMGDIR=$BIN_DIR/sdimg
mkdir -p $SDIMGDIR
touch 	$SDIMGDIR/boot.bif
cp $BIN_DIR/u-boot $SDIMGDIR/u-boot.elf
cp $BIN_DIR/system_top.bit $SDIMGDIR/
cp $BIN_DIR/fsbl.elf $SDIMGDIR/
echo "img : {[bootloader] $SDIMGDIR/fsbl.elf  $SDIMGDIR/system_top.bit  $SDIMGDIR/u-boot.elf}" >  $SDIMGDIR/boot.bif
bootgen -image $SDIMGDIR/boot.bif -w -o i $SDIMGDIR/BOOT.bin
mkdir -p $SDIMGDIR/overclock

for filename in $BOARD_DIR/bitstream/overclock/*.elf ; do
echo "img : {[bootloader] $filename  $SDIMGDIR/system_top.bit  $SDIMGDIR/u-boot.elf}" >  $SDIMGDIR/boot.bif    
NAME=`basename -- "$filename" .elf`
bootgen -image $SDIMGDIR/boot.bif -w -o i $SDIMGDIR"/overclock/BOOT_"$NAME
done


#rm $SDIMGDIR/fsbl.elf  $SDIMGDIR/system_top.bit  $SDIMGDIR/u-boot.elf $SDIMGDIR/boot.bif
cp $BIN_DIR/rootfs.cpio.gz $SDIMGDIR/ramdisk.image.gz
$mkimage -A arm -T ramdisk -C gzip -d $SDIMGDIR/ramdisk.image.gz $SDIMGDIR/uramdisk.image.gz
rm $SDIMGDIR/ramdisk.image.gz
mkimage -A arm -O linux -T kernel -C none -a 0x2080000 -e 2080000 -n "Linux kernel" -d $BIN_DIR/zImage $SDIMGDIR/uImage
#cp $BIN_DIR/zynq-plutoplus.dtb $SDIMGDIR/devicetree.dtb
cp $BIN_DIR/plutoplus.dtb $SDIMGDIR/devicetree.dtb

cp $BOARD_DIR/uboot-env.txt $SDIMGDIR/uEnv.txt

cd $BIN_DIR && zip tezuka.zip boot.dfu boot.frm pluto.frm pluto.dfu sdimg/* sdimg/overclock/*
