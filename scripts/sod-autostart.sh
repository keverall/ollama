#!/bin/bash
# Wrapper launched by the GUI autostart .desktop entry (KDE Plasma).
# Runs sod.sh in a visible konsole window and keeps it open at the end.
cd /home/keverall/repos/ollama || exit 1
/home/keverall/repos/ollama/scripts/sod.sh
status=$?
echo
echo "[sod.sh finished - exit $status]"
echo "You can now use this terminal, or close it."
exec bash
