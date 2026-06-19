$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$staticDir = Join-Path $root 'Nexus static'
$globalCssPath = Join-Path $staticDir 'nexus-global.css'
$mobileCssPath = Join-Path $staticDir 'nexus-mobile-nav.css'

$commonVars = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
@(
  '--navy',
  '--navy-deep',
  '--blue-primary',
  '--blue-mid',
  '--blue-light',
  '--green-primary',
  '--green-mid',
  '--green-light',
  '--white',
  '--off-white',
  '--gray-100',
  '--gray-200',
  '--gray-400',
  '--gray-600',
  '--text-dark',
  '--text-body'
) | ForEach-Object { [void]$commonVars.Add($_) }

$globalCss = @'
:root {
  --navy: #152238;
  --navy-deep: #0e1a2e;
  --blue-primary: #275087;
  --blue-mid: #497BBE;
  --blue-light: #79ACF0;
  --green-primary: #4CBA70;
  --green-mid: #6BB884;
  --green-light: #B3E7C4;
  --white: #ffffff;
  --off-white: #f8f9fc;
  --gray-100: #f1f3f8;
  --gray-200: #e2e6ef;
  --gray-400: #8b95a8;
  --gray-600: #5a6577;
  --text-dark: #152238;
  --text-body: #4a5568;
}

* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

html {
  scroll-behavior: smooth;
  font-size: 16px;
}

body {
  font-family: 'Montserrat', sans-serif;
  color: var(--text-dark);
  background: var(--white);
  overflow-x: hidden;
  -webkit-font-smoothing: antialiased;
}

/* ===== NAVIGATION ===== */
.nav {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  z-index: 1000;
  padding: 0 60px;
  height: 80px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  transition: all 0.4s cubic-bezier(0.16, 1, 0.3, 1);
  background: transparent;
}

.nav.scrolled {
  background: rgba(21, 34, 56, 0.95);
  backdrop-filter: blur(20px);
  -webkit-backdrop-filter: blur(20px);
  box-shadow: 0 1px 40px rgba(0, 0, 0, 0.15);
  height: 72px;
}

.nav-logo {
  display: flex;
  align-items: center;
  text-decoration: none;
}

.nav-logo img {
  height: 38px;
  width: auto;
}

.nav-links {
  display: flex;
  align-items: center;
  gap: 40px;
  list-style: none;
}

.nav-links a {
  text-decoration: none;
  color: rgba(255, 255, 255, 0.8);
  font-size: 0.85rem;
  font-weight: 600;
  letter-spacing: 0.5px;
  text-transform: uppercase;
  transition: color 0.3s;
}

.nav-links a:hover,
.nav-links a.active {
  color: var(--white);
}

.nav-dropdown {
  position: relative;
}

.nav-dropdown > a {
  display: flex;
  align-items: center;
  gap: 4px;
}

.nav-dropdown > a::after {
  content: '';
  width: 0;
  height: 0;
  border-left: 4px solid transparent;
  border-right: 4px solid transparent;
  border-top: 4px solid currentColor;
  transition: transform 0.3s;
}

.nav-dropdown:hover > a::after {
  transform: rotate(180deg);
}

.dropdown-menu {
  position: absolute;
  top: calc(100% + 12px);
  left: 50%;
  transform: translateX(-50%) translateY(8px);
  background: rgba(21, 34, 56, 0.97);
  backdrop-filter: blur(20px);
  border: 1px solid rgba(255, 255, 255, 0.1);
  border-radius: 12px;
  padding: 12px 0;
  min-width: 220px;
  opacity: 0;
  visibility: hidden;
  transition: all 0.3s cubic-bezier(0.16, 1, 0.3, 1);
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
  list-style: none;
}

.nav-dropdown:hover .dropdown-menu {
  opacity: 1;
  visibility: visible;
  transform: translateX(-50%) translateY(0);
}

.dropdown-menu li a {
  display: block;
  padding: 10px 24px;
  font-size: 0.8rem;
  font-weight: 600;
  letter-spacing: 0.3px;
  text-transform: none;
  color: rgba(255, 255, 255, 0.7);
  text-decoration: none;
  transition: all 0.2s;
}

.dropdown-menu li a:hover {
  color: var(--white);
  background: rgba(255, 255, 255, 0.05);
}

.dropdown-menu li a.dropdown-active {
  color: var(--green-light);
}

.dropdown-divider {
  height: 1px;
  background: rgba(255, 255, 255, 0.08);
  margin: 8px 24px;
}

