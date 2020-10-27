#!/bin/bash
echo ""
echo "LineageOS 17.x Treble Buildbot"
echo "ATTENTION: this script syncs repo on each run"
echo "Executing in 5 seconds - CTRL-C to exit"
echo ""
sleep 5

START=`date +%s`
BUILD_DATE="$(date +%Y%m%d)"
BL=$PWD/treble_build_los

sync_source() {
	echo "Preparing local manifest"
	mkdir -p .repo/local_manifests
	cp $BL/manifest.xml .repo/local_manifests/manifest.xml
	echo ""

	echo "Syncing repos"
	rm -rf vendor/lineage
	repo sync -c --force-sync --no-clone-bundle --no-tags -j$(nproc --all)
	repo forall -c git lfs pull
	echo ""
}

echo "Setting up build environment"
source build/envsetup.sh &> /dev/null
echo ""

patches_source() {
	echo "Reverting LOS FOD implementation"
	cd frameworks/base
	git am $BL/patches/0001-Squashed-revert-of-LOS-FOD-implementation.patch
	cd ../..
	cd frameworks/native
	git am $BL/patches/0001-Revert-surfaceflinger-Add-support-for-extension-lib.patch
	cd ../..
	cd vendor/lineage
	git revert 612c5a846ea5aed339fe1275c119ee111faae78c --no-edit # soong: Add flag for fod extension
	cd ../..
	echo ""

	echo "Applying PHH patches"
	rm -f device/*/sepolicy/common/private/genfs_contexts
	cd device/phh/treble
	git clean -fdx
	bash generate.sh lineage
	cd ../../..
	bash ../treble_experimentations/apply-patches.sh treble_patches
	echo ""

	echo "Applying universal patches"
	cd frameworks/base
	git am $BL/patches/0001-UI-Revive-navbar-layout-tuning-via-sysui_nav_bar-tun.patch
	git am $BL/patches/0001-Disable-vendor-mismatch-warning.patch
	git am $BL/patches/0001-Allow-selective-signature-spoofing-for-microG.patch
	cd ../..
	cd lineage-sdk
	git am $BL/patches/0001-sdk-Invert-per-app-stretch-to-fullscreen.patch
	cd ..
	cd packages/apps/LineageParts
	git am $BL/patches/0001-LineageParts-Invert-per-app-stretch-to-fullscreen.patch
	cd ../../..
	cd vendor/lineage
	git am $BL/patches/0001-vendor_lineage-Log-privapp-permissions-whitelist-vio.patch
	cd ../..
	echo ""

	echo "Applying GSI-specific patches"
	cd build/make
	git am $BL/patches/0001-build-Don-t-handle-apns-conf.patch
	cd ../..
	cd device/phh/treble
	git revert 82b15278bad816632dcaeaed623b569978e9840d --no-edit # Update lineage.mk for LineageOS 16.0
	git am $BL/patches/0001-Remove-fsck-SELinux-labels.patch
	git am $BL/patches/0001-treble-Add-overlay-lineage.patch
	git am $BL/patches/0001-treble-Don-t-specify-config_wallpaperCropperPackage.patch
	git am $BL/patches/0001-TEMP-treble-Fix-init.treble-environ.rc-hardcode-for-.patch
	cd ../../..
	cd external/tinycompress
	git revert 82c8fbf6d3fb0a017026b675adf2cee3f994e08a --no-edit # tinycompress: Use generated kernel headers
	cd ../..
	cd frameworks/native
	git revert 581c22f979af05e48ad4843cdfa9605186d286da --no-edit # Add suspend_resume trace events to the atrace 'freq' category.
	cd ../..
	cd hardware/lineage/interfaces
	git am $BL/patches/0001-cryptfshw-Remove-dependency-on-generated-kernel-head.patch
	cd ../../..
	cd system/hardware/interfaces
	git revert 5c145c4 --no-edit # system_suspend: start early
	cd ../../..
	cd system/sepolicy
	git revert d12551bf1a6e8a9ece6bbb98344a27bde7f9b3e1 --no-edit # sepolicy: Relabel wifi. properties as wifi_prop
	cd ../..
	cd vendor/lineage
	git am $BL/patches/0001-build_soong-Disable-generated_kernel_headers.patch
	cd ../..

	# Vgdn1942 patches
	cd system/sepolicy
	git am $BL/patches/0001-Update-sepolicy-to-user-build.patch
	cd ../..
	cd packages/apps/FMRadio
	git am $BL/patches/0001-Fix-build-FM.patch
	cd ../../..
	cd frameworks/base
	git am $BL/patches/0001-Make-QS-columns-count-configurable.patch
	cd ../..
	cd device/phh/treble
	git am $BL/patches/0001-Fix-build-user-mode-and-more-additional.patch
	git am $BL/patches/0001-Add-new-device.patch
	git am $BL/patches/0001-Add-PS-helper-and-more.patch
	git am $BL/patches/0001-Fix-CTS.patch
	git am $BL/patches/0001-Update-libfmcust-sepolicy-other.patch
	cd ../../..
	cd external/noto-fonts
	git am $BL/patches/0001-Update-Emoji-from-iOS-11.2.patch
	cd ../..
	cd build/make
	git am $BL/patches/0001-Fingerprint-release.patch
	git am $BL/patches/0001-Releasekey-description.patch
	git am $BL/patches/0001-Update-incremental.patch
	cd ../..
	cd packages/apps/Dialer
	git am $BL/patches/0001-Add-autorecord-calls.patch
	cd ../../..
	cd vendor/hardware_overlay
	git am $BL/patches/0001-Cleanup-overlay.patch
	cd ../..
	echo ""
	echo "CHECK PATCH STATUS NOW!"
	sleep 5
	echo ""
}

#sync_source
#patches_source

export WITHOUT_CHECK_API=true
export WITH_SU=false
mkdir -p ../build-output/

buildVariant() {
	cp system/sepolicy/private/vndk_detect.te system/sepolicy/prebuilts/api/29.0/private
	if ! cat device/phh/treble/AndroidProducts.mk | grep -q "${1}"; then
	    echo -e "\t\$(LOCAL_DIR)/s62v71c2k_jk_eea.mk \\" >> device/phh/treble/AndroidProducts.mk
	fi
	#lunch ${1}-userdebug
	lunch ${1}-user
	make installclean
	make -j$(nproc --all) systemimage
	#make -j2 systemimage
	#make vndk-test-sepolicy
	mv $OUT/system.img ../build-output/lineage-17.1-$BUILD_DATE-UNOFFICIAL-${1}.img
}

#buildVariant treble_arm_avN
#buildVariant treble_arm_bvN
#buildVariant treble_a64_avN
#buildVariant treble_a64_bvN
#buildVariant treble_arm64_avN
# v/g/o - without/with GAPPS/with Go GAPPS
# N/S - without/with SuperSU
#buildVariant treble_arm64_bvN
#buildVariant treble_arm64_bgN

buildVariant s62v71c2k_jk_eea

ls ../build-output | grep 'lineage'

END=`date +%s`
ELAPSEDM=$(($(($END-$START))/60))
ELAPSEDS=$(($(($END-$START))-$ELAPSEDM*60))
echo "Buildbot completed in $ELAPSEDM minutes and $ELAPSEDS seconds"
echo ""
