$ErrorActionPreference = "Stop"

$Root = Resolve-Path "."
$OutDir = Join-Path $Root "outputs"
$DeckPath = Join-Path $OutDir "Health_Mate_Stronger_Defense_Presentation.pptx"
$PreviewDir = Join-Path $OutDir "Health_Mate_Stronger_Defense_Presentation_preview"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
New-Item -ItemType Directory -Force -Path $PreviewDir | Out-Null

$Assets = Join-Path $Root "assets\branding"
$Icon = Join-Path $Root "Front-end\health_mate_app\assets\icon\icon.png"
$UniLogo = Join-Path $Assets "zagazig_university_logo.jpeg"
$FacultyLogo = Join-Path $Assets "faculty_computers_informatics_logo.jpeg"

$ppLayoutBlank = 12
$msoTextHorizontal = 1
$msoTrue = -1
$msoFalse = 0
$msoShapeRectangle = 1
$msoShapeRoundedRectangle = 5
$msoShapeOval = 9
$msoConnectorStraight = 1
$msoLineDash = 4
$ppSaveAsOpenXMLPresentation = 24
$ppEffectFadeSmoothly = 3849
$msoAnimEffectFade = 10
$msoAnimTriggerAfterPrevious = 3
$msoAnimTriggerWithPrevious = 2

$C = @{
  Ink = 0x172026
  Navy = 0x2A2113
  Dark = 0x211A10
  Teal = 0x7D7D0E
  Green = 0x6AA84F
  Coral = 0x5D625E
  Red = 0x4F46E5
  Amber = 0x2FB8F2
  Blue = 0xD99B38
  Soft = 0xF7FAFC
  Mist = 0xE9F7F7
  Line = 0xD5DEE5
  White = 0xFFFFFF
  Gray = 0x58636F
}

function RgbHex($hex) {
  $h = $hex.TrimStart("#")
  $r = [Convert]::ToInt32($h.Substring(0,2),16)
  $g = [Convert]::ToInt32($h.Substring(2,2),16)
  $b = [Convert]::ToInt32($h.Substring(4,2),16)
  return $r + ($g * 256) + ($b * 65536)
}

$C.Ink = RgbHex "#172026"
$C.Navy = RgbHex "#102A43"
$C.Dark = RgbHex "#071923"
$C.Teal = RgbHex "#0F7C80"
$C.Green = RgbHex "#2E8B57"
$C.Coral = RgbHex "#E85D57"
$C.Red = RgbHex "#D64545"
$C.Amber = RgbHex "#F4A261"
$C.Blue = RgbHex "#3A86B7"
$C.Soft = RgbHex "#F7FAFC"
$C.Mist = RgbHex "#E8F6F6"
$C.Line = RgbHex "#D8E2EA"
$C.White = RgbHex "#FFFFFF"
$C.Gray = RgbHex "#5C6B73"

function Add-Slide {
  param($Pres, [string]$Section = "")
  $slide = $Pres.Slides.Add($Pres.Slides.Count + 1, $ppLayoutBlank)
  $slide.FollowMasterBackground = $msoFalse
  $slide.Background.Fill.ForeColor.RGB = $C.Soft
  try { $slide.SlideShowTransition.EntryEffect = $ppEffectFadeSmoothly } catch {}
  if ($Section) {
    Add-Text $slide $Section 44 26 260 18 9 $C.Teal $true "left" | Out-Null
  }
  return $slide
}

function Add-Text {
  param($Slide, [string]$Text, [double]$X, [double]$Y, [double]$W, [double]$H, [double]$Size = 18, [int]$Color = $C.Ink, [bool]$Bold = $false, [string]$Align = "left", [string]$Font = "Segoe UI")
  $shape = $Slide.Shapes.AddTextbox($msoTextHorizontal, $X, $Y, $W, $H)
  $shape.TextFrame.MarginLeft = 0
  $shape.TextFrame.MarginRight = 0
  $shape.TextFrame.MarginTop = 0
  $shape.TextFrame.MarginBottom = 0
  $shape.TextFrame.WordWrap = $msoTrue
  $shape.TextFrame.TextRange.Text = $Text
  $shape.TextFrame.TextRange.Font.Name = $Font
  $shape.TextFrame.TextRange.Font.Size = $Size
  $shape.TextFrame.TextRange.Font.Bold = if ($Bold) { $msoTrue } else { $msoFalse }
  $shape.TextFrame.TextRange.Font.Color.RGB = $Color
  switch ($Align) {
    "center" { $shape.TextFrame.TextRange.ParagraphFormat.Alignment = 2 }
    "right" { $shape.TextFrame.TextRange.ParagraphFormat.Alignment = 3 }
    default { $shape.TextFrame.TextRange.ParagraphFormat.Alignment = 1 }
  }
  return $shape
}

