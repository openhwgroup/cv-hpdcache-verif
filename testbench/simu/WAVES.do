onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -itemcolor #ffb400 /top/dut/clk_i
add wave -noupdate -itemcolor #ffb400 /top/dut/rst_ni
add wave -noupdate -group cfg -itemcolor #ffb400 /top/dut/cfg_wbuf_threshold_i
add wave -noupdate -group cfg -itemcolor #ffb400 /top/dut/cfg_wbuf_reset_timecnt_on_write_i
add wave -noupdate -group cfg -itemcolor #ffb400 /top/dut/cfg_wbuf_sequential_waw_i
add wave -noupdate -group cfg -itemcolor #ffb400 /top/dut/cfg_prefetch_updt_plru_i
add wave -noupdate -group cfg -itemcolor #ffb400 /top/dut/cfg_prefetch_sid_i
add wave -noupdate -group cfg -itemcolor #ffb400 /top/dut/cfg_error_on_cacheable_amo_i
add wave -noupdate -group cfg -itemcolor #ffb400 /top/dut/cfg_rtab_single_entry_i
add wave -noupdate -group evt -itemcolor #ffff1e /top/dut/evt_cache_write_miss_o
add wave -noupdate -group evt -itemcolor #ffff1e /top/dut/evt_cache_read_miss_o
add wave -noupdate -group evt -itemcolor #ffff1e /top/dut/evt_uncached_req_o
add wave -noupdate -group evt -itemcolor #ffff1e /top/dut/evt_cmo_req_o
add wave -noupdate -group evt -itemcolor #ffff1e /top/dut/evt_write_req_o
add wave -noupdate -group evt -itemcolor #ffff1e /top/dut/evt_read_req_o
add wave -noupdate -group evt -itemcolor #ffff1e /top/dut/evt_granted_req_o
add wave -noupdate -group evt -itemcolor #ffff1e /top/dut/evt_req_on_hold_o
add wave -noupdate -group core_req_rsp -itemcolor #ffb400 /top/dut/core_req_i
add wave -noupdate -group core_req_rsp -itemcolor #ffb400 /top/dut/core_req_valid_i
add wave -noupdate -group core_req_rsp -itemcolor #ffff1e /top/dut/core_req_ready_o
add wave -noupdate -group core_req_rsp -itemcolor #ffff1e /top/dut/core_rsp_o
add wave -noupdate -group core_req_rsp -itemcolor #ffff1e /top/dut/core_rsp_valid_o
add wave -noupdate -group wbuf -itemcolor #ffb400 /top/dut/wbuf_flush_i
add wave -noupdate -group wbuf -itemcolor #ffb400 /top/dut/mem_req_wbuf_write_ready_i
add wave -noupdate -group wbuf -itemcolor #ffb400 /top/dut/mem_req_wbuf_write_base_id_i
add wave -noupdate -group wbuf -itemcolor #ffb400 /top/dut/mem_req_wbuf_write_data_ready_i
add wave -noupdate -group wbuf -itemcolor #ffb400 /top/dut/mem_resp_wbuf_write_valid_i
add wave -noupdate -group wbuf -itemcolor #ffb400 /top/dut/mem_resp_wbuf_write_i
add wave -noupdate -group wbuf -itemcolor #ffb400 /top/dut/cfg_wbuf_threshold_i
add wave -noupdate -group wbuf -itemcolor #ffb400 /top/dut/cfg_wbuf_reset_timecnt_on_write_i
add wave -noupdate -group wbuf -itemcolor #ffb400 /top/dut/cfg_wbuf_sequential_waw_i
add wave -noupdate -group wbuf -itemcolor #ffff1e /top/dut/mem_req_wbuf_write_valid_o
add wave -noupdate -group wbuf -itemcolor #ffff1e /top/dut/mem_req_wbuf_write_o
add wave -noupdate -group wbuf -itemcolor #ffff1e /top/dut/mem_req_wbuf_write_data_valid_o
add wave -noupdate -group wbuf -itemcolor #ffff1e /top/dut/mem_req_wbuf_write_data_o
add wave -noupdate -group wbuf -itemcolor #ffff1e /top/dut/mem_resp_wbuf_write_ready_o
add wave -noupdate -group wbuf -itemcolor #ffff1e /top/dut/wbuf_empty_o
add wave -noupdate -group uc_req_rsp -itemcolor #ffb400 /top/dut/mem_req_uc_read_ready_i
add wave -noupdate -group uc_req_rsp -itemcolor #ffb400 /top/dut/mem_req_uc_read_base_id_i
add wave -noupdate -group uc_req_rsp -itemcolor #ffb400 /top/dut/mem_resp_uc_read_valid_i
add wave -noupdate -group uc_req_rsp -itemcolor #ffb400 /top/dut/mem_resp_uc_read_i
add wave -noupdate -group uc_req_rsp -itemcolor #ffb400 /top/dut/mem_req_uc_write_ready_i
add wave -noupdate -group uc_req_rsp -itemcolor #ffb400 /top/dut/mem_req_uc_write_base_id_i
add wave -noupdate -group uc_req_rsp -itemcolor #ffb400 /top/dut/mem_req_uc_write_data_ready_i
add wave -noupdate -group uc_req_rsp -itemcolor #ffb400 /top/dut/mem_resp_uc_write_valid_i
add wave -noupdate -group uc_req_rsp -itemcolor #ffb400 /top/dut/mem_resp_uc_write_i
add wave -noupdate -group uc_req_rsp -itemcolor #ffff1e /top/dut/mem_req_uc_read_valid_o
add wave -noupdate -group uc_req_rsp -itemcolor #ffff1e /top/dut/mem_req_uc_read_o
add wave -noupdate -group uc_req_rsp -itemcolor #ffff1e /top/dut/mem_resp_uc_read_ready_o
add wave -noupdate -group uc_req_rsp -itemcolor #ffff1e /top/dut/mem_req_uc_write_valid_o
add wave -noupdate -group uc_req_rsp -itemcolor #ffff1e /top/dut/mem_req_uc_write_o
add wave -noupdate -group uc_req_rsp -itemcolor #ffff1e /top/dut/mem_req_uc_write_data_valid_o
add wave -noupdate -group uc_req_rsp -itemcolor #ffff1e /top/dut/mem_req_uc_write_data_o
add wave -noupdate -group uc_req_rsp -itemcolor #ffff1e /top/dut/mem_resp_uc_write_ready_o
add wave -noupdate -group miss_req_rsp -itemcolor #ffb400 /top/dut/mem_req_miss_read_ready_i
add wave -noupdate -group miss_req_rsp -itemcolor #ffb400 /top/dut/mem_req_miss_read_base_id_i
add wave -noupdate -group miss_req_rsp -itemcolor #ffb400 /top/dut/mem_resp_miss_read_valid_i
add wave -noupdate -group miss_req_rsp -itemcolor #ffb400 /top/dut/mem_resp_miss_read_i
add wave -noupdate -group miss_req_rsp -itemcolor #ffff1e /top/dut/mem_req_miss_read_valid_o
add wave -noupdate -group miss_req_rsp -itemcolor #ffff1e /top/dut/mem_req_miss_read_o
add wave -noupdate -group miss_req_rsp -itemcolor #ffff1e /top/dut/mem_resp_miss_read_ready_o
add wave -noupdate -group refill_internal /top/dut/refill_req_valid
add wave -noupdate -group refill_internal /top/dut/refill_req_ready
add wave -noupdate -group refill_internal /top/dut/refill_busy
add wave -noupdate -group refill_internal /top/dut/refill_updt_plru
add wave -noupdate -group refill_internal /top/dut/refill_set
add wave -noupdate -group refill_internal /top/dut/refill_dir_entry
add wave -noupdate -group refill_internal /top/dut/refill_read_victim_way
add wave -noupdate -group refill_internal /top/dut/refill_write_victim_way
add wave -noupdate -group refill_internal /top/dut/refill_write_dir
add wave -noupdate -group refill_internal /top/dut/refill_write_data
add wave -noupdate -group refill_internal /top/dut/refill_word
add wave -noupdate -group refill_internal /top/dut/refill_data
add wave -noupdate -group refill_internal /top/dut/refill_core_rsp_valid
add wave -noupdate -group refill_internal /top/dut/refill_core_rsp
add wave -noupdate -group refill_internal /top/dut/refill_nline
add wave -noupdate /top/mem_rsp_if/req_AMOS
add wave -noupdate /top/mem_rsp_if/amo_op
add wave -noupdate /top/mem_rsp_if/req_OP
add wave -noupdate /top/mem_rsp_if/req_wrn
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {273500 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 150
configure wave -valuecolwidth 211
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {3824327 ps} {3875014 ps}
