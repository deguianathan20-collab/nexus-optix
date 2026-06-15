# Strip Insights Blog + White Papers links from every footer "Resources"
# column across all HTML pages. Also normalize the mobile-nav CTA path
# from "/contact" to "nexus-contact.html" for consistency.
# Idempotent.

$ErrorActionPreference = 'Stop'
$root = Join-Path $PSScriptRoot '..' | Resolve-Path
$pages = Join-Path $root 'Nexus static'

$files = Get-ChildItem -Path $pages -Filter *.html -File

$patterns = @(
    # Insights Blog <li>
    @{
        Name = 'Footer Insights Blog link'
        Regex = '(?ms)\s*<li><a href="nexus-insights-blog(?:\.html)?">Insights Blog</a></li>'
    },
    # White Papers <li>
    @{
        Name = 'Footer White Papers link'
        Regex = '(?ms)\s*<li><a href="nexus-insights-whitepaper(?:\.html)?">White Papers</a></li>'
    },
    # Mobile-nav CTA pointing to /contact (relative-root) → normalize to filename
    @{
        Name = 'Mobile nav /contact CTA'
        Regex = '<a href="/contact" class="mnv3-cta">'
        Replacement = '<a href="nexus-contact.html" class="mnv3-cta">'
    }
)

$totals = @{}
foreach ($p in $patterns) { $totals[$p.Name] = 0 }

foreach ($file in $files) {
    $original = [System.IO.File]::ReadAllText($file.FullName)
    $content  = $original

    foreach ($p in $patterns) {
        $matches = [regex]::Matches($content, $p.Regex)
        if ($matches.Count -gt 0) {
            if ($p.ContainsKey('Replacement')) {
                $content = [regex]::Replace($content, $p.Regex, $p.Replacement)
            } else {
                $content = [regex]::Replace($content, $p.Regex, '')
            }
            $totals[$p.Name] += $matches.Count
        }
    }

    if ($content -ne $original) {
        [System.IO.File]::WriteAllText($file.FullName, $content, [System.Text.UTF8Encoding]::new($false))
        Write-Host "  modified: $($file.Name)"
    }
}

Write-Host "`nSummary:"
foreach ($k in $totals.Keys) {
    Write-Host ("  {0,-32} {1}" -f $k, $totals[$k])
}