function Add-Box {
  param($Slide, [double]$X, [double]$Y, [double]$W, [double]$H, [int]$Fill = $C.White, [int]$Line = $C.Line, [double]$LineWeight = 1.0, [int]$RadiusShape = $msoShapeRoundedRectangle)
  $shape = $Slide.Shapes.AddShape($RadiusShape, $X, $Y, $W, $H)
  $shape.Fill.ForeColor.RGB = $Fill
  $shape.Line.ForeColor.RGB = $Line
  $shape.Line.Weight = $LineWeight
  return $shape
}

function Add-Title {
  param($Slide, [string]$Title, [string]$Subtitle = "")
  $long = $Title.Length -gt 62
  $titleSize = if ($long) { 27 } else { 34 }
  $titleHeight = if ($long) { 86 } else { 58 }
  $subtitleY = if ($long) { 144 } else { 102 }
  Add-Text $Slide $Title 44 52 850 $titleHeight $titleSize $C.Ink $true | Out-Null
  if ($Subtitle) { Add-Text $Slide $Subtitle 46 $subtitleY 810 34 16 $C.Gray $false | Out-Null }
}

function Add-Footer {
  param($Slide, [int]$N, [string]$Mode = "")
  Add-Text $Slide "Health Mate - Zagazig University - 2025/2026" 44 512 480 14 8 $C.Gray $false | Out-Null
  Add-Text $Slide "$N" 902 512 24 14 8 $C.Gray $false "right" | Out-Null
}

function Add-ImageContain {
  param($Slide, [string]$Path, [double]$X, [double]$Y, [double]$W, [double]$H)
  if (!(Test-Path $Path)) { return $null }
  Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
  $img = [System.Drawing.Image]::FromFile($Path)
  $iw = $img.Width
  $ih = $img.Height
  $img.Dispose()
  $scale = [Math]::Min($W / $iw, $H / $ih)
  $nw = $iw * $scale
  $nh = $ih * $scale
  $px = $X + (($W - $nw) / 2)
  $py = $Y + (($H - $nh) / 2)
  return $Slide.Shapes.AddPicture($Path, $msoFalse, $msoTrue, $px, $py, $nw, $nh)
}

function Add-Phone {
  param($Slide, [string]$Path, [double]$X, [double]$Y, [double]$W = 84, [string]$Label = "")
  $H = $W * 2.05
  Add-Box $Slide ($X-6) ($Y-8) ($W+12) ($H+16) (RgbHex "#0B1F2A") (RgbHex "#0B1F2A") 1 | Out-Null
  Add-ImageContain $Slide $Path $X $Y $W $H | Out-Null
  if ($Label) { Add-Text $Slide $Label ($X-10) ($Y+$H+11) ($W+20) 22 9 $C.Gray $true "center" | Out-Null }
}

function Add-Chip {
  param($Slide, [string]$Text, [double]$X, [double]$Y, [double]$W, [int]$Fill, [int]$TextColor = $C.White)
  Add-Box $Slide $X $Y $W 27 $Fill $Fill 0.5 | Out-Null
  Add-Text $Slide $Text ($X+9) ($Y+6) ($W-18) 12 8.5 $TextColor $true "center" | Out-Null
}

function Add-Metric {
  param($Slide, [string]$Number, [string]$Label, [double]$X, [double]$Y, [double]$W, [int]$Color = $C.Teal)
  Add-Box $Slide $X $Y $W 86 $C.White $C.Line 1 | Out-Null
  Add-Text $Slide $Number ($X+14) ($Y+13) ($W-28) 28 25 $Color $true "center" | Out-Null
  Add-Text $Slide $Label ($X+12) ($Y+51) ($W-24) 28 10 $C.Gray $false "center" | Out-Null
}

function Add-Arrow {
  param($Slide, [double]$X1, [double]$Y1, [double]$X2, [double]$Y2, [int]$Color = $C.Teal)
  $line = $Slide.Shapes.AddConnector($msoConnectorStraight, $X1, $Y1, $X2, $Y2)
  $line.Line.ForeColor.RGB = $Color
  $line.Line.Weight = 2
  $line.Line.EndArrowheadStyle = 3
  return $line
}

function Add-Bullets {
  param($Slide, [string[]]$Items, [double]$X, [double]$Y, [double]$W, [double]$H, [double]$Size = 15, [int]$Color = $C.Ink)
  $txt = ($Items | ForEach-Object { "- $_" }) -join "`r"
  $shape = Add-Text $Slide $txt $X $Y $W $H $Size $Color $false
  $shape.TextFrame.TextRange.ParagraphFormat.SpaceAfter = 6
  return $shape
}

