#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# Script to generate visual SVG digital waveform diagrams for NN Accelerator SoC verification
import os

uart_svg = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1150 560" width="1150" height="560" style="background:#1e1e2e; font-family:'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
  <defs>
    <linearGradient id="gridGrad" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#313244" stop-opacity="0.3"/>
      <stop offset="100%" stop-color="#181825" stop-opacity="0.8"/>
    </linearGradient>
    <filter id="shadow" x="-5%" y="-5%" width="110%" height="110%">
      <feDropShadow dx="0" dy="2" stdDeviation="3" flood-color="#000" flood-opacity="0.5"/>
    </filter>
  </defs>

  <!-- Title & Header Bar -->
  <rect x="0" y="0" width="1150" height="55" fill="#181825"/>
  <text x="25" y="35" fill="#89b4fa" font-size="20" font-weight="bold">UART End-to-End Verification Waveform (VeeR EL2 NN Accelerator SoC)</text>
  <text x="750" y="35" fill="#a6adc8" font-size="14">Data: 0x50 ('P') | Baud: 115200 (8-N-1) | Clks/bit: 434</text>
  <line x1="0" y1="55" x2="1150" y2="55" stroke="#45475a" stroke-width="1.5"/>

  <!-- Left Sidebar (Signal Names) -->
  <rect x="0" y="55" width="230" height="505" fill="#11111b"/>
  <line x1="230" y1="55" x2="230" y2="560" stroke="#45475a" stroke-width="2"/>

  <!-- Time Header Bar -->
  <rect x="230" y="55" width="920" height="35" fill="#181825"/>
  <line x1="230" y1="90" x2="1150" y2="90" stroke="#313244" stroke-width="1"/>

  <!-- Time Axis Markers -->
  <text x="250" y="78" fill="#6c7086" font-size="11">0 us</text>
  <text x="325" y="78" fill="#f38ba8" font-size="11" font-weight="bold">START (0)</text>
  <text x="400" y="78" fill="#a6e3a1" font-size="11">D0 (0)</text>
  <text x="475" y="78" fill="#a6e3a1" font-size="11">D1 (0)</text>
  <text x="550" y="78" fill="#a6e3a1" font-size="11">D2 (0)</text>
  <text x="625" y="78" fill="#a6e3a1" font-size="11">D3 (0)</text>
  <text x="700" y="78" fill="#a6e3a1" font-size="11">D4 (1)</text>
  <text x="775" y="78" fill="#a6e3a1" font-size="11">D5 (0)</text>
  <text x="850" y="78" fill="#a6e3a1" font-size="11">D6 (1)</text>
  <text x="925" y="78" fill="#a6e3a1" font-size="11">D7 (0)</text>
  <text x="1000" y="78" fill="#f9e2af" font-size="11" font-weight="bold">STOP (1)</text>
  <text x="1075" y="78" fill="#6c7086" font-size="11">IDLE</text>

  <!-- Vertical Grid Guidelines -->
  <g stroke="#313244" stroke-width="1" stroke-dasharray="3,3">
    <line x1="310" y1="90" x2="310" y2="550"/>
    <line x1="385" y1="90" x2="385" y2="550"/>
    <line x1="460" y1="90" x2="460" y2="550"/>
    <line x1="535" y1="90" x2="535" y2="550"/>
    <line x1="610" y1="90" x2="610" y2="550"/>
    <line x1="685" y1="90" x2="685" y2="550"/>
    <line x1="760" y1="90" x2="760" y2="550"/>
    <line x1="835" y1="90" x2="835" y2="550"/>
    <line x1="910" y1="90" x2="910" y2="550"/>
    <line x1="985" y1="90" x2="985" y2="550"/>
    <line x1="1060" y1="90" x2="1060" y2="550"/>
  </g>

  <!-- Signal 1: clk (50 MHz) -->
  <text x="20" y="125" fill="#cdd6f4" font-size="13" font-weight="bold">clk (50MHz)</text>
  <path d="M 230 130 L 245 130 L 245 105 L 260 105 L 260 130 L 275 130 L 275 105 L 290 105 L 290 130 L 305 130 L 305 105 L 320 105 L 320 130 L 335 130 L 335 105 L 350 105 L 350 130 L 365 130 L 365 105 L 380 105 L 380 130 L 395 130 L 395 105 L 410 105 L 410 130 L 425 130 L 425 105 L 440 105 L 440 130 L 455 130 L 455 105 L 470 105 L 470 130 L 485 130 L 485 105 L 500 105 L 500 130 L 515 130 L 515 105 L 530 105 L 530 130 L 545 130 L 545 105 L 560 105 L 560 130 L 575 130 L 575 105 L 590 105 L 590 130 L 605 130 L 605 105 L 620 105 L 620 130 L 635 130 L 635 105 L 650 105 L 650 130 L 665 130 L 665 105 L 680 105 L 680 130 L 695 130 L 695 105 L 710 105 L 710 130 L 725 130 L 725 105 L 740 105 L 740 130 L 755 130 L 755 105 L 770 105 L 770 130 L 785 130 L 785 105 L 800 105 L 800 130 L 815 130 L 815 105 L 830 105 L 830 130 L 845 130 L 845 105 L 860 105 L 860 130 L 875 130 L 875 105 L 890 105 L 890 130 L 905 130 L 905 105 L 920 105 L 920 130 L 935 130 L 935 105 L 950 105 L 950 130 L 965 130 L 965 105 L 980 105 L 980 130 L 995 130 L 995 105 L 1010 105 L 1010 130 L 1025 130 L 1025 105 L 1040 105 L 1040 130 L 1055 130 L 1055 105 L 1070 105 L 1070 130 L 1085 130 L 1085 105 L 1100 105 L 1100 130 L 1115 130 L 1115 105 L 1130 105 L 1130 130 L 1150 130" fill="none" stroke="#89dceb" stroke-width="1.5"/>

  <!-- Signal 2: rst_n -->
  <text x="20" y="175" fill="#cdd6f4" font-size="13" font-weight="bold">rst_n</text>
  <path d="M 230 180 L 260 180 L 260 155 L 1150 155" fill="none" stroke="#a6e3a1" stroke-width="2"/>

  <!-- Signal 3: uart_tx (Serial Data) -->
  <text x="20" y="235" fill="#cdd6f4" font-size="13" font-weight="bold">uart_tx</text>
  <!-- Idle=High, Start=Low(310..385), D0..D3=Low(385..685), D4=High(685..760), D5=Low(760..835), D6=High(835..910), D7=Low(910..985), Stop=High(985..1150) -->
  <path d="M 230 210 L 310 210 L 310 240 L 685 240 L 685 210 L 760 210 L 760 240 L 835 240 L 835 210 L 910 210 L 910 240 L 985 240 L 985 210 L 1150 210" fill="none" stroke="#f38ba8" stroke-width="2.5"/>

  <!-- Signal 4: tx_busy -->
  <text x="20" y="295" fill="#cdd6f4" font-size="13" font-weight="bold">tx_busy</text>
  <path d="M 230 300 L 310 300 L 310 270 L 1060 270 L 1060 300 L 1150 300" fill="none" stroke="#fab387" stroke-width="2"/>

  <!-- Signal 5: tx_fifo_empty -->
  <text x="20" y="355" fill="#cdd6f4" font-size="13" font-weight="bold">tx_fifo_empty</text>
  <path d="M 230 330 L 300 330 L 300 360 L 310 360 L 310 330 L 1150 330" fill="none" stroke="#f9e2af" stroke-width="2"/>

  <!-- Signal 6: baud_tick (Pulse per bit) -->
  <text x="20" y="415" fill="#cdd6f4" font-size="13" font-weight="bold">baud_tick</text>
  <path d="M 230 420 L 310 420 L 310 395 L 313 395 L 313 420 L 385 420 L 385 395 L 388 395 L 388 420 L 460 420 L 460 395 L 463 395 L 463 420 L 535 420 L 535 395 L 538 395 L 538 420 L 610 420 L 610 395 L 613 395 L 613 420 L 685 420 L 685 395 L 688 395 L 688 420 L 760 420 L 760 395 L 763 395 L 763 420 L 835 420 L 835 395 L 838 395 L 838 420 L 910 420 L 910 395 L 913 395 L 913 420 L 985 420 L 985 395 L 988 395 L 988 420 L 1060 420 L 1060 395 L 1063 395 L 1063 420 L 1150 420" fill="none" stroke="#b4befe" stroke-width="1.8"/>

  <!-- Signal 7: AXI4-Lite LSU Access -->
  <text x="20" y="475" fill="#cdd6f4" font-size="13" font-weight="bold">LSU AXI Write</text>
  <rect x="270" y="460" width="40" height="25" rx="3" fill="#89b4fa" fill-opacity="0.3" stroke="#89b4fa" stroke-width="1.5"/>
  <text x="275" y="477" fill="#89b4fa" font-size="11" font-weight="bold">0x50</text>
  <line x1="230" y1="485" x2="270" y2="485" stroke="#6c7086" stroke-width="1.5"/>
  <line x1="310" y1="485" x2="1150" y2="485" stroke="#6c7086" stroke-width="1.5"/>

  <!-- Signal 8: irq_uart -->
  <text x="20" y="535" fill="#cdd6f4" font-size="13" font-weight="bold">irq_uart</text>
  <path d="M 230 540 L 1060 540 L 1060 515 L 1110 515 L 1110 540 L 1150 540" fill="none" stroke="#cba6f7" stroke-width="2"/>
