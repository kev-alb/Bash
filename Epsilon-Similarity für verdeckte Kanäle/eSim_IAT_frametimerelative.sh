#!/bin/bash
source "`dirname $0`/nefias_lib.sh"
NEFIAS_INIT_PER_FLOW $1 $2 "ip"

for flow in $FLOWS; do
	# Betrachte immer die ersten 2001 IP-Pakete (entspricht 2000
	# Zeitabstaenden bzw. Bits) eines Flows und berechne den
	# Epsilon-Similarity-Wert auf Basis von frame.time_relative.
	cat ${TMPPKTSFILE} | grep $flow | head -n 2001 | \
	# Nutze gawk anstatt awk wegen Built-in-Funktionen asort() und
	# length().
	gawk -F\, ${FLOWFIELDS} \
	'BEGIN {counter=0
		epsilon_1=0.005; epsilon_1_counter=0
		epsilon_2=0.008; epsilon_2_counter=0
		epsilon_3=0.01; epsilon_3_counter=0
		epsilon_4=0.02; epsilon_4_counter=0
		epsilon_5=0.03; epsilon_5_counter=0
		epsilon_6=0.1; epsilon_6_counter=0
		# epsilon_7 bedeutet hier lambda_i >= 0.1. Siehe
		# Cabuk et al. 2004 (und 2009)
		epsilon_7=0.1; epsilon_7_counter=0
	}
	{
		counter++
		
		# Ab dem 2. IP-Paket (counter >= 2) den Zeitabstand
		# zum vorherigen berechnen und in einem Array speichern.
		if (counter >= 2) {
			arr_T[counter] = $frame_time_relative - previous_time
		}
				
		previous_time = $frame_time_relative
	}
	END {
		# Sichergehen, dass der Flow auch genügend Pakete
		# enthält. (Anzahl definiert durch head -n,
		# mindestens aber 3, sonst Fehler wegen Teilen durch 0)
		if (counter == 2001 && counter >= 3) {

			# Das Array mit den Zeitabstaenden aufsteigend
			# sortieren: Das Array arr_T enthält Werte mit Indizes
			# 2 bis counter. asort() sortiert und arr_T beginnt
			# anschließend bei Index 1.
			asort(arr_T)
			
			# Die paarweisen relativen Differenzen lambda aus
			# arr_T berechnen und in Array arr_lambda speichern.
			for (i = 1; i < length(arr_T); i++) {
				# Fehlerbehandlung für Teilen durch 0:
				# Falls Zeitabstand 0 ist, wird lambda 0 gesetzt.
				if (arr_T[i] != 0)
						arr_lambda[i] = (arr_T[i+1]-arr_T[i])/arr_T[i]
					else
						arr_lambda[i] = 0
			}
			
			# Anzahl der lambda-Werte zählen, die kleiner als die
			# jeweiligen Epsilon-Werte sind (bzw. größer gleich).
			for (i = 1; i <= length(arr_lambda); i++) {
				if (arr_lambda[i] < epsilon_1) epsilon_1_counter++
				if (arr_lambda[i] < epsilon_2) epsilon_2_counter++
				if (arr_lambda[i] < epsilon_3) epsilon_3_counter++
				if (arr_lambda[i] < epsilon_4) epsilon_4_counter++
				if (arr_lambda[i] < epsilon_5) epsilon_5_counter++
				if (arr_lambda[i] < epsilon_6) epsilon_6_counter++
				if (arr_lambda[i] >= epsilon_7) epsilon_7_counter++
			}
			
			# Die Epsilon-Similarity-Werte berechnen.
			eSim_1 = epsilon_1_counter / length(arr_lambda)
			eSim_2 = epsilon_2_counter / length(arr_lambda)
			eSim_3 = epsilon_3_counter / length(arr_lambda)
			eSim_4 = epsilon_4_counter / length(arr_lambda)
			eSim_5 = epsilon_5_counter / length(arr_lambda)
			eSim_6 = epsilon_6_counter / length(arr_lambda)
			eSim_7 = epsilon_7_counter / length(arr_lambda)
			
			# Epsilon-Similarity-Werte zu einem String konkatenieren.
			eSim_Werte = "eSim(" epsilon_1 ")=" sprintf("%.2f", 100*eSim_1) "%, "\
				"eSim(" epsilon_2 ")=" sprintf("%.2f", 100*eSim_2) "%, "\
				"eSim(" epsilon_3 ")=" sprintf("%.2f", 100*eSim_3) "%, "\
				"eSim(" epsilon_4 ")=" sprintf("%.2f", 100*eSim_4) "%, "\
				"eSim(" epsilon_5 ")=" sprintf("%.2f", 100*eSim_5) "%, "\
				"eSim(" epsilon_6 ")=" sprintf("%.2f", 100*eSim_6) "%, "\
				"eSim(>=" epsilon_7 ")=" sprintf("%.2f", 100*eSim_7) "%"		
		
			# Den String mit allen Epsilon-Similarity-Werten ausgeben.
			print eSim_Werte
		}
		
	# Ausgabe in die temporäre Arbeitsdatei schreiben.
	}' > ${TMPWORKFILE}
	
	# Temporäre Ergebnisdatei ${TMPRESULTSFILE} befüllen.
	if [ `/bin/ls -l ${TMPWORKFILE} | gawk '{print $5}'` = "0" ]; then
		# ${TMPWORKFILE} ist leer (0B), falls nicht genügend
		# IP-Pakete zur Berechnung der
		# Epsilon-Similarity-Werte vorhanden waren.
		# Dann NeFiAS über Ende informieren.
		touch ${TMPRESULTSFILE}
	else
		# ${TMPWORKFILE} enthält genau eine Zeile mit Epsilon-Similarity-Werten.
		# Diese Zeile in folgender Variable speichern.
		eSim=`gawk '{print}' ${TMPWORKFILE}`
		# Das Ergebnis an die temporäre Ergebnisdatei ${TMPRESULTSFILE} anhängen.
		echo "${flow}, ${eSim}" >> ${TMPRESULTSFILE}
	fi

	# Temporäre Arbeitsdatei löschen, da sie nicht mehr benötigt wird.
	rm -f ${TMPWORKFILE}
	
done

NEFIAS_FINISH