function Add-Table {
  param($Slide, [array]$Rows, [double]$X, [double]$Y, [double]$W, [double]$H, [array]$Widths = $null, [int]$HeaderFill = $C.Navy, [int]$HeaderText = $C.White)
  $nRows = $Rows.Count
  $nCols = $Rows[0].Count
  if ($null -eq $Widths) { $Widths = @(1) * $nCols }
  $total = ($Widths | Measure-Object -Sum).Sum
  $rowH = $H / $nRows
  $stripe = $false
  for ($r=0; $r -lt $nRows; $r++) {
    $cx = $X
    for ($c=0; $c -lt $nCols; $c++) {
      $cw = $W * ($Widths[$c] / $total)
      if ($r -eq 0) {
        $fill = $HeaderFill
      } elseif ($stripe) {
        $fill = RgbHex "#F2F7F8"
      } else {
        $fill = RgbHex "#FBFDFE"
      }
      $txtColor = if ($r -eq 0) { $HeaderText } else { $C.Ink }
      Add-Box $Slide $cx ($Y + $r*$rowH) $cw $rowH $fill $C.Line 0.75 $msoShapeRectangle | Out-Null
      Add-Text $Slide ([string]$Rows[$r][$c]) ($cx+5) ($Y + $r*$rowH + 7) ($cw-10) ($rowH-10) 9.5 $txtColor ($r -eq 0) "center" | Out-Null
      $cx += $cw
    }
    if ($r -gt 0) { $stripe = -not $stripe }
  }
}

function Animate-In {
  param($Slide, $Shape, [bool]$WithPrevious = $false)
  try {
    $trigger = if ($WithPrevious) { $msoAnimTriggerWithPrevious } else { $msoAnimTriggerAfterPrevious }
    $eff = $Slide.TimeLine.MainSequence.AddEffect($Shape, $msoAnimEffectFade, 0, $trigger)
    $eff.Timing.Duration = 0.35
  } catch {}
}

function Add-SectionBand {
  param($Slide, [string]$Text, [int]$Fill = $C.Dark)
  Add-Box $Slide 0 0 960 540 $Fill $Fill 0 $msoShapeRectangle | Out-Null
  Add-Text $Slide $Text 70 188 820 92 42 $C.White $true "center" | Out-Null
}

$ppt = New-Object -ComObject PowerPoint.Application
$ppt.Visible = $msoTrue
try { $ppt.WindowState = 2 } catch {}
$pres = $ppt.Presentations.Add($msoTrue)
$pres.PageSetup.SlideWidth = 960
$pres.PageSetup.SlideHeight = 540

$slides = @()

# 1
$s = Add-Slide $pres
Add-Box $s 0 0 960 540 $C.Dark $C.Dark 0 $msoShapeRectangle | Out-Null
Add-ImageContain $s $UniLogo 42 28 105 52 | Out-Null
Add-ImageContain $s $FacultyLogo 812 29 108 43 | Out-Null
Add-ImageContain $s $Icon 642 104 220 220 | Out-Null
Add-Text $s "Health Mate" 54 132 520 64 50 $C.White $true | Out-Null
Add-Text $s "An AI-assisted remote monitoring system for chronic cardiovascular care" 58 206 530 62 20 (RgbHex "#C8E6E7") $false | Out-Null
Add-Text $s "Graduation Project Defense - AI and Data Science Program" 58 286 530 24 13 (RgbHex "#9ECFD1") $true | Out-Null
Add-Text $s "Omar Ashraf Mohamed Kamal (Team Leader)  -  Seif EL-Deen Amr Mohamed`rRofida Mohamed Ahmed Ibrahim  -  Farida Abdelazim Gharib Mohamed`rSupervised by ASS. Prof. Dr. Amr Abdellatif and Eng. Mohamed Ameen" 58 418 760 62 11 $C.White $false | Out-Null
$slides += $s

# 2
$s = Add-Slide $pres "OPENING"
Add-Title $s "The project closes the gap between a reading and a response." "Health Mate is not a single-feature app; it is an end-to-end loop for patients and caregivers."
Add-Metric $s "Measure" "8-second PPG + ECG capture, or manual cuff reading" 70 178 210 $C.Teal
Add-Metric $s "Understand" "AI estimation, rule-based urgency, calibration and drift checks" 374 178 210 $C.Blue
Add-Metric $s "Act" "Caregiver alerts, medication alarms, and emergency calling" 678 178 210 $C.Coral
Add-Arrow $s 284 221 364 221 $C.Teal | Out-Null
Add-Arrow $s 588 221 668 221 $C.Teal | Out-Null
Add-Text $s "By the end, the committee should believe this is a working remote-monitoring system with measurable AI results, real hardware integration, and honest boundaries." 132 342 700 62 20 $C.Ink $true "center" | Out-Null
Add-Footer $s 2
$slides += $s

# 3
$s = Add-Slide $pres "PROBLEM"
Add-Title $s "The danger is not only high blood pressure; it is delayed awareness." "A patient can miss the reading, misread the risk, or fail to reach help in time."
Add-Box $s 58 164 250 222 $C.White $C.Line 1 | Out-Null
Add-Text $s "Patient side" 82 188 200 24 18 $C.Teal $true | Out-Null
Add-Bullets $s @("cuff placement and logging are easy to skip","daily routines fail under fatigue or memory loss","a critical moment still depends on the patient noticing") 82 230 194 105 14 | Out-Null
Add-Box $s 356 164 250 222 $C.White $C.Line 1 | Out-Null
Add-Text $s "Caregiver side" 380 188 200 24 18 $C.Coral $true | Out-Null
Add-Bullets $s @("no live view unless the patient reports back","no automatic escalation when risk crosses a line","the family reacts after the fact") 380 230 194 105 14 | Out-Null
Add-Box $s 654 164 250 222 (RgbHex "#FFF4E8") (RgbHex "#F4C28A") 1 | Out-Null
Add-Text $s "Design target" 678 188 200 24 18 (RgbHex "#9C5700") $true | Out-Null
Add-Bullets $s @("reduce measurement friction","make the risk visible immediately","give the caregiver a direct action path") 678 230 194 105 14 | Out-Null
Add-Text $s "The story of the system is a safety loop, not a feature checklist." 164 424 632 24 19 $C.Ink $true "center" | Out-Null
Add-Footer $s 3
$slides += $s

