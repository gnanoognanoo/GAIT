$ErrorActionPreference = 'Stop'
Push-Location -LiteralPath $PSScriptRoot
try {
  flutter pub get
  if ($LASTEXITCODE -ne 0) { throw 'Dependency resolution failed.' }
} finally {
  Pop-Location
}

