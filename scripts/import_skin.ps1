param(
    [Parameter(Mandatory = $true)][string]$InputPath,
    [Parameter(Mandatory = $true)]
    [ValidateSet('global-chest', 'global-craft-chest', 'global-provider-chest')]
    [string]$Skin
)

# Mechanical export only: preserve the generated transparency and composition.
Add-Type -AssemblyName System.Drawing
$modRoot = Split-Path -Parent $PSScriptRoot
$source = [System.Drawing.Image]::FromFile((Resolve-Path -LiteralPath $InputPath).Path)
try {
    foreach ($export in @(@{Folder='entity'; Size=64}, @{Folder='icons'; Size=32})) {
        $folder = Join-Path $modRoot ('graphics/' + $export.Folder)
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
        $bitmap = [System.Drawing.Bitmap]::new($export.Size, $export.Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $canvas = [System.Drawing.Graphics]::FromImage($bitmap)
        try {
            $canvas.Clear([System.Drawing.Color]::Transparent)
            $canvas.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
            $canvas.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $canvas.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $canvas.DrawImage($source, [System.Drawing.Rectangle]::new(0, 0, $export.Size, $export.Size))
            $bitmap.Save((Join-Path $folder ($Skin + '.png')), [System.Drawing.Imaging.ImageFormat]::Png)
        } finally {
            $canvas.Dispose()
            $bitmap.Dispose()
        }
    }
} finally {
    $source.Dispose()
}