# 4
$s = Add-Slide $pres "MARKET"
Add-Title $s "Existing solutions solve pieces of the loop, not the whole loop."
$rows = @(
  @("Capability","Cuff + log","Wearables","Connected monitors","Clinical RPM","Health Mate"),
  @("Cuffless AI sensing","No","No","No","No","Yes"),
  @("Family caregiver alerts","No","Partial","Partial","Partial","Yes"),
  @("Symptom + red-flag triage","No","No","No","Partial","Yes"),
  @("Smart medication hardware","No","No","No","No","Yes"),
  @("Emergency call path","No","No","No","No","Yes"),
  @("Arabic + English parity","No","Partial","Partial","Partial","Yes")
)
Add-Table $s $rows 55 152 850 260 @(1.55,0.92,0.92,1.20,1.00,0.95)
Add-Text $s "Positioning: Health Mate is a research prototype, not a cleared medical device. Its strength is integration depth and transparent evaluation." 94 440 770 32 15 $C.Gray $false "center" | Out-Null
Add-Footer $s 4
$slides += $s

# 5
$s = Add-Slide $pres "SOLUTION"
Add-Title $s "Health Mate is built as one closed safety loop." "The hardware collects; the backend decides; the app turns decisions into action."
$nodes = @(
  @("BP sensing unit","ESP8266 + MAX30102 + AD8232",100,168,$C.Teal),
  @("FastAPI backend","validation, inference, calibration",375,110,$C.Navy),
  @("AI + rule engine","BP model + symptom triage",652,168,$C.Blue),
  @("Flutter app","patient and caregiver views",548,350,$C.Green),
  @("Smart box + calls","medication cues and escalation",210,350,$C.Coral)
)
foreach ($n in $nodes) {
  Add-Box $s $n[2] $n[3] 210 78 $C.White $n[4] 2 | Out-Null
  Add-Text $s $n[0] ($n[2]+12) ($n[3]+15) 186 22 15 $n[4] $true "center" | Out-Null
  Add-Text $s $n[1] ($n[2]+12) ($n[3]+42) 186 20 10.5 $C.Gray $false "center" | Out-Null
}
Add-Arrow $s 310 198 374 162 $C.Teal | Out-Null
Add-Arrow $s 586 162 652 198 $C.Teal | Out-Null
Add-Arrow $s 745 246 656 350 $C.Teal | Out-Null
Add-Arrow $s 548 389 420 389 $C.Teal | Out-Null
Add-Arrow $s 210 350 158 246 $C.Teal | Out-Null
Add-Text $s "Core architectural rule: devices never make clinical decisions." 252 278 456 28 20 $C.Ink $true "center" | Out-Null
Add-Footer $s 5
$slides += $s

# 6
$s = Add-Slide $pres "ARCHITECTURE"
Add-Title $s "Backend decisions make safety traceable." "That choice makes safety logic traceable and testable."
$layers = @(
  @("IoT hardware","BP unit captures 800 samples; smart box indicates drawers",154,$C.Teal),
  @("Backend API","FastAPI, Socket.IO, APScheduler, model services",232,$C.Navy),
  @("Data and infra","PostgreSQL, Redis, Cloudinary, Firebase Messaging",310,$C.Blue),
  @("Mobile app","Flutter, Riverpod, Dio, Hive, secure storage, localization",388,$C.Green)
)
foreach ($l in $layers) {
  Add-Box $s 72 $l[2] 816 58 $C.White $l[3] 2 | Out-Null
  Add-Text $s $l[0] 100 ($l[2]+14) 170 20 15 $l[3] $true | Out-Null
  Add-Text $s $l[1] 286 ($l[2]+16) 570 20 14 $C.Ink $false | Out-Null
}
Add-Text $s "Two architectural styles coexist: service layer for most features; clean/hexagonal architecture for symptom checker v2." 108 468 744 24 13.5 $C.Gray $false "center" | Out-Null
Add-Footer $s 6
$slides += $s

