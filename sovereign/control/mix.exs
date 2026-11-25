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

defmodule SovereignBeamMojo.MixProject do
  use Mix.Project

  def project do
    [
      app: :sovereign_beam_mojo,
      version: "0.1.0",
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      deps: [],
      # The release runs where OTP is installed system-wide
      # (vm/bootstrap.sh installs OTP 29 + Elixir in the guest),
      # so it does not bundle ERTS. Bundling also fails on
      # hosts where Erlang's :file.copy hits :eperm copying
      # beam.smp onto overlayfs (verified 2026-11-24).
      releases: [
        sovereign_beam_mojo: [
          include_erts: false,
          include_executables_for: [:unix]
        ]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {SovereignBeamMojo.Application, []}
    ]
  end
end
