set term pngcairo dashed size 900,600
set ylabel "Count"
set xlabel "Absolute profit (credits)"
set x2label "Relative profit" tc ls 4
set xrange [0:]
set xtics nomirror in tc ls 1
set x2tics auto nomirror tc ls 4

set style data lines

# data path
d="reward_data/"

set colorsequence podo

set style line 1 pt 1 lw 1 lt 1 dashtype 1
set style line 2 pt 2 lw 1 lt 2 dashtype 1
set style line 3 pt 1 lw 2 lt 1 dashtype 2
set style line 4 pt 2 lw 2 lt 2 dashtype 2

posx=-.13
posy=1.08


set output "trade.png"
set multiplot layout 1,1
#set label 1 "A" at graph posx, posy font "Arial-BoldMT,11"
plot "< ./histogram_from_file.py reward_data/trade_legal_Sol -c 0"  u 1:3 axes x1y1 ls 1 ti "legal absolute profit",\
     "< ./histogram_from_file.py reward_data/trade_ilegal_Sol -c 0" u 1:3 axes x1y1 ls 3 ti "ilegal absolute profit",\
     "< ./histogram_from_file.py reward_data/trade_legal_Sol -c 1"  u 1:3 axes x2y1 ls 2 ti "legal relative profit",\
     "< ./histogram_from_file.py reward_data/trade_ilegal_Sol -c 1" u 1:3 axes x2y1 ls 4 ti "ilegal relative profit"

unset title

# set label 1 "B"
# set xtics 5000
# plot "< ./histogram_from_file.py reward_data/taxi_single 500" u 1:3 axes x1y2 ls 3 noti,\
#      "< ./histogram_from_file.py reward_data/taxi_single 500" u 1:2 ls 4 ti "Taxi single"
# set label 1 "C"
# set xtics 50000
# plot "< ./histogram_from_file.py reward_data/taxi_group 500" u 1:3 axes x1y2 ls 5 noti,\
#      "< ./histogram_from_file.py reward_data/taxi_group 500" u 1:2 ls 6 ti "Taxi group"
unset multiplot
