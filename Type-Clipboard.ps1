# Settings
$guiMode = $true # true of false: Use Gui OR Console
$inputSpeed = 50 #  typespeed in RDP session
$SecondsWaitBeforeTyping = 10 # ressponstime before start typing
$language = "en" #  Language: "en" of "nl" Dutch or English


# Do not change anything after this line:

Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction Stop
Add-Type -AssemblyName System.windows.forms -ErrorAction Stop

if ($language -ne "en" -and $language -ne "nl") {
    $language = "en" # 
}

$translations = @{
    "en" = @{
        "title" = "Clipboard RDPConsole Typer"
        "buttonType" = "Type Text"
        "doneTyping" = "Typing completed"
        "moreTyping" = "Would you like to type more?"
        "consoleWarning1" = "WARNING!"
        "consoleWarning2" = "If you want to type in an RDP session, make sure it is not fullscreen (Shift key won't work)."
        "consoleWarning3" = "You have $SecondsWaitBeforeTyping seconds to place your cursor in the correct window."
        "consoleWarning4" = "Do not close this window! Wait until the script is done."
        "consoleWarning5" = "Strange effects may occur if you don't click in time."
        "consoleWarning6" = "Using this script is at your own risk!"
        "consoleContinue" = "Press (ANY-KEY) to continue, or (ctrl)+(C) to cancel"
        "done" = " DONE! "
    }
    "nl" = @{
        "title" = "Klembord RDPConsole Typer"
        "buttonType" = "Typ Tekst"
        "doneTyping" = "Typen voltooid"
        "moreTyping" = "Wil je nog meer typen?"
        "consoleWarning1" = "LET OP!"
        "consoleWarning2" = "Als je in een RDP sessie wilt typen, zorg dan dat deze niet fullscreen is (Shift-toets werkt dan niet)."
        "consoleWarning3" = "Je hebt $SecondsWaitBeforeTyping seconden om je cursor te plaatsen in het venster waar je wilt typen."
        "consoleWarning4" = "Sluit dit venster niet! Wacht tot het script klaar is."
        "consoleWarning5" = "Als je te laat klikt, kunnen er vreemde effecten ontstaan."
        "consoleWarning6" = "Gebruik van dit script is op eigen risico!"
        "consoleContinue" = "Druk op een toets om door te gaan, of (ctrl)+(C) om te annuleren"
        "done" = " KLAAR! "
    }
}

Function Get-Text($Key) {
    return $translations[$language][$Key]
}

Function Escape-SendKeysChar($Char) {
    switch ($Char) {
        "{" { return "{{}" }
        "}" { return "{}}" }
        "+" { return "{+}" }
        "^" { return "{^}" }
        "%" { return "{%}" }
        "~" { return "{~}" }
        "(" { return "{(}" }
        ")" { return "{)}" }
        default { return $Char }
    }
}

Function CopyTo-RDPWindow {
    foreach ($Char in $TextToType.ToCharArray()) {
        switch ($Char) {
            "`t" { [System.Windows.Forms.SendKeys]::SendWait("{TAB}") }
            "`n" { [System.Windows.Forms.SendKeys]::SendWait("~") }
            " "  { [System.Windows.Forms.SendKeys]::SendWait(" ") }
            default {
                $escaped = Escape-SendKeysChar $Char
                [System.Windows.Forms.SendKeys]::SendWait($escaped)
            }
        }
    }
    Start-Sleep -Milliseconds $inputSpeed
}

Function Type-ClipBoard {

    if ($guiMode) {

        $form = New-Object System.Windows.Forms.Form
        $form.Text = Get-Text "title"
        $form.Size = New-Object System.Drawing.Size(400, 300)

        $txtInput = New-Object System.Windows.Forms.TextBox
        $txtInput.Multiline = $true
        $txtInput.ScrollBars = 'Vertical'
        $txtInput.Dock = 'Top'
        $txtInput.Height = 150

        $btnSimulate = New-Object System.Windows.Forms.Button
        $btnSimulate.Text = Get-Text "buttonType"
        $btnSimulate.Dock = 'Bottom'

        $txtInput.AppendText([windows.forms.clipboard]::GetText())

        $btnSimulate.Add_Click({
            $TextToType = $txtInput.Text
            $TextToType = $TextToType -replace "`r`n", "`n"

            Start-Sleep -Seconds $SecondsWaitBeforeTyping
            Copyto-RDPWindow

            $ResultMessageBox = [System.Windows.Forms.MessageBox]::Show(
                (New-Object system.windows.forms.form -Property @{Topmost = $true}),
                (Get-Text "moreTyping"),
                (Get-Text "doneTyping"),
                [System.Windows.Forms.MessageBoxButtons]::YesNo
            )

            if ($ResultMessageBox -eq [System.Windows.Forms.DialogResult]::No) {
                [system.windows.forms.sendkeys]::Flush()
                $form.Close()
            } 
        })
                
        $form.Controls.Add($txtInput)
        $form.Controls.Add($btnSimulate)
        $form.ShowDialog((New-Object system.windows.forms.form -Property @{Topmost = $true}))
    }
    else {
        Write-Host (Get-Text "consoleWarning1").PadLeft(54).PadRight(105) -ForegroundColor Red -BackgroundColor White
        Write-Host " " -BackgroundColor White -NoNewLine; Write-Host (Get-Text "consoleWarning2").PadRight(103) -NoNewLine; Write-Host " " -BackgroundColor White
        Write-Host " " -BackgroundColor White -NoNewLine; Write-Host (Get-Text "consoleWarning3").PadRight(103) -NoNewLine; Write-Host " " -BackgroundColor White
        Write-Host " " -BackgroundColor White -NoNewLine; Write-Host (Get-Text "consoleWarning4").PadRight(103) -NoNewLine; Write-Host " " -BackgroundColor White
        Write-Host " " -BackgroundColor White -NoNewLine; Write-Host (Get-Text "consoleWarning5").PadRight(103) -NoNewLine; Write-Host " " -BackgroundColor White
        Write-Host " " -BackgroundColor White -NoNewLine; Write-Host "".PadRight(103) -NoNewLine; Write-Host " " -BackgroundColor White
        Write-Host " " -BackgroundColor White -NoNewLine; Write-Host (Get-Text "consoleWarning6").PadRight(103) -NoNewLine; Write-Host " " -BackgroundColor White
        Write-Host " ".PadRight(105) -ForegroundColor Red -BackgroundColor White
        Write-Host ""
        [void](Read-Host -Prompt (Get-Text "consoleContinue"))
    
        Start-Sleep $SecondsWaitBeforeTyping 
    
        $TextToType = $([windows.forms.clipboard]::GetText())
        $TextToType = $TextToType -replace "`r`n", "`n"

        Copyto-RDPWindow
   
        Write-Host (Get-Text "done") -BackgroundColor Green -ForegroundColor black
    }
    [system.windows.forms.sendkeys]::Flush()
}
Type-ClipBoard
