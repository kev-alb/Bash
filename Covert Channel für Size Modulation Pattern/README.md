Implementierung eines einfachen Covert Channels auf Basis des Size Modulation Patterns. (Es wird das Programm ncat benötigt.)
Siehe das Bash-Skript "Covert_Channel_UTF8_1000_1001_TheQuickBrown_ncat.sh" für die genaue Funktionsweise des Channels.

Der Covert Channel mit Size Modulation Pattern enthält Pakete der Größen 1000 und 1001 Byte.

Der Sender ist 192.168.0.46
Der Empänger ist 192.168.0.206

1. Schritt: In Terminal des Empfängers Kommando zum Aufzeichnen der Pakete, die vom Sender kommen.
sudo tshark -i wlp14s0 -a packets 3000 -w Size_Mod_Channel.pcap -f "tcp and src host 192.168.0.46"

2. Schritt: Im 2. Terminal des Empfängers mit ncat lauschen:
ncat -v -l 9999

3. Schritt: Im Terminal des Senders 
ncat -v 192.168.0.206 9999 -e Covert_Channel_UTF8_1000_1001_TheQuickBrown_ncat.sh

Channel bzw. Flow läuft und wird aufgezeichnet.
