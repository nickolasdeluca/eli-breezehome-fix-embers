<#
Rebuilds "Eli_Breezehome [FIX - Embers XD Firepit].esp" from the two plugins it patches.

  .\tools\build.ps1 -EliPlugin "<...>\Eli_Breezehome.esp" -EmbersPlugin "<...>\Embers XD.esp"

The patch contains no new records. It overrides, inside the Breezehome interior cell (000165A8):
  - 000CB48D, 000CB48E, 0010C063 : the vanilla firepit references, copied byte-for-byte from
    Eli_Breezehome.esp so its version wins again over "Lux - Embers XD patch.esp".
  - Embers XD.esp:0EE400         : the extra ember effect Embers XD adds at the old firepit,
    flagged Initially Disabled the same way EBO disables things (enable parent = player, opposite).
#>
param(
    [Parameter(Mandatory)][string]$EliPlugin,
    [Parameter(Mandatory)][string]$EmbersPlugin,
    [string]$OutFile = (Join-Path (Split-Path -Parent $PSScriptRoot) 'Eli_Breezehome [FIX - Embers XD Firepit].esp')
)
$ErrorActionPreference = 'Stop'
$L = [Text.Encoding]::GetEncoding(28591)
$BaseMasters = 'Skyrim.esm', 'Update.esm', 'Dawnguard.esm', 'HearthFires.esm', 'Dragonborn.esm'
$Masters = $BaseMasters + 'Eli_Breezehome.esp' + 'Embers XD.esp'
$CellId = 0x000165A8

function Read-Plugin([string]$path) {
    $b = [IO.File]::ReadAllBytes($path)
    $pos = 24; $end = 24 + [BitConverter]::ToUInt32($b, 4); $masters = @()
    while ($pos -lt $end) {
        $t = $L.GetString($b, $pos, 4); $len = [BitConverter]::ToUInt16($b, $pos + 4)
        if ($t -eq 'MAST') { $masters += $L.GetString($b, $pos + 6, $len - 1) }
        $pos += 6 + $len
    }
    $records = New-Object System.Collections.Generic.List[object]
    $stack = New-Object System.Collections.Generic.List[object]
    $pos = $end
    while ($pos -lt $b.Length - 23) {
        while ($stack.Count -gt 0 -and $pos -ge $stack[$stack.Count - 1].End) { $stack.RemoveAt($stack.Count - 1) }
        if ($L.GetString($b, $pos, 4) -eq 'GRUP') {
            $stack.Add([pscustomobject]@{ Pos = $pos; End = $pos + [BitConverter]::ToUInt32($b, $pos + 4) })
            $pos += 24
            continue
        }
        $size = [BitConverter]::ToUInt32($b, $pos + 4)
        $records.Add([pscustomobject]@{ Type = $L.GetString($b, $pos, 4); Pos = $pos; Size = $size; Fid = [BitConverter]::ToUInt32($b, $pos + 12); Chain = $stack.ToArray() })
        $pos += 24 + $size
    }
    [pscustomobject]@{ Bytes = $b; Masters = $masters; Records = $records }
}
function Get-Slice($plugin, [int]$pos, [int]$len) { $o = New-Object byte[] $len; [Array]::Copy($plugin.Bytes, $pos, $o, 0, $len); , $o }
function Find-Record($plugin, [string]$type, [uint32]$fid) {
    $r = $plugin.Records | Where-Object { $_.Type -eq $type -and $_.Fid -eq $fid } | Select-Object -First 1
    if (-not $r) { throw ('{0} {1:X8} not found' -f $type, $fid) }
    $r
}
function Set-UInt32([byte[]]$buffer, [int]$offset, [uint32]$value) { [Array]::Copy([BitConverter]::GetBytes($value), 0, $buffer, $offset, 4) }
function New-Subrecord([string]$tag, [byte[]]$data) { , [byte[]]($L.GetBytes($tag) + [BitConverter]::GetBytes([uint16]$data.Length) + $data) }

