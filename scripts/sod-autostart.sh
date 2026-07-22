#!/bin/bash
# Wrapper launched by the GUI autostart .desktop entry (KDE Plasma).
# Runs sod.sh in a visible ghostty window and keeps it open at the end.

# Wait for the repository path to exist (filesystem might not be ready at boot)
for i in {1..30}; do
    if [ -d "/home/keverall/repos/ollama" ]; then
        break
    fi
    sleep 1
done

cd /home/keverall/repos/ollama || exit 1
/home/keverall/repos/ollama/scripts/sod.sh
status=$?
echo
echo "[sod.sh finished - exit $status]"
echo "You can now use this terminal, or close it."
exec bash
