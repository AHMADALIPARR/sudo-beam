# Input policy columns: caller target command verdict. Last match wins.
BEGIN { verdict = "deny"; invalid = 0 }
/^[[:space:]]*($|#)/ { next }
NF != 4 || $1 !~ /^[a-z][a-z0-9_-]*$/ || $2 !~ /^[a-z][a-z0-9_-]*$/ || $3 !~ /^[a-z][a-z0-9_-]*$/ || ($4 != "allow" && $4 != "deny") { invalid = 1; next }
$1 == caller && $2 == target && $3 == cmd { verdict = $4 }
END { if (invalid) { print "deny"; exit 2 }; print verdict }