$eli = Read-Plugin $EliPlugin
$emb = Read-Plugin $EmbersPlugin
# Both plugins must have exactly the five base masters: that is what lets FormIDs carry over unchanged.
if (($eli.Masters -join '|') -ne ($BaseMasters -join '|')) { throw "Unexpected masters in Eli_Breezehome.esp: $($eli.Masters -join ', ')" }
if (($emb.Masters -join '|') -ne ($BaseMasters -join '|')) { throw "Unexpected masters in Embers XD.esp: $($emb.Masters -join ', ')" }

$cell = Find-Record $eli 'CELL' $CellId
$refs = @()
foreach ($fid in 0x000CB48D, 0x000CB48E, 0x0010C063) {
    $r = Find-Record $eli 'REFR' $fid
    $refs += , (Get-Slice $eli $r.Pos (24 + $r.Size))
}
$chain = (Find-Record $eli 'REFR' 0x000CB48D).Chain      # CELL top group > block > sub-block > cell children > temporary
if ($chain.Count -ne 5) { throw 'Unexpected group nesting around the Breezehome cell' }

$ember = Find-Record $emb 'REFR' 0x050EE400
$position = New-Object byte[] 24
[Array]::Copy([BitConverter]::GetBytes([single]-30000), 0, $position, 8, 4)
$body = [byte[]]((New-Subrecord 'NAME' ([byte[]](0xA9, 0x3D, 0x03, 0x00))) +          # unchanged base object, Skyrim.esm:033DA9
                 (New-Subrecord 'XESP' ([byte[]](0x14, 0, 0, 0, 0x01, 0, 0, 0))) +    # enable parent: player, opposite
                 (New-Subrecord 'DATA' $position))                                    # z = -30000
$header = Get-Slice $emb $ember.Pos 24
Set-UInt32 $header 4 $body.Length
Set-UInt32 $header 8 0x00000800       # Initially Disabled
Set-UInt32 $header 12 0x060EE400      # Embers XD.esp is master index 6 in this plugin
$refs += , [byte[]]($header + $body)

function New-GroupFrom($sourceGroup, [byte[]]$content) {
    $h = Get-Slice $eli $sourceGroup.Pos 24
    Set-UInt32 $h 4 (24 + $content.Length)
    , [byte[]]($h + $content)
}
$blob = [byte[]]($refs | ForEach-Object { $_ })
$g = New-GroupFrom $chain[4] $blob
$g = New-GroupFrom $chain[3] $g
$g = New-GroupFrom $chain[2] ([byte[]]((Get-Slice $eli $cell.Pos (24 + $cell.Size)) + $g))
$g = New-GroupFrom $chain[1] $g
$g = New-GroupFrom $chain[0] $g

$hedr = New-Object byte[] 12
[Array]::Copy([BitConverter]::GetBytes([single]1.7), 0, $hedr, 0, 4)
Set-UInt32 $hedr 4 10                 # 5 records + 5 groups
Set-UInt32 $hedr 8 0x800
$tes4 = [byte[]]((New-Subrecord 'HEDR' $hedr) +
                 (New-Subrecord 'CNAM' ([byte[]]($L.GetBytes('nickolasdeluca') + [byte]0))) +
                 (New-Subrecord 'SNAM' ([byte[]]($L.GetBytes('Removes the old firepit fire/ember effects that Embers XD and the Lux - Embers XD patch leave in the middle of Elianora''s Breezehome.') + [byte]0))))
foreach ($name in $Masters) {
    $tes4 += (New-Subrecord 'MAST' ([byte[]]($L.GetBytes($name) + [byte]0))) + (New-Subrecord 'DATA' (New-Object byte[] 8))
}
$top = New-Object byte[] 24
[Array]::Copy($L.GetBytes('TES4'), 0, $top, 0, 4)
Set-UInt32 $top 4 $tes4.Length
Set-UInt32 $top 8 0x200               # ESL flag
[Array]::Copy($eli.Bytes, 16, $top, 16, 8)
[IO.File]::WriteAllBytes($OutFile, [byte[]]($top + $tes4 + $g))
"Wrote $OutFile ($([IO.FileInfo]::new($OutFile).Length) bytes)"
