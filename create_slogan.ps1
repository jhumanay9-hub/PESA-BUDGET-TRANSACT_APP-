Add-Type -AssemblyName System.Drawing
[System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") | Out-Null
$width = 2000
$height = 400
$bmp = New-Object System.Drawing.Bitmap($width, $height)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$g.Clear([System.Drawing.Color]::Transparent)
$font = New-Object System.Drawing.Font("Arial", 60)
$brush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::White)
$line1 = "The app that puts you in control"
$size = $g.MeasureString($line1, $font)
$x = ($width - $size.Width) / 2
$y = ($height - $size.Height) / 2
$g.DrawString($line1, $font, $brush, $x, $y)
$bmp.Save("c:\xampp\htdocs\TRansact__app.n\assets\images\slogan.png", [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose()
$bmp.Dispose()
Write-Host "slogan.png created!"
