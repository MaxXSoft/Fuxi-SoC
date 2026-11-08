# Explicitly source this script from the U-Boot prompt; never name it boot.scr.
# flash.meta is data: import only size/hash, clearing old values on each run.
# Nested guards prevent later operations after failure. Old Hush lacks break
# and loses nested/expanded exit statuses; keep the literal exit 1 at top level.
# All accesses use the actual SD size; the imported size is compared as text.
# hash takes a variable NAME so missing/short digests fail instead of persisting.
setenv fuxi_flash_size
setenv fuxi_flash_sha256
setenv fuxi_update_error MMC
if mmc dev 0 && mmc rescan; then
    setenv fuxi_update_error META_SIZE
    if size mmc 0:1 flash.meta && itest ${filesize} -gt 0 && itest ${filesize} -le 0x200; then
        setenv fuxi_meta_size ${filesize}
        setenv fuxi_update_error META_LOAD
        if fatload mmc 0:1 0x02100000 flash.meta ${fuxi_meta_size} && itest ${filesize} == ${fuxi_meta_size}; then
            setenv fuxi_update_error META_IMPORT
            if env import -t -d 0x02100000 ${fuxi_meta_size} fuxi_flash_size fuxi_flash_sha256; then
                setenv fuxi_update_error INPUT_SIZE
                if size mmc 0:1 flash.bin && itest ${filesize} -ge 0x800058 && itest ${filesize} -le 0x1000000 && test "${fuxi_flash_size}" = "0x${filesize}"; then
                    setenv fuxi_image_size ${filesize}
                    setenv fuxi_update_error LOAD
                    if fatload mmc 0:1 0x10000000 flash.bin ${fuxi_image_size} && itest ${filesize} == ${fuxi_image_size}; then
                        setenv fuxi_update_error INPUT_HASH
                        if hash -v sha256 0x10000000 ${fuxi_image_size} fuxi_flash_sha256; then
                            setenv fuxi_update_error INPUT_HEADER
                            if itest.l *0x10000020 == 0xaa995566 && itest.l *0x10000024 == 0x584c4e58 && itest.l *0x10800000 == 0x49585546 && itest.l *0x10800004 == 0x00434f53; then
                                setenv fuxi_update_error PROBE
                                if sf probe 0:0; then
                                    echo Writing Fuxi image to QSPI offset zero
                                    setenv fuxi_update_error WRITE
                                    if sf update 0x10000000 0 ${fuxi_image_size}; then
                                        setenv fuxi_update_error VERIFY
                                        if sf read 0x12000000 0 ${fuxi_image_size} && cmp.b 0x10000000 0x12000000 ${fuxi_image_size}; then
                                            setenv fuxi_update_error
                                        fi
                                    fi
                                fi
                            fi
                        fi
                    fi
                fi
            fi
        fi
    fi
fi
if test -z "${fuxi_update_error}"; then
    echo FUXI_FLASH_VERIFY_PASS
    echo Power off, select QSPI boot, then power on
    exit 0
fi
echo FUXI_FLASH_${fuxi_update_error}_FAIL
exit 1
