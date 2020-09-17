#!/bin/bash
source "`dirname $0`/nefias_lib.sh"
NEFIAS_INIT_PER_FLOW $1 $2 "ip"

for flow in $FLOWS; do
	# Betrachte immer die ersten 1000 IP-Pakete (entsprechen 1000
	# Bits) eines Flows und berechne den Epsilon-Similarity-Wert
	# auf Basis von frame.len.
	cat ${TMPPKTSFILE} | grep $flow | head -n 1000 | \
	# Nutze gawk anstatt awk wegen Built-in-Funktionen asort() und
	# length().
	gawk -F\, ${FLOWFIELDS} \
	'BEGIN {counter=0
		# Werte nach Wendzel et al. 2019
		epsilon_1=0.1; epsilon_1_counter=0
		# epsilon_2 bedeutet hier lambda_i >= 0.1.
		epsilon_2=0.1; epsilon_2_counter=0
		# Werte ohne Literaturbezug
		epsilon_3=0.001; epsilon_3_counter=0
		epsilon_4=10; epsilon_4_counter=0
	}
	{
		counter++
		
		# Die Größe jedes IP-Pakets in einem Array speichern.
		arr_S[counter] = $frame_len
	}
	END {
		# Sichergehen, dass der Flow auch genügend Pakete
		# enthält. (Anzahl definiert durch head -n,
		# mindestens aber 2, sonst Fehler wegen Teilen durch 0)
		if (counter == 1000 && counter >= 2) {
		
			# Das Array mit den Paketgrößen aufsteigend
			# sortieren: Das Array arr_S enthält Werte mit Indizes
			# 1 bis counter. asort() sortiert und arr_S beginnt
			# anschließend bei Index 1.
			asort(arr_S)
			
			# Die paarweisen relativen Differenzen lambda aus
			# arr_S berechnen und in Array arr_lambda speichern.
			for (i = 1; i < length(arr_S); i++) {
				# Fehlerbehandlung für Teilen durch 0:
				# Falls Paketgröße 0 ist, wird lambda 0 gesetzt.
				if (arr_S[i] != 0)
						arr_lambda[i] = (arr_S[i+1]-arr_S[i])/arr_S[i]
					else
						arr_lambda[i] = 0	
			}
			
			# Anzahl der lambda-Werte zählen, die kleiner als die
			# jeweiligen Epsilon-Werte sind (bzw. größer gleich).
			for (i = 1; i <= length(arr_lambda); i++) {
				if (arr_lambda[i] < epsilon_1) epsilon_1_counter++
				if (arr_lambda[i] >= epsilon_2) epsilon_2_counter++
				if (arr_lambda[i] < epsilon_3) epsilon_3_counter++
				if (arr_lambda[i] < epsilon_4) epsilon_4_counter++
			}
			
			# Die Epsilon-Similarity-Werte berechnen.
			eSim_1 = epsilon_1_counter / length(arr_lambda)
			eSim_2 = epsilon_2_counter / length(arr_lambda)
			eSim_3 = epsilon_3_counter / length(arr_lambda)
			eSim_4 = epsilon_4_counter / length(arr_lambda)
			
			# Epsilon-Similarity-Werte zu einem String konkatenieren.
			eSim_Werte = "eSim(" epsilon_1 ")=" sprintf("%.2f", 100*eSim_1) "%, "\
				"eSim(>=" epsilon_2 ")=" sprintf("%.2f", 100*eSim_2) "%, "\
				"eSim(" epsilon_3 ")=" sprintf("%.2f", 100*eSim_3) "%, "\
				"eSim(" epsilon_4 ")=" sprintf("%.2f", 100*eSim_4) "%"

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
