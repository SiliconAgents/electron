#!/bin/bash
# nangate_photon_server: photon_server's what-if against batch Photon on one
# graph -- the same STA, the same sizing choices, a repeat estimate that undoes.
# Run in the container from TESTS/: server_parity.sh <pyspark> <store> <cells>
set -u
PY=$1/scala; STORE=$2; CELLS=$3
W=$PWD/workarea; S=$W/sta/server; mkdir -p $S; rm -f $S/*
SG=$W/vedic_16x16.phys.sgraph; COR=slow; PER=2.0; R=2000; C=0.2
JAR=$PY/build/photon.jar; SPARK="spark-shell --master local[4] --driver-memory 4g --conf spark.ui.showConsoleProgress=false --jars $JAR"
# --- batch: photon() on the graph, then sizeBound with place_opt's footprint
cat $PY/photon.sca $PY/wireplan.sca $PY/size.sca $PY/repeat.sca > $S/batch.sca
cat >> $S/batch.sca <<SCA
photon("$SG", "$STORE", "$COR", "$S/batch.seg.tsv", period = $PER, wireResPerUm = $R, wireCapPerUm = $C)
val (edgesB, placementB) = readSgraphPlaced("$SG", true, insts = true)
val phB = placementB.phys.get
val fpB = new Footprint(phB)
fpB.build(placementB.insts.iterator.filter { case (_, q) => q.ref != "PIN" && (q.status == "PLACED" || q.status == "FIXED") }
            .map { case (nm, q) => (nm, q.ref, q.x, q.y) }, ref => phB.cells.get(ref).map(c => (c._1, c._2)).getOrElse((0, phB.rowH)))
val infoB = readCellTable("$CELLS")
val usedB = { val hs = new scala.collection.mutable.HashSet[String](); edgesB.foreach { e => hs += e.drvRef; hs += e.sinkRef }; hs }
sizeBound("$SG", "$STORE", "$COR", "$S/batch", $PER, repeaterCells(infoB, usedB, Seq("any"), Some(phB)), "$CELLS", Seq("any"), 2,
          $R, $C, 1000, "", fits = (i, c) => fpB.fits(i, c), idealRepeat = false)
System.exit(0)
SCA
$SPARK -i $S/batch.sca < /dev/null > $S/batch.log 2>&1 || { echo "server_parity: batch failed, see $S/batch.log"; exit 1; }
# --- the server on the same graph
{ printf 'val psGraph="%s"\nval psStore="%s"\nval psCorner="%s"\nval psPeriod=%s\nval psSpef=""\nval psWire="auto"\n' "$SG" "$STORE" $COR $PER
  printf 'val psWireRes=%s\nval psWireCap=%s\nval psWireIdeal=1000\nval psWireModel=""\nval psCellTable="%s"\nval psVts="any"\n' $R $C "$CELLS"
  printf 'val psSdc=""\nval psPort=0\nval psEpfile="%s"\n' "$S/server.ep"
  cat $PY/photon.sca $PY/wireplan.sca $PY/size.sca $PY/repeat.sca $PY/photon_server.sca; } > $S/server.sca
$SPARK -i $S/server.sca < /dev/null > $S/server.log 2>&1 &
for i in $(seq 1 120); do [ -s $S/server.ep ] && break; sleep 2; done
[ -s $S/server.ep ] || { echo "server_parity: the server did not come up, see $S/server.log"; exit 1; }
# a net place_opt repeated (nangate_photon_repeat's ECO): long enough to be worth it
NET=$(awk -F'\t' '$1=="CONN" && $2 !~ /^photon_rep/ {print $2; exit}' $W/sta/vedic_16x16.prep.eco.tsv 2>/dev/null)
python3 $PY/pq.py $S/server.ep "wns; whatif_repeat ${NET:-none}; wns; size all 2; wns; eco $S/server.eco; changes" > $S/queries.txt 2>&1
python3 $PY/pq.py $S/server.ep "shutdown" > /dev/null 2>&1; wait
cat $S/queries.txt | grep -vE "^\s+[0-9]+\. " | head -40
# --- compare
bw=$(tr '\r' '\n' < $S/batch.log | grep -oE "photon: period [0-9.]+ +WNS -?[0-9.]+ +TNS -?[0-9.]+" | head -1 | awk '{print $5, $7}')
sw=$(grep -m1 -oE "^WNS -?[0-9.]+ +TNS -?[0-9.]+" $S/queries.txt | awk '{print $2, $4}')
echo "STA: batch WNS/TNS $bw, server $sw"
python3 - "$bw" "$sw" <<'PY' || exit 1
import sys
b = list(map(float, sys.argv[1].split())); s = list(map(float, sys.argv[2].split()))
ok = abs(b[0]-s[0]) < 1e-3 and abs(b[1]-s[1]) < 0.05 * max(1, abs(b[1]))
print("server_parity: STA", "matches" if ok else "DIFFERS"); sys.exit(0 if ok else 1)
PY
w1=$(grep -oE "^WNS -?[0-9.]+ +TNS -?[0-9.]+" $S/queries.txt | sed -n 2p); w0=$(grep -oE "^WNS -?[0-9.]+ +TNS -?[0-9.]+" $S/queries.txt | sed -n 1p)
[ "$w0" = "$w1" ] && echo "server_parity: whatif_repeat undone cleanly ($w0)" || { echo "server_parity: timing after an undone whatif_repeat is $w1, was $w0"; exit 1; }
diff <(awk -F'\t' 'NR>1 {print $1"\t"$2"\t"$3}' $S/batch.resize.tsv | sort) <(awk -F'\t' '$1=="RESIZE" {print $2"\t"$3"\t"$4}' $S/server.eco | sort) > $S/resize.diff \
  && echo "server_parity: sizing: server and batch chose the same $(grep -c '^RESIZE' $S/server.eco) resize(s)" \
  || { echo "server_parity: sizing differs, $(wc -l < $S/resize.diff) line(s), see $S/resize.diff"; exit 1; }
grep "best:" $S/batch.size_rounds.txt; grep -E "^\s+now:" $S/queries.txt
