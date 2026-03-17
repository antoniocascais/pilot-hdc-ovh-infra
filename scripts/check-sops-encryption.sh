#!/bin/bash
retval=0
for file in "$@"; do
  if ! grep -qE '"sops"|^sops[_:]' "$file"; then
    echo "ERROR: $file is not SOPS-encrypted. Run: sops -e -i $file"
    retval=1
  fi
done
exit $retval
