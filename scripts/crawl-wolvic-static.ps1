param(
  [string]$SourceUrl = "https://www.wolvic.com/en/start/",
  [string]$OutputPath = "index.html",
  [string]$AssetRoot = "assets"
)

$ErrorActionPreference = "Stop"

function Convert-ToLocalPath {
  param(
    [string]$Url,
    [string]$Kind
  )

  if ($Url -match "^data:|^#|^mailto:|^tel:") {
    return $null
  }

  $source = [uri]$SourceUrl
  $absolute = ([uri]::new($source, $Url)).AbsoluteUri
  $uri = [uri]$absolute

  if ($uri.Host -eq $source.Host -and $uri.AbsolutePath.StartsWith("/assets/")) {
    return ($uri.AbsolutePath.TrimStart("/") -replace "/", "\")
  }

  if ($uri.Host -eq $source.Host -and $uri.AbsolutePath -eq "/favicon.ico") {
    return "favicon.ico"
  }

  if ($uri.Host -eq $source.Host -and $uri.AbsolutePath -eq "/blog/feed.xml") {
    return "blog\feed.xml"
  }

  if ($Kind -eq "src") {
    $ext = [System.IO.Path]::GetExtension($uri.AbsolutePath)
    if ([string]::IsNullOrWhiteSpace($ext)) {
      $ext = ".bin"
    }

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($absolute)
    $sha1 = [System.Security.Cryptography.SHA1]::Create()
    $hash = [System.BitConverter]::ToString($sha1.ComputeHash($bytes)).Replace("-", "").ToLowerInvariant().Substring(0, 12)
    return Join-Path (Join-Path $AssetRoot "remote") "$hash$ext"
  }

  return $null
}

function Save-Asset {
  param(
    [string]$Url,
    [string]$LocalPath
  )

  if ([string]::IsNullOrWhiteSpace($LocalPath)) {
    return
  }

  $target = Join-Path (Get-Location) $LocalPath
  $dir = Split-Path $target
  New-Item -ItemType Directory -Force -Path $dir | Out-Null

  if (Test-Path $target) {
    return
  }

  $source = [uri]$SourceUrl
  $absolute = ([uri]::new($source, $Url)).AbsoluteUri

  try {
    Invoke-WebRequest -Uri $absolute -UseBasicParsing -OutFile $target
  } catch {
    Write-Warning "Could not download $absolute"
  }
}

function Convert-ToWebPath {
  param([string]$Path)
  return $Path -replace "\\", "/"
}

function Install-BrandAssets {
  $logoSource = "METALENSE-01.png"
  $logoTarget = Join-Path $AssetRoot "img\metalense-logo.png"
  $faviconTarget = Join-Path $AssetRoot "img\metalense-favicon.png"

  if (-not (Test-Path -LiteralPath $logoSource)) {
    Write-Warning "Brand source image not found: $logoSource"
    return
  }

  New-Item -ItemType Directory -Force -Path (Split-Path $logoTarget) | Out-Null
  Copy-Item -LiteralPath $logoSource -Destination $logoTarget -Force

  Add-Type -AssemblyName System.Drawing
  $src = [System.Drawing.Image]::FromFile((Resolve-Path $logoSource))
  $canvasSize = 256
  $canvas = New-Object System.Drawing.Bitmap $canvasSize, $canvasSize
  $g = [System.Drawing.Graphics]::FromImage($canvas)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $g.Clear([System.Drawing.Color]::Transparent)

  $cropWidth = [Math]::Min($src.Width, [int]($src.Height * 1.9))
  $srcRect = New-Object System.Drawing.Rectangle 0, 0, $cropWidth, $src.Height
  $scale = [Math]::Min(224 / $cropWidth, 224 / $src.Height)
  $drawWidth = [int]($cropWidth * $scale)
  $drawHeight = [int]($src.Height * $scale)
  $destRect = New-Object System.Drawing.Rectangle ([int](($canvasSize - $drawWidth) / 2)), ([int](($canvasSize - $drawHeight) / 2)), $drawWidth, $drawHeight

  $g.DrawImage($src, $destRect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
  $canvas.Save((Join-Path (Get-Location) $faviconTarget), [System.Drawing.Imaging.ImageFormat]::Png)

  $g.Dispose()
  $canvas.Dispose()
  $src.Dispose()
}

Install-BrandAssets

$html = (Invoke-WebRequest -Uri $SourceUrl -UseBasicParsing).Content
$replacements = [ordered]@{}

[regex]::Matches($html, '(?<attr>src|href)="(?<url>[^"]+)"', "IgnoreCase") | ForEach-Object {
  $attr = $_.Groups["attr"].Value.ToLowerInvariant()
  $url = $_.Groups["url"].Value
  $local = Convert-ToLocalPath -Url $url -Kind $attr
  if ($local) {
    Save-Asset -Url $url -LocalPath $local
    $replacements[$url] = Convert-ToWebPath $local
  }
}

[regex]::Matches($html, 'url\((?<quote>["'']?)(?<url>[^)"'']+)(?<quote2>["'']?)\)', "IgnoreCase") | ForEach-Object {
  $url = $_.Groups["url"].Value
  $local = Convert-ToLocalPath -Url $url -Kind "src"
  if ($local) {
    Save-Asset -Url $url -LocalPath $local
    $replacements[$url] = Convert-ToWebPath $local
  }
}

foreach ($entry in $replacements.GetEnumerator()) {
  $html = $html.Replace('"' + $entry.Key + '"', '"' + $entry.Value + '"')
  $html = $html.Replace("'" + $entry.Key + "'", "'" + $entry.Value + "'")
  $html = $html.Replace("(" + $entry.Key + ")", "(" + $entry.Value + ")")
}

$html = $html -replace '(?s)\s*<label for="dof6" class="off">.*?</label>', ''
$html = $html -replace '(?s)\s*<h2 id="scaseHead"[^>]*>Featured</h2>\s*<div class="featured grid" id="scase"[\s\S]*?</div>\s*<h2>Explore</h2>', "`n`t`t<h2>Explore</h2>"
$html = $html -replace '(?s)\s*// Shuffle the featured items and pick three\.\s*let featured = document\.getElementById\(''scase''\);.*?featured\.append\(\.\.\.selectedItems\);\s*', "`n`t// Random ordering is disabled during sample validation.`n"
$html = $html.Replace("let headers = document.querySelectorAll('#scaseHead, spicy-sections > h3');", "let headers = document.querySelectorAll('spicy-sections > h3');")
$html = $html.Replace("let categories = document.querySelectorAll('#scase, spicy-sections > div');", "let categories = document.querySelectorAll('spicy-sections > div');")
$html = $html -replace '(?s)\s*// shuffle the order in each tab\.\.\.\s*categories\.forEach\(tab => \{.*?tab\.prepend\(\.\.\.collection\);\s*\}\);\s*', ''
$html = $html -replace '(?s)\s*let params = new URLSearchParams\(window\.location\.search\);\s*if \(params\.get\(''device''\) == ''3dof'' \|\| params\.has\(''3dof''\)\) \{.*?\}\s*', ''
$html = $html -replace '(?s)\s*function shuffle\(array\) \{.*?\}\s*(?=function startup\(\))', "`n"
$html = $html.Replace("let categories = document.querySelectorAll('spicy-sections > div');function filter", "let categories = document.querySelectorAll('spicy-sections > div');`n`n`tfunction filter")
$html = $html.Replace("// Random ordering is disabled during sample validation.`nlet headers", "// Random ordering is disabled during sample validation.`n`tlet headers")
$html = $html.Replace('<spicy-sections class="tags">', '<div class="tags sections-list">')
$html = $html.Replace('</spicy-sections>', '</div>')
$html = $html -replace '\s*<script src="assets/js/SpicySections.js" type="module"></script>', ''
$html = $html -replace '(?s)\s*spicy-sections \{.*?\}\s*:where\(spicy-sections > \[affordance\*="collapse"\]\)::before \{.*?\}\s*\[affordance="tab-bar"\] h3 \{.*?\}\s*\[affordance="collapse"\] :nth-child\(2n\) \{.*?\}\s*\[affordance="tab-bar"\] h2:not\(\[tabindex="0"\]\) \{.*?\}', ''
$html = $html.Replace("`n.tags.filtering {", "`n.sections-list h3 {`n`tcursor: default;`n`tborder-radius: 0;`n`tborder: 0;`n`tborder-bottom: 2px solid #555;`n`tbackground: transparent;`n`tmargin: 2rem 0 1rem;`n`tpadding: 0 0 0.5rem;`n`tfont-size: 1.4em;`n`ttext-align: left;`n}`n`n.tags.filtering {")
$html = $html -replace '(?s)function startup\(\) \{.*?\}\s*const galleryDiv = document\.getElementById\(''gallery''\);\s*let items =\s*document\.querySelectorAll\(''#gallery \.item''\);\s*startup\(\)', "function startup() {`n`t// Random ordering is disabled during sample validation.`n}`n`nstartup()"

$html = $html -replace '<link rel="shortcut icon" type="image/x-icon" href="[^"]+">', '<link rel="icon" type="image/png" href="assets/img/metalense-favicon.png">'
$html = $html -replace '<meta property="og:image" content="[^"]+">', '<meta property="og:image" content="assets/img/metalense-logo.png">'
$html = $html -replace '<a href="/en"><img class="full logo" src="data:image/png;base64,[^"]+" alt="Wolvic"></a>', '<a href="index.html"><img class="full logo" src="assets/img/metalense-logo.png" alt="METALENSE"></a>'
$html = $html -replace 'header \.logo \{\s*max-width: 11rem;\s*width: 100%;\s*\}', "header .logo {`n`tmax-width: min(42rem, 82vw);`n`twidth: 100%;`n}"
$html = $html -replace 'img\.logo \{\s*margin-top: 1vh;\s*\}', "img.logo {`n`tmargin-top: 1vh;`n}"

$stamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss zzz")
$html = $html -replace '<html lang="en">', "<html lang=`"en`">`n<!-- Static crawl of $SourceUrl at $stamp. -->"

Set-Content -Path $OutputPath -Value $html -Encoding UTF8

Write-Output "Saved static crawl: $OutputPath"
Write-Output "Assets downloaded under: $AssetRoot"
