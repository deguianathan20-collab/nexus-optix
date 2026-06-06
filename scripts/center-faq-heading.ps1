# Center the FAQ section heading (section-label + section-title) across all
# pages that have a .faq-section. Idempotent — re-running is a no-op once applied.

$ErrorActionPreference = 'Stop'
$root = Join-Path $PSScriptRoot '..' | Resolve-Path
$pages = Join-Path $root 'Nexus static'

$rule = @"

  /* Center FAQ heading */
  .faq-section > .section-label,
  .faq-section > .section-title { text-align: center; }
"@

# Marker so we know if we already added the rule
$marker = '/* Center FAQ heading */'

$files = Get-ChildItem -Path $pages -Filter *.html -File
$modified = 0
foreach ($file in $files) {
    $content = [System.IO.File]::ReadAllText($file.FullName)

    # only process files that actually have a .faq-section
    if ($content -notmatch '\.faq-section\b') { continue }
    if ($content.Contains($marker)) { continue }

    # Insert the rule just before the closing </style> of the FIRST style block
    # (Each page has its CSS in one inline <style> tag in <head>.)
    $newContent = [regex]::Replace($content, '(?s)</style>', ($rule + "`n</style>"), 1)

    if ($newContent -ne $content) {
        [System.IO.File]::WriteAllText($file.FullName, $newContent, [System.Text.UTF8Encoding]::new($false))
        Write-Host "  modified: $($file.Name)"
        $modified++
    }
}
Write-Host "`nTotal modified: $modified"
