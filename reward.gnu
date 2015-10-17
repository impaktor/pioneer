set term pngcairo dashed size 600,900
set ylabel "Probability"
set ytics nomirror
set y2label "Count"
set y2tics auto nomirror
set xlabel "Reward (credits)"
set xrange [0:]

# set style data lines
set style data boxes
set style fill solid
set boxwidth 0.95 relative

# data path
d="reward_data/"

set colorsequence podo

set style line 1 pt 1 lw 1 lt 1 lc rgb "#ffffff" dashtype 1
set style line 2 pt 1 lw 2 lt 1 dashtype 1
set style line 3 pt 2 lw 1 lt 2 lc rgb "#ffffff" dashtype 1
set style line 4 pt 2 lw 2 lt 2 dashtype 1
set style line 5 pt 3 lw 1 lt 3 lc rgb "#ffffff" dashtype 1
set style line 6 pt 3 lw 2 lt 3 dashtype 1


posx=-.22
posy=1.13

set output "taxi.png"
set multiplot layout 3,1
set title "Taxi missions"
set label 1 "A" at graph posx, posy font "Arial-BoldMT,11"
set xtics 50000
plot "< ./histogram_from_file.py reward_data/taxi -b 500" u 1:3 axes x1y2 ls 1 noti,\
     "< ./histogram_from_file.py reward_data/taxi -b 500" u 1:2 ls 2 ti "Taxi"
unset title
set label 1 "B"
set xtics 5000
plot "< ./histogram_from_file.py reward_data/taxi_single -b 500" u 1:3 axes x1y2 ls 3 noti,\
     "< ./histogram_from_file.py reward_data/taxi_single -b 500" u 1:2 ls 4 ti "Taxi single"
set label 1 "C"
set xtics 50000
plot "< ./histogram_from_file.py reward_data/taxi_group -b 500" u 1:3 axes x1y2 ls 5 noti,\
     "< ./histogram_from_file.py reward_data/taxi_group -b 500" u 1:2 ls 6 ti "Taxi group"
unset multiplot

set output "cargo.png"
set multiplot layout 3,1
set title "Cargo missions"
set label 1 "A" at graph posx, posy font "Arial-BoldMT,11"
set xtics 5000
plot "< ./histogram_from_file.py reward_data/cargorun -b 500" u 1:3 axes x1y2 ls 1 noti,\
     "< ./histogram_from_file.py reward_data/cargorun -b 500" u 1:2 ls 2 ti "Cargorun"
unset title
set label 1 "B"
set xtics 200
plot "< ./histogram_from_file.py reward_data/cargorun_local -b 100" u 1:3 axes x1y2 ls 3 noti,\
     "< ./histogram_from_file.py reward_data/cargorun_local -b 100" u 1:2 ls 4 ti "Cargorun local"
set label 1 "C"
set xtics 2000
plot "< ./histogram_from_file.py reward_data/cargorun_nonlocal -b 500" u 1:3 axes x1y2 ls 5 noti,\
     "< ./histogram_from_file.py reward_data/cargorun_nonlocal -b 500" u 1:2 ls 6 ti "Cargorun nonlocal"
unset multiplot

set output "package.png"
set multiplot layout 3,1
set title "DeliverPackage missions"
set label 1 "A" at graph posx, posy font "Arial-BoldMT,11"
set xtics 800
plot "< ./histogram_from_file.py reward_data/deliverpackage -b 500" u 1:3 axes x1y2 ls 1 noti,\
     "< ./histogram_from_file.py reward_data/deliverpackage -b 500" u 1:2 ls 2 ti "Package"
unset title
set label 1 "B"
set xtics 50
plot "< ./histogram_from_file.py reward_data/deliverpackage_local -b 50" u 1:3 axes x1y2 ls 3 noti,\
     "< ./histogram_from_file.py reward_data/deliverpackage_local -b 50" u 1:2 ls 4 ti "Package local"
set label 1 "C"
set xtics 1000
plot "< ./histogram_from_file.py reward_data/deliverpackage_nonlocal -b 100" u 1:3 axes x1y2 ls 5 noti,\
     "< ./histogram_from_file.py reward_data/deliverpackage_nonlocal -b 100" u 1:2 ls 6 ti "Package nonlocal"
unset multiplot

set term png enhanced size 900,500
set output "assassin.png"
set xtics 5000
plot "< ./histogram_from_file.py reward_data/assassin -b 200" u 1:3 axes x1y2 ls 1 noti,\
     "< ./histogram_from_file.py reward_data/assassin -b 200" u 1:2 ls 2 ti "Assassin"

# set ytics nomirror tc lt 1
# set y2tics auto nomirror tc lt 3
# set ylabel "Prob (single)"
# set y2label "Prob (group)"
# set xtics nomirror tc lt 1
# set x2tics auto nomirror tc lt 3
# set xlabel "reward (single)"
# set x2label "reward (group)"
# plot "hist_taxi_single"axes x1y1 lt 1 ti "Taxi single",\
#      "hist_taxi_group" axes x2y2 lt 3 ti "Taxi group"
