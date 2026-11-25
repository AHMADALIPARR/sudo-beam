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

import Config

# No secrets here. The Sudo config path is created empty (0600) by
# vm/bootstrap.sh and filled in by hand in the guest. Its `mode`
# field (mock | real | local_only) gates Sudo.ApiClient — see
# docs/API_CLIENT_DECISION.md. Example (placeholders only):
# control/config/sudoplatformconfig.example.json
config :sovereign_beam_mojo,
  sudo_config_path: Path.expand("~/.config/sovereign-beam-mojo/sudoplatformconfig.json")

# In dev/test the workers live in control/priv. In prod (a release)
# kernel_bin_dir is deliberately unset, so KernelPort falls back
# to :code.priv_dir(:sovereign_beam_mojo) — the release's own
# lib/sovereign_beam_mojo-*/priv — and the release is
# self-contained instead of depending on the source tree.
if config_env() != :prod do
  config :sovereign_beam_mojo, kernel_bin_dir: Path.expand("../priv", __DIR__)
end
