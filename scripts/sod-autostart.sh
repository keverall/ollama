#!/bin/bash
# Wrapper launched by the GUI autostart .desktop entry (KDE Plasma).
# Runs sod.sh in a visible konsole window and keeps it open at the end.
cd /home/keverall/repos/ollama || exit 1
/home/keverall/repos/ollama/scripts/sod.sh
status=$?
echo
echo "[sod.sh finished - exit $status]  Press any key to close."
read -n1
