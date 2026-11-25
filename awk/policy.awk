# Copyright (C) 2026 AHMADALIPARR
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, version 3 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
# SPDX-License-Identifier: AGPL-3.0-only

# Input policy columns: caller target command verdict. Last match wins.
BEGIN { verdict = "deny"; invalid = 0 }
/^[[:space:]]*($|#)/ { next }
NF != 4 || $1 !~ /^[a-z][a-z0-9_-]*$/ || $2 !~ /^[a-z][a-z0-9_-]*$/ || $3 !~ /^[a-z][a-z0-9_-]*$/ || ($4 != "allow" && $4 != "deny") { invalid = 1; next }
$1 == caller && $2 == target && $3 == cmd { verdict = $4 }
END { if (invalid) { print "deny"; exit 2 }; print verdict }
