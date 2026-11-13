# Genera tests/_sources.lua con el contenido real de src/.
# El CLI de Luau no expone io, así que las pruebas reciben las fuentes
# empaquetadas como cadenas y las cargan con loadstring.
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$files = @(
    "core/00_config.lua",
    "core/10_utils.lua",
    "core/05_persistence.lua",
    "props/45_props.lua",
    "demo/92_recorder.lua",
    "demo/94_player.lua",
    "demo/96_file.lua",
    "demo/98_takes.lua"
)

$builder = New-Object System.Text.StringBuilder
[void]$builder.AppendLine("return {")
foreach ($relative in $files) {
    $path = Join-Path $root ("src/" + $relative)
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Falta $path"
    }
    $text = [System.IO.File]::ReadAllText($path)
    if ($text.Contains("[====[")) {
        throw "El archivo $relative contiene el delimitador [====["
    }
    [void]$builder.AppendLine(('["{0}"] = [====[' -f $relative))
    [void]$builder.AppendLine($text)
    [void]$builder.AppendLine("]====],")
}
[void]$builder.AppendLine("}")

$output = Join-Path $PSScriptRoot "_sources.lua"
$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($output, $builder.ToString(), $utf8)
Write-Host "Generado $output"