.nav-cta {
  padding: 12px 28px;
  background: linear-gradient(135deg, var(--green-primary) 0%, var(--green-mid) 50%, var(--blue-mid) 100%) !important;
  border: none;
  border-radius: 6px;
  color: var(--white) !important;
  font-weight: 700 !important;
  transition: all 0.3s !important;
  box-shadow: 0 2px 12px rgba(76, 186, 112, 0.3);
  text-decoration: none;
}

.nav-cta:hover {
  color: var(--white) !important;
  transform: translateY(-1px);
  box-shadow: 0 4px 20px rgba(76, 186, 112, 0.4);
  filter: brightness(1.08);
}

/* Center FAQ heading */
.faq-section > .section-label,
.faq-section > .section-title {
  text-align: center;
}
'@

function Remove-CssRule {
  param(
    [string]$Css,
    [string]$SelectorPattern
  )
  return [regex]::Replace($Css, "(?s)\s*$SelectorPattern\s*\{[^{}]*\}", "`n")
}

function Remove-DuplicateFaqRule {
  param([string]$Css)
  $pattern = '(?s)\s*/\*\s*Center FAQ heading\s*\*/\s*\.faq-section\s*>\s*\.section-label\s*,\s*\.faq-section\s*>\s*\.section-title\s*\{\s*text-align:\s*center;\s*\}'
  return [regex]::Replace($Css, $pattern, "`n")
}

function Convert-FirstStyle {
  param([string]$Html)

  if ($Html.Contains('/nexus-global.css')) {
    return $Html
  }

  $styleMatch = [regex]::Match($Html, '(?s)<style>\s*(?<css>.*?)</style>')
  if (-not $styleMatch.Success) {
    return $Html
  }

  $css = $styleMatch.Groups['css'].Value
  if ($css -notmatch '\.nav\s*\{') {
    return $Html
  }

  $extras = New-Object System.Collections.Generic.List[string]
  $rootMatch = [regex]::Match($css, '(?s)^\s*:root\s*\{(?<root>.*?)\}')
  if ($rootMatch.Success) {
    foreach ($decl in [regex]::Matches($rootMatch.Groups['root'].Value, '(?m)\s*(--[a-zA-Z0-9-]+)\s*:\s*([^;]+);')) {
      $name = $decl.Groups[1].Value.Trim()
      if (-not $commonVars.Contains($name)) {
        $value = $decl.Groups[2].Value.Trim()
        $extras.Add("  ${name}: $value;")
      }
    }
    $css = $css.Remove($rootMatch.Index, $rootMatch.Length)
  }

  $css = [regex]::Replace($css, '(?s)\s*/\*\s*=*\s*NAVIGATION\s*=*\s*\*/', "`n")
  $css = [regex]::Replace($css, '(?s)\s*/\*\s*NAV\s*\*/', "`n")
  $css = [regex]::Replace($css, '(?s)\s*\*\s*\{\s*margin:\s*0;\s*padding:\s*0;\s*box-sizing:\s*border-box;\s*\}', "`n")
  $css = [regex]::Replace($css, '(?s)\s*html\s*\{\s*scroll-behavior:\s*smooth;\s*font-size:\s*16px;\s*\}', "`n")
  $css = [regex]::Replace($css, '(?s)\s*body\s*\{.*?font-family:\s*''Montserrat'',\s*sans-serif;.*?-webkit-font-smoothing:\s*antialiased;.*?\}', "`n")

  $selectors = @(
    '\.nav\.scrolled',
    '\.nav',
    '\.nav-logo',
    '\.nav-logo\s+img',
    '\.nav-links',
    '\.nav-links\s+a',
    '\.nav-links\s+a:hover\s*,\s*\.nav-links\s+a\.active',
    '\.nav-links\s+a:hover',
    '\.nav-dropdown',
    '\.nav-dropdown\s*>\s*a',
    '\.nav-dropdown\s*>\s*a::after',
    '\.nav-dropdown:hover\s*>\s*a::after',
    '\.nav-dropdown:hover\s+\.dropdown-menu',
    '\.dropdown-menu',
    '\.dropdown-menu\s+li\s+a',
    '\.dropdown-menu\s+li\s+a:hover',
    '\.dropdown-menu\s+li\s+a\.dropdown-active',
    '\.dropdown-divider',
    '\.nav-cta',
    '\.nav-cta:hover'
  )

  foreach ($selector in $selectors) {
    $css = Remove-CssRule -Css $css -SelectorPattern $selector
  }

  $css = Remove-DuplicateFaqRule -Css $css
  $css = [regex]::Replace($css, "(\r?\n){3,}", "`r`n`r`n").Trim()

  $parts = New-Object System.Collections.Generic.List[string]
  if ($extras.Count -gt 0) {
    $parts.Add(":root {`r`n$($extras -join "`r`n")`r`n}")
  }
  if ($css.Length -gt 0) {
    $parts.Add($css)
  }

  $newStyle = "<link rel=`"stylesheet`" href=`"/nexus-global.css`">`r`n<style>`r`n$($parts -join "`r`n`r`n")`r`n</style>"
  return $Html.Remove($styleMatch.Index, $styleMatch.Length).Insert($styleMatch.Index, $newStyle)
}