# 7
$s = Add-Slide $pres "EXPERIENCE"
Add-Title $s "The same app serves two people without duplicating the system." "Screens are Arabic/RTL-capable and backed by shared providers and repositories."
Add-Phone $s (Join-Path $Assets "screen_home_patient.png") 86 162 86 "Patient"
Add-Phone $s (Join-Path $Assets "screen_home_caregiver.png") 244 162 86 "Caregiver"
Add-Phone $s (Join-Path $Assets "screen_bp_3_result.png") 402 162 86 "BP result"
Add-Phone $s (Join-Path $Assets "screen_notifications.png") 560 162 86 "Alerts"
Add-Phone $s (Join-Path $Assets "screen_linking_qr.png") 718 162 86 "Linking"
Add-Text $s "One codebase, role-aware routing, localized reminders, and offline access to the last known vital history." 126 444 708 28 17 $C.Ink $true "center" | Out-Null
Add-Footer $s 7
$slides += $s

# 8
$s = Add-Slide $pres "HARDWARE"
Add-Title $s "The hardware is custom, but each device has a narrow responsibility." "That makes the prototype easier to reason about and safer to fail."
Add-Box $s 58 152 405 250 $C.White $C.Line 1 | Out-Null
Add-Text $s "Blood-pressure sensing unit" 80 172 300 22 18 $C.Teal $true | Out-Null
Add-ImageContain $s (Join-Path $Assets "bp_hardware_circuit.png") 86 212 142 120 | Out-Null
Add-Bullets $s @("ESP8266-12E, MAX30102 PPG, AD8232 ECG","100 Hz sampling, exactly 800 samples per channel","finger and lead-off gates reject bad windows") 244 218 190 100 12.5 | Out-Null
Add-Box $s 498 152 405 250 $C.White $C.Line 1 | Out-Null
Add-Text $s "Smart medicine box" 520 172 300 22 18 $C.Coral $true | Out-Null
Add-ImageContain $s (Join-Path $Assets "smart_box_circuit.png") 528 212 142 120 | Out-Null
Add-Bullets $s @("ESP32 plus 74HC595, LEDs and buzzer","indicator, not dispenser: patient opens drawer","fail-soft: phone alarm still fires if box is offline") 686 218 190 100 12.5 | Out-Null
Add-Text $s "Honesty point: neither device contains the AI model; all clinical interpretation stays in the backend." 132 434 696 26 16 $C.Gray $true "center" | Out-Null
Add-Footer $s 8
$slides += $s

# 9
$s = Add-Slide $pres "BP MODEL"
Add-Title $s "The BP model was evaluated as a fair model-selection problem." "The dataset split and preprocessing choices are the credibility story."
Add-Metric $s "653K+" "PPG + ECG signal windows" 70 168 180 $C.Teal
Add-Metric $s "1,631" "held-out patient records" 282 168 180 $C.Blue
Add-Metric $s "10" "models compared" 494 168 180 $C.Coral
Add-Metric $s "21" "hand-crafted waveform features" 706 168 180 $C.Green
Add-ImageContain $s (Join-Path $Assets "fig_01_max30102_pipeline.png") 88 314 360 80 | Out-Null
Add-ImageContain $s (Join-Path $Assets "fig_02_ad8232_pipeline.png") 512 314 360 80 | Out-Null
Add-Text $s "Record-level split prevents leakage from overlapping windows of the same patient. Training and production share the same filtering, normalization, and feature extraction path." 94 430 772 34 15 $C.Gray $false "center" | Out-Null
Add-Footer $s 9
$slides += $s

# 10
$s = Add-Slide $pres "BP RESULTS"
Add-Title $s "The strongest result is also the most honest one: the simplest deep model won." "More architecture did not automatically mean better accuracy."
$rows = @(
  @("Model","SBP MAE","DBP MAE","DBP BHS","Interpretation"),
  @("1D-CNN","9.08","4.91","B","best overall"),
  @("TCN","9.79","5.31","B","close but weaker"),
  @("TCN+BiLSTM+Attn","10.17","5.63","B","our proposed model did not win"),
  @("BiLSTM","14.34","7.28","C","weaker sequence baseline"),
  @("XGBoost","14.71","7.45","C","best classical baseline")
)
Add-Table $s $rows 62 144 500 245 @(1.45,0.72,0.72,0.65,1.75)
Add-ImageContain $s (Join-Path $Assets "fig_12_mae_comparison_sbp.png") 606 144 280 118 | Out-Null
Add-ImageContain $s (Join-Path $Assets "fig_13_mae_comparison_dbp.png") 606 278 280 118 | Out-Null
Add-Text $s "Committee-ready takeaway: the team ran the baseline, accepted the result, and deployed the model that actually performed best." 118 438 724 28 16 $C.Ink $true "center" | Out-Null
Add-Footer $s 10
$slides += $s

