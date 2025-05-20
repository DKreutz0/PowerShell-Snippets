# Settings
$guiMode = $true # true of false: Use Gui OR Console
$inputSpeed = 50 #  typespeed in RDP session
$SecondsWaitBeforeTyping = 10 # ressponstime before start typing
$language = "en" #  Language: "en" of "nl" Dutch or English


# dont change anything after this line:

if ($language -ne "en" -and $language -ne "nl") {
    $language = "en" # 
}

$translations = @{
    "en" = @{
        "title" = "Clipboard Typing Simulator"
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
        "title" = "Klembord Typ Simulatie"
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

Function Get-Text($key) {
    return $translations[$language][$key]
}

Function Escape-SendKeysChar($char) {
    switch ($char) {
        "{" { return "{{}" }
        "}" { return "{}}" }
        "+" { return "{+}" }
        "^" { return "{^}" }
        "%" { return "{%}" }
        "~" { return "{~}" }
        "(" { return "{(}" }
        ")" { return "{)}" }
        default { return $char }
    }
}

Function CopyTo-RDPWindow {
    foreach ($char in $textToType.ToCharArray()) {
        switch ($char) {
            "`t" { [System.Windows.Forms.SendKeys]::SendWait("{TAB}") }
            "`n" { [System.Windows.Forms.SendKeys]::SendWait("~") }
            " "  { [System.Windows.Forms.SendKeys]::SendWait(" ") }
            default {
                $escaped = Escape-SendKeysChar $char
                [System.Windows.Forms.SendKeys]::SendWait($escaped)
            }
        }
    }
    Start-Sleep -Milliseconds $inputSpeed
}

Function Type-ClipBoard {

    [void]::([System.Reflection.Assembly]::LoadWithPartialName("Microsoft.VisualBasic"))
    [void]::([System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms"))

    if ($guiMode) {
        Add-Type -AssemblyName System.Windows.Forms
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
            $textToType = $txtInput.Text
            $textToType = $textToType -replace "`r`n", "`n"

            Start-Sleep -Seconds $SecondsWaitBeforeTyping
            Copyto-RDPWindow

            $result = [System.Windows.Forms.MessageBox]::Show(
                (New-Object system.windows.forms.form -Property @{Topmost = $true}),
                (Get-Text "moreTyping"),
                (Get-Text "doneTyping"),
                [System.Windows.Forms.MessageBoxButtons]::YesNo
            )

            if ($result -eq [System.Windows.Forms.DialogResult]::No) {
                [system.windows.forms.sendkeys]::Flush()
                $form.Close()
            } 
        })
                
        $form.Controls.Add($txtInput)
        $form.Controls.Add($btnSimulate)
        $form.ShowDialog((New-Object system.windows.forms.form -Property @{Topmost = $true}))
    }
    else {
        Write-Host (Get-Text "consoleWarning1").PadLeft(54).PadRight(105) -ForegroundColor red -BackgroundColor white
        Write-Host " " -BackgroundColor white -NoNewLine; Write-Host (Get-Text "consoleWarning2").PadRight(103) -NoNewLine; Write-Host " " -BackgroundColor white
        Write-Host " " -BackgroundColor white -NoNewLine; Write-Host (Get-Text "consoleWarning3").PadRight(103) -NoNewLine; Write-Host " " -BackgroundColor white
        Write-Host " " -BackgroundColor white -NoNewLine; Write-Host (Get-Text "consoleWarning4").PadRight(103) -NoNewLine; Write-Host " " -BackgroundColor white
        Write-Host " " -BackgroundColor white -NoNewLine; Write-Host (Get-Text "consoleWarning5").PadRight(103) -NoNewLine; Write-Host " " -BackgroundColor white
        Write-Host " " -BackgroundColor white -NoNewLine; Write-Host "".PadRight(103) -NoNewLine; Write-Host " " -BackgroundColor white
        Write-Host " " -BackgroundColor white -NoNewLine; Write-Host (Get-Text "consoleWarning6").PadRight(103) -NoNewLine; Write-Host " " -BackgroundColor white
        Write-Host " ".PadRight(105) -ForegroundColor red -BackgroundColor white
        Write-Host ""
        [void](Read-Host -Prompt (Get-Text "consoleContinue"))
    
        Start-Sleep $SecondsWaitBeforeTyping 
    
        $textToType = $([windows.forms.clipboard]::GetText())
        $textToType = $textToType -replace "`r`n", "`n"

        Copyto-RDPWindow
   
        Write-Host (Get-Text "done") -BackgroundColor green -ForegroundColor black
    }

    [system.windows.forms.sendkeys]::Flush()
}

Type-ClipBoard
