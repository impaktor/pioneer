set term pngcairo dashed size 1000,1200
set output "expected.png"
set xrange [10:1e5]
set yrange [0:1]
set logscale x
# Gauss / normal distribution
#f(x,mu,sig2) = 1./sqrt(2*pi*sig2) *  exp(-(mu-x)**2/(2*sig2))
f(x,mu,sig2) = exp(-(mu-x)**2/(2*sig2))

# Poission distribution
p(k,lambda) = lambda**k * exp(-lambda) / gamma(k+1)

set samples 1000
posx=-.05
posy=1.1

set colorsequence podo

set style line 1 pt 1 lw 1.5*1 lt 1 dashtype 1
set style line 2 pt 1 lw 1.5*2 lt 1 dashtype 3
set style line 3 pt 2 lw 1.5*1 lt 2 dashtype 1
set style line 4 pt 2 lw 1.5*2 lt 2 dashtype 8
set style line 5 pt 3 lw 1.5*1 lt 3 dashtype 1
set style line 6 pt 3 lw 1.5*2 lt 3 dashtype 2
set style line 7 pt 4 lw 1.5*1 lt 7 dashtype 4

set multiplot layout 3,1

set key maxrows 2 outside above vertical
set title "Plaussible mission reward distribution"
set xlabel "Reward (credits)"
set ylabel "Probability (unnormalized)"
set label 1 "A" at graph posx, posy font "Arial-BoldMT,11"
plot  mean=1.0e2 f(x,mean,2*mean) ti "Package local",\
      mean=2.0e2 f(x,mean,6*mean) ti "Package nonlocal",\
      mean=4.0e2 f(x,mean,12*mean) ti "CargoRun local",\
      mean=1.0e3 f(x,mean,80*mean) ti "CargoRun nonlocal",\
      mean=3.0e3 f(x,mean,200*mean) ti "Taxi single",\
      mean=1.0e4 100 > x ? 0 : f(x,mean,1000*mean) ti "Taxi group",\
      mean=5.0e4 5000 > x ? 0 : f(x,mean,5000*mean) ti "Assassin"
unset key
unset title

unset logscale
set label 1 "B"
plot  mean=1.0e2 f(x,mean,2*mean) ti "Package local",\
      mean=2.0e2 f(x,mean,6*mean) ti "Package nonlocal",\
      mean=4.0e2 f(x,mean,12*mean) ti "CargoRun local",\
      mean=1.0e3 f(x,mean,80*mean) ti "CargoRun nonlocal",\
      mean=3.0e3 f(x,mean,200*mean) ti "Taxi single",\
      mean=1.0e4 100 > x ? 0 : f(x,mean,1000*mean) ti "Taxi group",\
      mean=5.0e4 5000 > x ? 0 : f(x,mean,5000*mean) ti "Assassin"

set st da line
set logscale x
set title "Actual mission reward distribution"
set xrange [10:*]
set label 1 "C"
plot \
     "< ./histogram_from_file.py reward_data/deliverpackage_local -b 50" u 1:($2/0.06) ti "Package local",\
     "< ./histogram_from_file.py reward_data/deliverpackage_nonlocal -b 100" u 1:($2/0.001) ti "Package nonlocal",\
     "< ./histogram_from_file.py reward_data/cargorun_local -b 100"    u 1:($2/0.025) ti "Cargorun local",\
     "< ./histogram_from_file.py reward_data/cargorun_nonlocal -b 500" u 1:($2/0.0005) ti "Cargorun nonlocal",\
     "< ./histogram_from_file.py reward_data/taxi_single -b 500"       u 1:($2/0.0007) ti "Taxi single",\
     "< ./histogram_from_file.py reward_data/taxi_group -b 500"        u 1:($2/.00007) ti "Taxi group",\
     "< ./histogram_from_file.py reward_data/assassin -b 200"          u 1:($2/.0001) ti "Assassin"

unset multiplot