function Convert-MobileNavStyle {
  param([string]$Html)

  if ($Html.Contains('/nexus-mobile-nav.css')) {
    return $Html
  }

  return [regex]::Replace(
    $Html,
    '(?s)<style\s+id="mobile-nav-v3">.*?</style>',
    '<link rel="stylesheet" href="/nexus-mobile-nav.css">'
  )
}

function Remove-TrailingDuplicateFaqStyle {
  param([string]$Html)
  $pattern = '(?s)\s*<style>\s*/\*\s*=== V6 MARGIN FIX: Increase mobile side padding ===\s*\*/(?<body>.*?)</style>'
  return [regex]::Replace($Html, $pattern, {
    param($m)
    $body = Remove-DuplicateFaqRule -Css $m.Groups['body'].Value
    if ($body.Trim().Length -eq 0) {
      return ''
    }
    return "`r`n<style>`r`n/* === V6 MARGIN FIX: Increase mobile side padding === */$body`r`n</style>"
  })
}

[System.IO.File]::WriteAllText($globalCssPath, $globalCss, [System.Text.UTF8Encoding]::new($false))

$indexHtml = [System.IO.File]::ReadAllText((Join-Path $staticDir 'index.html'))
$mobileMatch = [regex]::Match($indexHtml, '(?s)<style\s+id="mobile-nav-v3">(?<css>.*?)</style>')
if (-not $mobileMatch.Success) {
  throw 'Could not find mobile-nav-v3 block in index.html'
}

$mobileCss = $mobileMatch.Groups['css'].Value
$mobileCss = $mobileCss.Replace('section, .hero, [class*="section"], footer, .footer, main', 'section, .hero, footer, .footer, main')
$explicitContainers = '.container, .nx-container, .explore-container, .rotate-wrapper, .carousel-track-wrapper, .faq-answer-inner, .filter-inner, .hero-inner, .mission-inner, .mnv3-inner, .stats-inner, .cta-inner, .empathy-inner, .testimonials-inner, .video-inner'
$mobileCss = $mobileCss.Replace('.container, [class*="container"], [class*="wrapper"], [class*="inner"]', $explicitContainers)
$mobileCss = Remove-DuplicateFaqRule -Css $mobileCss
$mobileCss = [regex]::Replace($mobileCss, "(\r?\n){3,}", "`r`n`r`n").Trim() + "`r`n"
[System.IO.File]::WriteAllText($mobileCssPath, $mobileCss, [System.Text.UTF8Encoding]::new($false))

$convertedGlobal = 0
$convertedMobile = 0
$files = Get-ChildItem -Path $staticDir -Filter '*.html' | Where-Object { $_.Name -ne 'admin.html' }
foreach ($file in $files) {
  $html = [System.IO.File]::ReadAllText($file.FullName)
  $before = $html

  $hadGlobal = $html.Contains('/nexus-global.css')
  $hadMobile = $html.Contains('/nexus-mobile-nav.css')

  $html = Convert-FirstStyle -Html $html
  $html = Convert-MobileNavStyle -Html $html
  $html = Remove-TrailingDuplicateFaqStyle -Html $html

  if ($html -ne $before) {
    [System.IO.File]::WriteAllText($file.FullName, $html, [System.Text.UTF8Encoding]::new($false))
    if (-not $hadGlobal -and $html.Contains('/nexus-global.css')) { $convertedGlobal++ }
    if (-not $hadMobile -and $html.Contains('/nexus-mobile-nav.css')) { $convertedMobile++ }
  }
}

"Wrote $globalCssPath"
"Wrote $mobileCssPath"
"Converted global CSS links: $convertedGlobal"
"Converted mobile nav links: $convertedMobile"