</svg>
"""

nn_svg = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1200 620" width="1200" height="620" style="background:#1e1e2e; font-family:'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
  <!-- Title & Header Bar -->
  <rect x="0" y="0" width="1200" height="60" fill="#181825"/>
  <text x="25" y="38" fill="#a6e3a1" font-size="22" font-weight="bold">Neural Network Accelerator SoC Inference Waveform (VeeR EL2 Core)</text>
  <text x="780" y="38" fill="#a6adc8" font-size="13">Pipeline: DMA Load -> Q16.16 MAC Mult -> Streaming ReLU -> Result Verification</text>
  <line x1="0" y1="60" x2="1200" y2="60" stroke="#45475a" stroke-width="2"/>

  <!-- Sidebar -->
  <rect x="0" y="60" width="240" height="560" fill="#11111b"/>
  <line x1="240" y1="60" x2="240" y2="620" stroke="#45475a" stroke-width="2"/>

  <!-- Time Header Bar -->
  <rect x="240" y="60" width="960" height="35" fill="#181825"/>
  <line x1="240" y1="95" x2="1200" y2="95" stroke="#313244" stroke-width="1"/>

  <text x="270" y="82" fill="#6c7086" font-size="11">0 us (Boot)</text>
  <text x="400" y="82" fill="#89b4fa" font-size="11" font-weight="bold">DMA_BURST_LOAD</text>
  <text x="600" y="82" fill="#f9e2af" font-size="11" font-weight="bold">MAT_COMPUTE (Y=W*X+B)</text>
  <text x="820" y="82" fill="#a6e3a1" font-size="11" font-weight="bold">ACT_STREAM_RELU</text>
  <text x="1030" y="82" fill="#cba6f7" font-size="11" font-weight="bold">UART_PASS_BANNER</text>

  <!-- Guidelines -->
  <g stroke="#313244" stroke-width="1" stroke-dasharray="3,3">
    <line x1="380" y1="95" x2="380" y2="610"/>
    <line x1="580" y1="95" x2="580" y2="610"/>
    <line x1="800" y1="95" x2="800" y2="610"/>
    <line x1="1010" y1="95" x2="1010" y2="610"/>
  </g>

  <!-- 1. clk -->
  <text x="20" y="125" fill="#cdd6f4" font-size="13" font-weight="bold">clk (50MHz)</text>
  <path d="M 240 130 L 250 130 L 250 110 L 260 110 L 260 130 L 270 130 L 270 110 L 280 110 L 280 130 L 290 130 L 290 110 L 300 110 L 300 130 L 310 130 L 310 110 L 320 110 L 320 130 L 330 130 L 330 110 L 340 110 L 340 130 L 350 130 L 350 110 L 360 110 L 360 130 L 370 130 L 370 110 L 380 110 L 380 130 L 390 130 L 390 110 L 400 110 L 400 130 L 410 130 L 410 110 L 420 110 L 420 130 L 430 130 L 430 110 L 440 110 L 440 130 L 450 130 L 450 110 L 460 110 L 460 130 L 470 130 L 470 110 L 480 110 L 480 130 L 490 130 L 490 110 L 500 110 L 500 130 L 510 130 L 510 110 L 520 110 L 520 130 L 530 130 L 530 110 L 540 110 L 540 130 L 550 130 L 550 110 L 560 110 L 560 130 L 570 130 L 570 110 L 580 110 L 580 130 L 590 130 L 590 110 L 600 110 L 600 130 L 610 130 L 610 110 L 620 110 L 620 130 L 630 130 L 630 110 L 640 110 L 640 130 L 650 130 L 650 110 L 660 110 L 660 130 L 670 130 L 670 110 L 680 110 L 680 130 L 690 130 L 690 110 L 700 110 L 700 130 L 710 130 L 710 110 L 720 110 L 720 130 L 730 130 L 730 110 L 740 110 L 740 130 L 750 130 L 750 110 L 760 110 L 760 130 L 770 130 L 770 110 L 780 110 L 780 130 L 790 130 L 790 110 L 800 110 L 800 130 L 810 130 L 810 110 L 820 110 L 820 130 L 830 130 L 830 110 L 840 110 L 840 130 L 850 130 L 850 110 L 860 110 L 860 130 L 870 130 L 870 110 L 880 110 L 880 130 L 890 130 L 890 110 L 900 110 L 900 130 L 910 130 L 910 110 L 920 110 L 920 130 L 930 130 L 930 110 L 940 110 L 940 130 L 950 130 L 950 110 L 960 110 L 960 130 L 970 130 L 970 110 L 980 110 L 980 130 L 990 130 L 990 110 L 1000 110 L 1000 130 L 1010 130 L 1010 110 L 1020 110 L 1020 130 L 1030 130 L 1030 110 L 1040 110 L 1040 130 L 1050 130 L 1050 110 L 1060 110 L 1060 130 L 1070 130 L 1070 110 L 1080 110 L 1080 130 L 1090 130 L 1090 110 L 1100 110 L 1100 130 L 1110 130 L 1110 110 L 1120 110 L 1120 130 L 1130 130 L 1130 110 L 1140 110 L 1140 130 L 1150 130 L 1150 110 L 1160 110 L 1160 130 L 1170 130 L 1170 110 L 1180 110 L 1180 130 L 1200 130" fill="none" stroke="#89dceb" stroke-width="1.5"/>

  <!-- 2. dma_busy & burst -->
  <text x="20" y="175" fill="#cdd6f4" font-size="13" font-weight="bold">dma_busy / burst</text>
  <path d="M 240 185 L 380 185 L 380 160 L 560 160 L 560 185 L 1200 185" fill="none" stroke="#89b4fa" stroke-width="2"/>
  <rect x="400" y="162" width="140" height="20" rx="3" fill="#89b4fa" fill-opacity="0.3"/>
  <text x="415" y="177" fill="#89b4fa" font-size="11" font-weight="bold">AXI4 ARLEN=7 INCR</text>

  <!-- 3. mm_busy & compute -->
  <text x="20" y="235" fill="#cdd6f4" font-size="13" font-weight="bold">mm_busy (Matrix)</text>
  <path d="M 240 245 L 580 245 L 580 220 L 780 220 L 780 245 L 1200 245" fill="none" stroke="#f9e2af" stroke-width="2.5"/>

  <!-- 4. mm_mac_accum -->
  <text x="20" y="295" fill="#cdd6f4" font-size="13" font-weight="bold">mm_mac_accum</text>
  <line x1="240" y1="295" x2="580" y2="295" stroke="#6c7086" stroke-width="1.5"/>
  <rect x="590" y="280" width="85" height="24" rx="3" fill="#fab387" fill-opacity="0.3" stroke="#fab387" stroke-width="1.5"/>
  <text x="595" y="296" fill="#fab387" font-size="11">0x0002_C000</text>
  <rect x="685" y="280" width="85" height="24" rx="3" fill="#fab387" fill-opacity="0.3" stroke="#fab387" stroke-width="1.5"/>
  <text x="690" y="296" fill="#fab387" font-size="11">0xFFFD_8000</text>
  <line x1="775" y1="295" x2="1200" y2="295" stroke="#6c7086" stroke-width="1.5"/>

  <!-- 5. stream_act_valid / data -->
  <text x="20" y="355" fill="#cdd6f4" font-size="13" font-weight="bold">stream_act_valid</text>
  <path d="M 240 365 L 770 365 L 770 340 L 820 340 L 820 365 L 1200 365" fill="none" stroke="#a6e3a1" stroke-width="2"/>

  <!-- 6. act_busy (Activation) -->
  <text x="20" y="415" fill="#cdd6f4" font-size="13" font-weight="bold">act_busy (ReLU)</text>
  <path d="M 240 425 L 800 425 L 800 400 L 980 400 L 980 425 L 1200 425" fill="none" stroke="#a6e3a1" stroke-width="2.5"/>

  <!-- 7. act_out_data -->
  <text x="20" y="475" fill="#cdd6f4" font-size="13" font-weight="bold">act_out_data (Z)</text>
  <line x1="240" y1="475" x2="820" y2="475" stroke="#6c7086" stroke-width="1.5"/>
  <rect x="830" y="460" width="70" height="24" rx="3" fill="#a6e3a1" fill-opacity="0.3" stroke="#a6e3a1" stroke-width="1.5"/>
  <text x="835" y="476" fill="#a6e3a1" font-size="11">0x0002C000</text>
  <rect x="910" y="460" width="65" height="24" rx="3" fill="#a6e3a1" fill-opacity="0.3" stroke="#a6e3a1" stroke-width="1.5"/>
  <text x="915" y="476" fill="#a6e3a1" font-size="11">0x00000000</text>
  <line x1="980" y1="475" x2="1200" y2="475" stroke="#6c7086" stroke-width="1.5"/>

  <!-- 8. acc_done & gpio_pass -->
  <text x="20" y="535" fill="#cdd6f4" font-size="13" font-weight="bold">acc_done / gpio</text>
  <path d="M 240 545 L 980 545 L 980 520 L 1200 520" fill="none" stroke="#cba6f7" stroke-width="2"/>
  <rect x="1010" y="515" width="120" height="25" rx="3" fill="#cba6f7" fill-opacity="0.4" stroke="#cba6f7" stroke-width="1.5"/>
  <text x="1020" y="532" fill="#cba6f7" font-size="12" font-weight="bold">GPIO: 0xAA55 PASS</text>

  <!-- 9. uart_tx string output -->
  <text x="20" y="585" fill="#cdd6f4" font-size="13" font-weight="bold">uart_tx</text>
  <path d="M 240 590 L 1020 590 L 1025 575 L 1030 590 L 1040 575 L 1050 590 L 1060 575 L 1070 590 L 1080 575 L 1090 590 L 1100 575 L 1110 590 L 1120 575 L 1130 590 L 1140 575 L 1150 590 L 1200 575" fill="none" stroke="#f38ba8" stroke-width="1.8"/>
  <text x="1040" y="605" fill="#f38ba8" font-size="10">"[TEST PASSED]"</text>
</svg>
"""

with open("uart_waveform.svg", "w") as f:
    f.write(uart_svg)

with open("nn_inference_waveform.svg", "w") as f:
    f.write(nn_svg)

print("Generated waveform SVG diagrams: uart_waveform.svg, nn_inference_waveform.svg")
