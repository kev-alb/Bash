#!/bin/bash
source "`dirname $0`/nefias_lib.sh"
NEFIAS_INIT_PER_FLOW $1 $2 "tcp"

for flow in $FLOWS; do
	# Betrachte immer die ersten 1000 TCP-Segmente eines Flows und
	# berechne den Epsilon-Similarity-Wert auf Basis von tcp.seq.
	cat ${TMPPKTSFILE} | grep $flow | head -n 1000 | \
	# Nutze gawk anstatt awk wegen Built-in-Funktionen asort() und
	# length().
	gawk -F\, ${FLOWFIELDS} \
	'BEGIN {counter=0
		# Werte nach Zillien und Wendzel 2018
		epsilon_1=0.01; epsilon_1_counter=0
		epsilon_2=0.2; epsilon_2_counter=0
		epsilon_3=2.5; epsilon_3_counter=0
		# epsilon_4 bedeutet hier lambda_i >= 2.5.
		epsilon_4=2.5; epsilon_4_counter=0
	}
	{
		counter++
		
		# Die TCP-Sequenznummern in einem Array speichern.
		arr_Seq[counter] = $tcp_seq
	}
	END {
		# Sichergehen, dass der Flow auch genügend Pakete
		# enthält. (Anzahl definiert durch head -n)
		if (counter == 1000) {
		
			# Aus dem Array der Sequenznummern nur die Sequenznummern
			# von erneuten Übertragungen extrahieren.
			counter_Retrans = 0
			for (i = 1; i <= length(arr_Seq); i++) {
				# "Boolesche" Variable wird eingesetzt, die
				# true (1) ist, falls eine erneute Übertragung
				# gefunden wurde, sonst false (0). Dies berücksichtigt
				# den Fall von mehrfach erneut übertragenen TCP-Segmenten.
				bool_retrans_found = 0
				for (j = i+1; bool_retrans_found == 0 && j <= length(arr_Seq); j++) {
					if (arr_Seq[i] == arr_Seq[j]) bool_retrans_found = 1
				}
				
				# Sequenznummer der erneuten Übertragung extrahieren.
				if (bool_retrans_found == 1) {
					counter_Retrans++
					arr_Retrans[counter_Retrans] = arr_Seq[i]	
				}
			}
			
			# Es müssen mindestens 3 erneute Übertragungen vorhanden sein,
			# um die eSim zu berechnen. (Ansonsten Fehler wegen Teilen durch 0)
			if (counter_Retrans <= 2) {
				eSim_Werte = "no or not enough (<=2) retransmissions existent"
			}
			else {
				# Je erneuter Übertragung (ausgenommen der letzten) ihren
				# Abstand zur nächsten erneuten Übertragung berechnen,
				# also die Differenz Delta ihrer Sequenznummern und in neuem
				# Array speichern.
				for (i = 1; i < length(arr_Retrans); i++) {
					arr_Delta[i] = arr_Retrans[i+1] - arr_Retrans[i]
				}
				
				# Das Array mit den Differenzen Delta aufsteigend
				# sortieren: asort(). arr_Delta beginnt anschließend
				# bei Index 1.
				asort(arr_Delta)
				
				# Die paarweisen relativen Differenzen lambda aus
				# arr_Delta berechnen und in Array arr_lambda speichern.
				for (i = 1; i < length(arr_Delta); i++) {
					# Fehlerbehandlung für Teilen durch 0:
					# Falls Delta-Wert 0 ist, wird lambda 0 gesetzt.
					if (arr_Delta[i] != 0)
						arr_lambda[i] = (arr_Delta[i+1]-arr_Delta[i])/arr_Delta[i]
					else
						arr_lambda[i] = 0
				}
				
				# Anzahl der lambda-Werte zählen, die kleiner als die
				# jeweiligen Epsilon-Werte sind (bzw. größer gleich).
				for (i = 1; i <= length(arr_lambda); i++) {
					if (arr_lambda[i] < epsilon_1) epsilon_1_counter++
					if (arr_lambda[i] < epsilon_2) epsilon_2_counter++
					if (arr_lambda[i] < epsilon_3) epsilon_3_counter++
					if (arr_lambda[i] >= epsilon_4) epsilon_4_counter++
				}
				
				# Die Epsilon-Similarity-Werte berechnen.
				eSim_1 = epsilon_1_counter / length(arr_lambda)
				eSim_2 = epsilon_2_counter / length(arr_lambda)
				eSim_3 = epsilon_3_counter / length(arr_lambda)
				eSim_4 = epsilon_4_counter / length(arr_lambda)
				
				# Epsilon-Similarity-Werte zu einem String konkatenieren.
				eSim_Werte = "eSim(" epsilon_1 ")=" sprintf("%.2f", 100*eSim_1) "%, "\
					"eSim(" epsilon_2 ")=" sprintf("%.2f", 100*eSim_2) "%, "\
					"eSim(" epsilon_3 ")=" sprintf("%.2f", 100*eSim_3) "%, "\
					"eSim(>=" epsilon_4 ")=" sprintf("%.2f", 100*eSim_4) "%"
			}
		
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
		# ${TMPWORKFILE} enthält genau eine Zeile (ggf.) mit
		# Epsilon-Similarity-Werten. Diese Zeile in folgender Variable speichern.
		eSim=`gawk '{print}' ${TMPWORKFILE}`
		# Das Ergebnis an die temporäre Ergebnisdatei ${TMPRESULTSFILE} anhängen.
		echo "${flow}, ${eSim}" >> ${TMPRESULTSFILE}
	fi
	
	# Temporäre Arbeitsdatei löschen, da sie nicht mehr benötigt wird.
	rm -f ${TMPWORKFILE}
	
done

NEFIAS_FINISH