# 11
$s = Add-Slide $pres "CLINICAL TRUTH"
Add-Title $s "Best model and clinically acceptable model are different claims." "The deck says both out loud before the committee has to ask."
Add-Metric $s "9.08" "SBP MAE - fails AAMI, BHS D" 96 170 220 $C.Red
Add-Metric $s "4.91" "DBP MAE - passes AAMI, BHS B" 370 170 220 $C.Green
Add-Metric $s "80 ms" "model inference after an 8s window" 644 170 220 $C.Teal
Add-Box $s 132 318 696 92 (RgbHex "#FFF8ED") (RgbHex "#F4C28A") 1 | Out-Null
Add-Text $s "How we present it safely" 164 338 260 22 16 (RgbHex "#9C5700") $true | Out-Null
Add-Bullets $s @("SBP is a trend indicator until real-hardware validation closes the gap","DBP clears the clinical accuracy bar in the current test set","calibration, physiological clamping, and withheld states protect the app experience") 164 368 600 40 12.5 | Out-Null
Add-Footer $s 11
$slides += $s

# 12
$s = Add-Slide $pres "SYMPTOM TRIAGE"
Add-Title $s "The symptom checker moves from text matching to structured triage." "Severity, duration, vitals, and risk factors become model input."
Add-Phone $s (Join-Path $Assets "screen_sym_1_category.png") 74 158 76 "Category"
Add-Phone $s (Join-Path $Assets "screen_sym_2_symptoms.png") 206 158 76 "Symptoms"
Add-Phone $s (Join-Path $Assets "screen_sym_3_severity.png") 338 158 76 "Severity"
Add-Phone $s (Join-Path $Assets "screen_sym_5_result.png") 470 158 76 "Result"
Add-Metric $s "232" "structured features" 640 158 210 $C.Teal
Add-Metric $s "85.8%" "top-1 accuracy" 640 258 210 $C.Blue
Add-Metric $s "95.5%" "top-3 accuracy" 640 358 210 $C.Green
Add-Text $s "Training uses synthetic structured cases generated from disease profiles, so the next validation step is real patient assessment data." 104 454 752 24 14 $C.Gray $false "center" | Out-Null
Add-Footer $s 12
$slides += $s

# 13
$s = Add-Slide $pres "SAFETY"
Add-Title $s "The safety layer can escalate the model, but it cannot be talked down by it." "This is the core defense against overtrusting ML confidence."
$steps = @(
  @("1","Red flags","symptoms like syncope trigger independently",$C.Red,68),
  @("2","Vitals floor","BP, HR, SpO2 create a minimum urgency",$C.Amber,284),
  @("3","ML prediction","top disease candidates and confidence",$C.Blue,500),
  @("4","Caregiver alert","high or critical cases trigger escalation",$C.Green,716)
)
foreach ($st in $steps) {
  Add-Box $s $st[4] 178 176 130 $C.White $st[3] 2 | Out-Null
  Add-Text $s $st[0] ($st[4]+68) 194 42 28 26 $st[3] $true "center" | Out-Null
  Add-Text $s $st[1] ($st[4]+14) 232 148 20 15 $C.Ink $true "center" | Out-Null
  Add-Text $s $st[2] ($st[4]+16) 260 144 36 10.5 $C.Gray $false "center" | Out-Null
}
Add-Arrow $s 244 244 284 244 $C.Teal | Out-Null
Add-Arrow $s 460 244 500 244 $C.Teal | Out-Null
Add-Arrow $s 676 244 716 244 $C.Teal | Out-Null
Add-Text $s "Hard rule: ML may support triage, but rule-engine red flags set the floor." 150 378 660 32 21 $C.Ink $true "center" | Out-Null
Add-Footer $s 13
$slides += $s

# 14
$s = Add-Slide $pres "DEMO STORY"
Add-Title $s "The demo should be narrated as one patient journey." "A story-driven demo beats a tour of screens."
Add-Phone $s (Join-Path $Assets "screen_bp_1_setup.png") 62 158 72 "setup"
Add-Phone $s (Join-Path $Assets "screen_bp_2_measuring.png") 188 158 72 "measure"
Add-Phone $s (Join-Path $Assets "screen_bp_3_result.png") 314 158 72 "result"
Add-Phone $s (Join-Path $Assets "screen_med_4_alarm.png") 440 158 72 "dose"
Add-Phone $s (Join-Path $Assets "screen_call_4_emergency.png") 566 158 72 "call"
Add-Phone $s (Join-Path $Assets "screen_home_caregiver.png") 692 158 72 "caregiver"
Add-Text $s "Recommended narration: a patient measures, risk is interpreted, the caregiver sees the state, medication support keeps the routine alive, and emergency calling closes the action path." 108 448 744 34 15 $C.Gray $false "center" | Out-Null
Add-Footer $s 14
$slides += $s

