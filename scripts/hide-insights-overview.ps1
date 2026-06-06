# One-shot script: hides Insights nav (desktop + mobile + footer) and
# removes "Overview" from the Services dropdown across all HTML pages.
# Idempotent — safe to re-run; patterns won't match after first pass.

$ErrorActionPreference = 'Stop'
$root = Join-Path $PSScriptRoot '..' | Resolve-Path
$pages = Join-Path $root 'Nexus static'

$files = Get-ChildItem -Path $pages -Filter *.html -File
Write-Host "Processing $($files.Count) HTML files in $pages"

# Patterns (regex, multiline). All use named groups for clarity, but we just
# delete the entire match. Single-line mode so . matches newlines via [\s\S].

$patterns = @(
    # 1. Desktop Insights nav-dropdown <li> (with or without active state, with
    #    or without indentation differences). Matches the whole <li class="nav-dropdown">
    #    ... </li> block that contains nexus-insights-blog.html
    @{
        Name = 'Desktop Insights dropdown'
        Regex = '(?ms)\s*<li class="nav-dropdown">\s*\r?\n\s*(?:<a href="nexus-insights-(?:blog|whitepaper)\.html"[^>]*>Insights</a>|<a [^>]*href="nexus-insights-(?:blog|whitepaper)\.html"[^>]*>Insights</a>)[\s\S]*?</ul>\s*\r?\n\s*</li>'
    },
    # 2. Mobile Insights submenu <li class="mnv3-item">...</li>
    @{
        Name = 'Mobile Insights submenu'
        Regex = '(?ms)\s*<li class="mnv3-item">\s*\r?\n\s*<button [^>]*data-sub="mnv3SubInsights"[^>]*>Insights[\s\S]*?</ul>\s*\r?\n\s*</li>'
    },
    # 3. Footer "Insights" link (plain <li>) — used in footers across most pages
    @{
        Name = 'Footer plain Insights link'
        Regex = '(?ms)\s*<li><a href="(?:/)?nexus-insights-blog(?:\.html)?">Insights</a></li>'
    },
    # 4. Footer Insights as nested nav-dropdown (services.html footer style)
    @{
        Name = 'Footer Insights dropdown'
        Regex = '(?ms)\s*<li class="nav-dropdown">\s*\r?\n\s*<a href="nexus-insights-blog\.html">Insights</a>\s*\r?\n\s*<ul class="dropdown-menu">\s*\r?\n\s*<li><a href="nexus-insights-whitepaper\.html">White Papers</a></li>\s*\r?\n\s*<li><a href="nexus-insights-blog\.html">Blog</a></li>\s*\r?\n\s*</ul>\s*\r?\n\s*</li>'
    },
    # 5. thank-you.html footer uses href="#"
    @{
        Name = 'Footer Insights placeholder (#)'
        Regex = '(?ms)\s*<li>\s*\r?\n\s*<a href="#">Insights</a>\s*\r?\n\s*<ul[^>]*>\s*\r?\n\s*<li><a href="nexus-insights-whitepaper\.html">White Papers</a></li>\s*\r?\n\s*<li><a href="nexus-insights-blog\.html">Blog</a></li>\s*\r?\n\s*</ul>\s*\r?\n\s*</li>'
    },
    # 6. Footer "Insights" inside a nested <li> with class="nav-dropdown" no active
    @{
        Name = 'Footer Insights dropdown (active variants)'
        Regex = '(?ms)\s*<li class="nav-dropdown">\s*\r?\n\s*<a [^>]*href="nexus-insights-(?:blog|whitepaper)\.html"[^>]*>Insights</a>\s*\r?\n\s*<ul class="dropdown-menu">[\s\S]*?</ul>\s*\r?\n\s*</li>'
    },
    # 7. Desktop "Overview" <li> in Services dropdown (with optional dropdown-active)
    @{
        Name = 'Desktop Overview Services'
        Regex = '(?ms)\s*<li><a href="nexus-services\.html"(?:\s+class="dropdown-active")?>Overview</a></li>\s*\r?\n(\s*<div class="dropdown-divider"></div>\s*\r?\n)?'
    },
    # 8. Mobile "Overview" <li> in Services submenu
    @{
        Name = 'Mobile Overview Services'
        Regex = '(?ms)\s*<li><a href="nexus-services\.html">Overview</a></li>'
    }
)

$totalReplacements = @{}
foreach ($p in $patterns) { $totalReplacements[$p.Name] = 0 }

foreach ($file in $files) {
    $original = Get-Content -Raw -LiteralPath $file.FullName
    $content = $original

    foreach ($p in $patterns) {
        $matches = [regex]::Matches($content, $p.Regex)
        if ($matches.Count -gt 0) {
            $content = [regex]::Replace($content, $p.Regex, "`n")
            $totalReplacements[$p.Name] += $matches.Count
        }
    }

    if ($content -ne $original) {
        # preserve original encoding (most files are UTF-8 no BOM)
        [System.IO.File]::WriteAllText($file.FullName, $content, [System.Text.UTF8Encoding]::new($false))
        Write-Host ("  modified: {0}" -f $file.Name)
    }
}

Write-Host "`nSummary:"
foreach ($k in $totalReplacements.Keys) {
    Write-Host ("  {0,-45} {1}" -f $k, $totalReplacements[$k])
}
