#=====================================================================
# system.xdc  -  2D FFT Range-Doppler Map (ZSK / ZedBoard XC7Z020-CLG484-1)
#---------------------------------------------------------------------
#  �?�트 �?�름�?� 블�?디�?�?� Make External 결과(system_wrapper)를 그대로 사용:
#    - LCD 출력 : rgb_lcd_0[23:0], hsync_0, vsync_0, lcd_clk_0,
#                 lcd_de_0, lcd_ud_0, lcd_bl_0
#    - 스위치   : btns_5bits_tri_i[4:0]  (GPIO width 2 -> [0],[1]만 사용)
#  sys_clk / sys_rst_n �?� PS가 내부�?서 공급하므로 여기서 제약하지 않�?�.
#  DDR_* / FIXED_IO_* 는 ZedBoard 프리셋�?� �?�?� 처리하므로 �?지 않�?�.
#  핀 번호는 �?수 lcd.xdc / sw_led.xdc 값.
#=====================================================================

#---------------------------------------------------------------------
# LCD �?�기/제어 신호
#---------------------------------------------------------------------
set_property -dict {PACKAGE_PIN J16 IOSTANDARD LVCMOS33} [get_ports hsync_0]
set_property -dict {PACKAGE_PIN J17 IOSTANDARD LVCMOS33} [get_ports vsync_0]
set_property -dict {PACKAGE_PIN L18 IOSTANDARD LVCMOS33} [get_ports lcd_clk_0]
set_property -dict {PACKAGE_PIN N20 IOSTANDARD LVCMOS33} [get_ports lcd_bl_0]
set_property -dict {PACKAGE_PIN B21 IOSTANDARD LVCMOS33} [get_ports lcd_ud_0]
set_property -dict {PACKAGE_PIN D15 IOSTANDARD LVCMOS33} [get_ports lcd_de_0]

#---------------------------------------------------------------------
# LCD RGB 888 (24-bit)
#---------------------------------------------------------------------
set_property -dict {PACKAGE_PIN D20 IOSTANDARD LVCMOS33} [get_ports {rgb_lcd_0[23]}]
set_property -dict {PACKAGE_PIN C17 IOSTANDARD LVCMOS33} [get_ports {rgb_lcd_0[22]}]
set_property -dict {PACKAGE_PIN C18 IOSTANDARD LVCMOS33} [get_ports {rgb_lcd_0[21]}]
set_property -dict {PACKAGE_PIN A16 IOSTANDARD LVCMOS33} [get_ports {rgb_lcd_0[20]}]
set_property -dict {PACKAGE_PIN C20 IOSTANDARD LVCMOS33} [get_ports {rgb_lcd_0[19]}]
set_property -dict {PACKAGE_PIN A17 IOSTANDARD LVCMOS33} [get_ports {rgb_lcd_0[18]}]
set_property -dict {PACKAGE_PIN B16 IOSTANDARD LVCMOS33} [get_ports {rgb_lcd_0[17]}]
set_property -dict {PACKAGE_PIN B17 IOSTANDARD LVCMOS33} [get_ports {rgb_lcd_0[16]}]

set_property -dict {PACKAGE_PIN E19 IOSTANDARD LVCMOS33} [get_ports {rgb_lcd_0[15]}]
set_property -dict {PACKAGE_PIN F19 IOSTANDARD LVCMOS33} [get_ports {rgb_lcd_0[14]}]
set_property -dict {PACKAGE_PIN E20 IOSTANDARD LVCMOS33} [get_ports {rgb_lcd_0[13]}]
set_property -dict {PACKAGE_PIN E18 IOSTANDARD LVCMOS33} [get_ports {rgb_lcd_0[12]}]
set_property -dict {PACKAGE_PIN D22 IOSTANDARD LVCMOS33} [get_ports {rgb_lcd_0[11]}]
set_property -dict {PACKAGE_PIN A18 IOSTANDARD LVCMOS33} [get_ports {rgb_lcd_0[10]}]
set_property -dict {PACKAGE_PIN C22 IOSTANDARD LVCMOS33} [get_ports {rgb_lcd_0[9]}]
set_property -dict {PACKAGE_PIN A19 IOSTANDARD LVCMOS33} [get_ports {rgb_lcd_0[8]}]

set_property -dict {PACKAGE_PIN E21 IOSTANDARD LVCMOS33} [get_ports {rgb_lcd_0[7]}]
set_property -dict {PACKAGE_PIN G20 IOSTANDARD LVCMOS33} [get_ports {rgb_lcd_0[6]}]
set_property -dict {PACKAGE_PIN G21 IOSTANDARD LVCMOS33} [get_ports {rgb_lcd_0[5]}]
set_property -dict {PACKAGE_PIN G15 IOSTANDARD LVCMOS33} [get_ports {rgb_lcd_0[4]}]
set_property -dict {PACKAGE_PIN D21 IOSTANDARD LVCMOS33} [get_ports {rgb_lcd_0[3]}]
set_property -dict {PACKAGE_PIN G16 IOSTANDARD LVCMOS33} [get_ports {rgb_lcd_0[2]}]
set_property -dict {PACKAGE_PIN G19 IOSTANDARD LVCMOS33} [get_ports {rgb_lcd_0[1]}]
set_property -dict {PACKAGE_PIN F18 IOSTANDARD LVCMOS33} [get_ports {rgb_lcd_0[0]}]

#---------------------------------------------------------------------
# 스위치 (모드 선�?)  -  GPIO 2개만 실제 사용
#   sw[0]=P16 -> btns_5bits_tri_i[0],  sw[1]=N15 -> btns_5bits_tri_i[1]
#---------------------------------------------------------------------
set_property -dict {PACKAGE_PIN P16 IOSTANDARD LVCMOS33} [get_ports {GPIO_0_tri_i[0]}]
set_property -dict {PACKAGE_PIN N15 IOSTANDARD LVCMOS33} [get_ports {GPIO_0_tri_i[1]}]

#---------------------------------------------------------------------
# btns_5bits_tri_i[4:2] 는 GPIO(width=2)�?서 실제로 쓰지 않는 비트.
# �?�트는 5비트로 존재하므로 미할당 I/O DRC(UCIO-1)를 경고로 낮춰
# 비트스트림 �?성�?� 막지 않�?��? 한다.
#---------------------------------------------------------------------