# 15
$s = Add-Slide $pres "ENGINEERING"
Add-Title $s "The engineering work is visible in the failure paths, not only the happy path." "These details are the committee's evidence that the project is more than UI."
Add-Box $s 70 152 250 232 $C.White $C.Line 1 | Out-Null
Add-Text $s "Backend safeguards" 94 176 200 24 17 $C.Navy $true | Out-Null
Add-Bullets $s @("model_not_ready fallback instead of silent failure","risk-tier cooldowns for alert spam control","physiological clamps before storing values") 94 216 184 88 13 | Out-Null
Add-Box $s 355 152 250 232 $C.White $C.Line 1 | Out-Null
Add-Text $s "Data rules" 379 176 200 24 17 $C.Teal $true | Out-Null
Add-Bullets $s @("21-table PostgreSQL schema","one active primary caregiver enforced in DB","nullable BP values represent withheld readings intentionally") 379 216 184 88 13 | Out-Null
Add-Box $s 640 152 250 232 $C.White $C.Line 1 | Out-Null
Add-Text $s "Mobile resilience" 664 176 200 24 17 $C.Green $true | Out-Null
Add-Bullets $s @("Hive cache for last known readings","localized push and local alarms","role-aware screens reuse shared logic") 664 216 184 88 13 | Out-Null
Add-Footer $s 15
$slides += $s

# 16
$s = Add-Slide $pres "RESULTS"
Add-Title $s "Every headline number is grounded in code or documentation." "This slide is the answer to 'what did you actually achieve?'"
Add-Metric $s "4.91" "DBP MAE, AAMI pass" 72 155 168 $C.Green
Add-Metric $s "85.8 / 95.5" "symptom top-1 / top-3" 268 155 168 $C.Blue
Add-Metric $s "653K+" "signal windows" 464 155 168 $C.Teal
Add-Metric $s "21" "database tables" 660 155 168 $C.Navy
Add-Metric $s "2" "custom IoT devices" 170 282 168 $C.Coral
Add-Metric $s "613/614" "EN/AR key parity" 366 282 168 $C.Amber
Add-Metric $s "0" "targeted cross-confusion pairs" 562 282 168 $C.Green
Add-Text $s "The strongest proof is not one number. It is the breadth of a working chain: sensor -> model -> rules -> database -> notification -> caregiver action." 112 436 736 34 16 $C.Ink $true "center" | Out-Null
Add-Footer $s 16
$slides += $s

# 17
$s = Add-Slide $pres "LIMITS"
Add-Title $s "Limitations are part of the defense." "Naming them early reduces surprise questions and shows engineering judgment."
$rows = @(
  @("Known gap","Why it matters","Planned answer"),
  @("SBP fails AAMI","primary BP number is not clinical-grade yet","validate on real hardware and target SBP error"),
  @("BP model not tested on live sensor recordings","dataset does not equal home-use conditions","collect cuff-paired MAX30102/AD8232 data"),
  @("Cardiac subtype weakness in triage","the domain focus is cardiovascular","add real assessment data and retrain baselines"),
  @("QR linking is unsigned/unexpired","security hardening needed before production","sign, encrypt or expire the payload"),
  @("No refresh-token revocation","standard stateless JWT tradeoff","add server-side token/session revocation")
)
Add-Table $s $rows 50 174 860 272 @(1.25,1.60,1.85) $C.Red $C.White
Add-Footer $s 17
$slides += $s

# 18
$s = Add-Slide $pres "ROADMAP"
Add-Title $s "The next work is validation and hardening, not inventing a new product." "The roadmap follows directly from measured gaps."
Add-Box $s 80 160 240 230 $C.White $C.Teal 2 | Out-Null
Add-Text $s "Validate" 106 188 180 24 20 $C.Teal $true | Out-Null
Add-Bullets $s @("real sensor recordings vs reference cuff","time-separated calibration samples","clinical review of remaining thresholds") 106 230 180 94 13 | Out-Null
Add-Box $s 360 160 240 230 $C.White $C.Blue 2 | Out-Null
Add-Text $s "Improve" 386 188 180 24 20 $C.Blue $true | Out-Null
Add-Bullets $s @("target SBP-specific error sources","investigate why complex models underperformed","strengthen cardiac subtype discrimination") 386 230 180 94 13 | Out-Null
Add-Box $s 640 160 240 230 $C.White $C.Green 2 | Out-Null
Add-Text $s "Harden" 666 188 180 24 20 $C.Green $true | Out-Null
Add-Bullets $s @("signed/expiring caregiver linking","refresh-token revocation","unify symptom checker generations") 666 230 180 94 13 | Out-Null
Add-Footer $s 18
$slides += $s

# 19
$s = Add-Slide $pres "CLOSE"
Add-Box $s 0 0 960 540 $C.Dark $C.Dark 0 $msoShapeRectangle | Out-Null
Add-ImageContain $s $Icon 684 94 180 180 | Out-Null
Add-Text $s "Health Mate proves the full loop." 72 118 560 60 42 $C.White $true | Out-Null
Add-Text $s "Custom sensing hardware, two evaluated AI subsystems, a backend that owns safety decisions, and a bilingual app that connects patients with caregivers." 76 206 620 78 21 (RgbHex "#D7F0F0") $false | Out-Null
Add-Text $s "The project is strongest when presented honestly: what works, what passes, what does not pass yet, and exactly what comes next." 76 334 680 48 19 $C.White $true | Out-Null
Add-Text $s "Questions and discussion" 76 442 360 28 18 (RgbHex "#9ECFD1") $true | Out-Null
$slides += $s

