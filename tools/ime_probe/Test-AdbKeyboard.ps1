param(
    [string]$Adb = "$PSScriptRoot/../../bin/adb.exe",
    [string]$Serial = 'bc4cd33a'
)
$ErrorActionPreference = 'Stop'
function Invoke-Adb([string[]]$Arguments) {
    $output = & $Adb -s $Serial @Arguments
    if ($LASTEXITCODE -ne 0) { throw "ADB failed: $($Arguments[0])" }
    return ($output | Out-String).Trim()
}
function Send-Broadcast([string[]]$Extras) {
    Invoke-Adb (@('shell', 'am', 'broadcast', '-p', 'com.android.adbkeyboard') + $Extras) | Out-Null
}
function Read-Sample {
    for ($attempt = 0; $attempt -lt 8; $attempt++) {
        $dump = Invoke-Adb @('shell', 'uiautomator', 'dump', '/data/local/tmp/ja-ime-test.xml')
        if ($dump -notmatch 'UI hierchary dumped') {
            Start-Sleep -Milliseconds 400
            continue
        }
        [xml]$tree = Invoke-Adb @('shell', 'cat', '/data/local/tmp/ja-ime-test.xml')
        $node = $tree.SelectSingleNode('//node[@resource-id="android:id/search_src_text" and @package="com.android.settings.intelligence" and @password="false"]')
        if ($null -ne $node) { return $node.text }
    }
    throw 'Expected non-password Settings search editor not found; refusing to continue.'
}
function Assert-Sample([string]$Expected, [string]$Label) {
    $actual = Read-Sample
    if ($actual -cne $Expected) { throw "$Label FAIL: actual=$actual expected=$Expected" }
    Write-Output "$Label PASS: $actual"
}
function Send-Text([string]$Value) {
    $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Value))
    Send-Broadcast @('-a', 'ADB_INPUT_B64', '--es', 'msg', $b64)
}
$originalIme = Invoke-Adb @('shell', 'settings', 'get', 'secure', 'default_input_method')
$originalEnabled = Invoke-Adb @('shell', 'settings', 'get', 'secure', 'enabled_input_methods')
if ($originalIme -ne 'com.android.inputmethod.latin/.LatinIME') {
    throw 'Expected LatinIME before trial; restore it or inspect current state first.'
}
if ((Read-Sample) -notin @('Search…', 'Xin chào Việt Nam 12')) {
    throw 'Settings search must be empty before trial; refusing to clear existing text.'
}
try {
    Invoke-Adb @('shell', 'ime', 'enable', 'com.android.adbkeyboard/.AdbIME') | Out-Null
    Invoke-Adb @('shell', 'ime', 'set', 'com.android.adbkeyboard/.AdbIME') | Out-Null
    Send-Broadcast @('-a', 'ADB_CLEAR_TEXT')
    Send-Text 'JA English 123'
    Assert-Sample 'JA English 123' 'English'
    Send-Broadcast @('-a', 'ADB_CLEAR_TEXT')
    Send-Text 'Xin chào Việt Nam 123'
    Assert-Sample 'Xin chào Việt Nam 123' 'Vietnamese UTF-8'
    Send-Broadcast @('-a', 'ADB_INPUT_CODE', '--ei', 'code', '67')
    Assert-Sample 'Xin chào Việt Nam 12' 'Backspace'
    Send-Text '😀'
    Assert-Sample 'Xin chào Việt Nam 12😀' 'Emoji UTF-8'
    Send-Broadcast @('-a', 'ADB_INPUT_CODE', '--ei', 'code', '67')
    Assert-Sample 'Xin chào Việt Nam 12' 'Backspace emoji'
    Send-Broadcast @('-a', 'ADB_EDITOR_CODE', '--ei', 'code', '3')
    Start-Sleep -Milliseconds 500
    $imeState = Invoke-Adb @('shell', 'dumpsys', 'input_method')
    if ($imeState -notmatch 'mInputShown=false') { throw 'Editor SEARCH did not dismiss IME; outcome not confirmed.' }
    Assert-Sample 'Xin chào Việt Nam 12' 'Editor SEARCH retained query and hid IME'
} finally {
    Invoke-Adb @('shell', 'ime', 'set', $originalIme) | Out-Null
    if ($originalEnabled -notmatch 'com.android.adbkeyboard') {
        Invoke-Adb @('shell', 'ime', 'disable', 'com.android.adbkeyboard/.AdbIME') | Out-Null
    }
    $restored = Invoke-Adb @('shell', 'settings', 'get', 'secure', 'default_input_method')
    $restoredEnabled = Invoke-Adb @('shell', 'settings', 'get', 'secure', 'enabled_input_methods')
    if ($restored -ne $originalIme -or $restoredEnabled -ne $originalEnabled) { throw 'IME restoration mismatch: manual inspection required.' }
    Write-Output 'RESTORED: LatinIME and original enabled IMEs'
}
