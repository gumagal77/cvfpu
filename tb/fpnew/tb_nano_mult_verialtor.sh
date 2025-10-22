script_dir=$(dirname "$(readlink -f "$0")")
warning_disable='-Wno-style -Wno-PINCONNECTEMPTY -Wno-TIMESCALEMOD -Wno-ASCRANGE -Wno-WIDTHEXPAND -Wno-PINMISSING -Wno-WIDTHTRUNC -Wno-UNSIGNED -Wno-UNOPTFLAT -Wno-BLKANDNBLK'
module_name=fpnew_fma_nano
tb_name="tb_nano_mult"
#echo $script_dir
verilator --binary -j 0 $warning_disable -I$script_dir/../../src/common_cells/include -I$script_dir/../../src/ $script_dir/../../src/common_cells/src/cf_math_pkg.sv $script_dir/../../src/common_cells/src/lzc.sv $script_dir/../../src/common_cells/src/rr_arb_tree.sv $script_dir/../../src/fpnew_fma_nano.sv $script_dir/${tb_name}.sv --top-module ${tb_name} --trace && $script_dir/obj_dir/V"${tb_name}" > $script_dir/"${tb_name}"_output.txt