# 20
$s = Add-Slide $pres "APPENDIX"
Add-SectionBand $s "Appendix: likely committee questions, already prepared" $C.Navy
$slides += $s

# 21
$s = Add-Slide $pres "APPENDIX"
Add-Title $s "Why not just use a connected cuff?" "Because the project target is the whole family-response loop."
$rows = @(
  @("Question","Short answer"),
  @("Is a cuff more clinically reliable?","Yes. That is why Health Mate keeps cuff calibration and does not claim SBP clinical readiness."),
  @("Then why cuffless?","To reduce measurement friction and study whether PPG+ECG can support trend monitoring."),
  @("What is the unique contribution?","The integration: cuffless sensing, triage, caregiver alerts, medication hardware, and emergency calling."),
  @("Is it production-ready?","No. It is a graduation research prototype with a clear validation roadmap.")
)
Add-Table $s $rows 68 150 824 260 @(1.15,3.1)
Add-Footer $s 21
$slides += $s

# 22
$s = Add-Slide $pres "APPENDIX"
Add-Title $s "The BP model table is deliberately not cherry-picked." "The best deployed BP model was selected by measured performance."
Add-ImageContain $s (Join-Path $Assets "fig_23_bhs_best_model.png") 58 144 390 250 | Out-Null
Add-ImageContain $s (Join-Path $Assets "fig_22_error_distribution.png") 512 144 380 250 | Out-Null
Add-Text $s "Use this slide if asked about clinical evaluation curves, error bands, or why DBP and SBP are treated differently." 108 440 744 30 15 $C.Gray $false "center" | Out-Null
Add-Footer $s 22
$slides += $s

# 23
$s = Add-Slide $pres "APPENDIX"
Add-Title $s "Calibration exists in the backend, but the simulation result is not overclaimed." "This is a strong answer to a predictable technical question."
Add-ImageContain $s (Join-Path $Assets "fig_38_calibration_drift_flow.png") 86 132 230 320 | Out-Null
Add-Box $s 364 164 500 226 $C.White $C.Line 1 | Out-Null
Add-Bullets $s @("fewer than 8 paired samples use a robust median offset","8 or more samples upgrade to a constrained linear fit","drift is flagged after sustained shifts or stale calibration","the oracle simulation was inconclusive because its samples were not time-separated like real use") 398 198 430 128 15 | Out-Null
Add-Footer $s 23
$slides += $s

# 24
$s = Add-Slide $pres "APPENDIX"
Add-Title $s "The symptom checker is safer because prediction and urgency are separated." "Use this when asked whether the model can miss a red flag."
$rows = @(
  @("Layer","Owns","Can it lower urgency?"),
  @("Rule engine","red flags and vitals floor","No"),
  @("LightGBM model","top disease predictions","No"),
  @("LLM phrasing layer","wording only, optional","No"),
  @("Caregiver notification","high/critical escalation","No")
)
Add-Table $s $rows 110 158 740 230 @(1.1,2.1,1.1) $C.Navy $C.White
Add-Text $s "The model can help explain likely disease classes; it cannot suppress a rule-engine red flag." 140 430 680 28 18 $C.Ink $true "center" | Out-Null
Add-Footer $s 24
$slides += $s

# 25
$s = Add-Slide $pres "APPENDIX"
Add-Title $s "Sources used inside the deck" "Local project documentation is the primary evidence."
Add-Bullets $s @(
  "Docs/PRD.md, ARCHITECTURE.md, FRONTEND.md, BACKEND.md, DATABASE.md, IOT.md",
  "Docs/BP_PREDICTION.md and Docs/SYMPTOM_CHECKER.md for metrics and limitations",
  "assets/branding screenshots, diagrams, model figures, university and faculty logos",
  "Reference deck TAFANEEN .pptx.pdf for academic coverage pattern and comparison/table expectations",
  "Presentation research: Duarte/TED storytelling structure and Kawasaki 10/20/30 pacing guideline"
) 110 150 740 210 16 | Out-Null
Add-Footer $s 25
$slides += $s

# Animate most non-background objects.
foreach ($sl in $slides) {
  for ($i=1; $i -le $sl.Shapes.Count; $i++) {
    $sh = $sl.Shapes.Item($i)
    if ($sh.Type -ne 13 -or $i -le 2) {
      Animate-In $sl $sh ($i -le 3)
    }
  }
}

if (Test-Path $DeckPath) { Remove-Item -LiteralPath $DeckPath -Force }
$pres.SaveAs($DeckPath, $ppSaveAsOpenXMLPresentation)

# Export previews for visual QA.
Get-ChildItem -Path $PreviewDir -Filter "*.png" -ErrorAction SilentlyContinue | Remove-Item -Force
$pres.Export($PreviewDir, "PNG", 1280, 720)

$pres.Close()
$ppt.Quit()
[System.Runtime.InteropServices.Marshal]::ReleaseComObject($pres) | Out-Null
[System.Runtime.InteropServices.Marshal]::ReleaseComObject($ppt) | Out-Null

Write-Output $DeckPath
Write-Output $PreviewDir
