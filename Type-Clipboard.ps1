$guiMode = $true # true or false vanuit de console of een dialogbox
$inputSpeed = 50 # typsnelheid in het RDP scherm
$SecondsWaitBeforeTyping = 10 # tijd tussen het drukken op de knop en alvorens het script begint

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
            "`n" { [System.Windows.Forms.SendKeys]::SendWait("~") }  # ENTER fix
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
   
    if ($guiMode) {
        Add-Type -AssemblyName System.Windows.Forms
        $form = New-Object System.Windows.Forms.Form
        $form.Text = "Clipboard Typing Simulator"
        $form.Size = New-Object System.Drawing.Size(400, 300)

        $txtInput = New-Object System.Windows.Forms.TextBox
        $txtInput.Multiline = $true
        $txtInput.ScrollBars = 'Vertical'
        $txtInput.Dock = 'Top'
        $txtInput.Height = 150

        $btnSimulate = New-Object System.Windows.Forms.Button
        $btnSimulate.Text = "Typ Tekst"
        $btnSimulate.Dock = 'Bottom'

        $txtInput.AppendText([windows.forms.clipboard]::GetText())

        $btnSimulate.Add_Click({
            $textToType = $txtInput.Text
            $textToType = $textToType -replace "`r`n", "`n"

            Start-Sleep -Seconds $SecondsWaitBeforeTyping
            Copyto-RDPWindow

            $result = [System.Windows.Forms.MessageBox]::Show("Wil je nog meer typen?", "Typen voltooid", [System.Windows.Forms.MessageBoxButtons]::YesNo)

            if ($result -eq [System.Windows.Forms.DialogResult]::No) {
                $form.Close()
                break
            }
        })
                
    $form.Controls.Add($txtInput)
    $form.Controls.Add($btnSimulate)
    $form.ShowDialog()
    }
    else {
        Write-Host "LET OP!".PadLeft(54).PadRight(105) -ForegroundColor red -BackgroundColor white
        Write-Host " " -BackgroundColor white -NoNewLine;Write-Host " Als je in een RDP sessie wilt type zorg dan dat deze niet FullScreen staat (Shift key werkt dan niet)".PadRight(103) -NoNewLine;Write-Host " " -BackgroundColor white;
        Write-Host " " -BackgroundColor white -NoNewLine;Write-Host " Als je doorgaat heb je $($SecondsWait) seconden om je cursor in het venster te plaatsen waar je wilt typen.".PadRight(103) -NoNewLine;Write-Host " " -BackgroundColor white;
        Write-Host " " -BackgroundColor white -NoNewLine;Write-Host " Klik niet weg! wacht tot het script klaar is".PadRight(103) -NoNewLine;Write-Host " " -BackgroundColor white;
        Write-Host " " -BackgroundColor white -NoNewLine;Write-Host " Doe je dit wel of klik je niet optijd in het juiste scherm kunnen er vreemde effecten ontstaan.".PadRight(103) -NoNewLine;Write-Host " " -BackgroundColor white;
        Write-Host " " -BackgroundColor white -NoNewLine;Write-Host "".PadRight(103) -NoNewLine;Write-Host " " -BackgroundColor white;
        Write-Host " " -BackgroundColor white -NoNewLine;Write-Host " Het gebruikt van dit script is dan ook op eigen risico!!".PadRight(103) -NoNewLine;Write-Host " " -BackgroundColor white;
        Write-Host " ".PadRight(105) -ForegroundColor red -BackgroundColor white
        Write-Host ""
        [void]::(Read-Host -Prompt "Press (ANY-KEY) to continue, or (ctrl)+(C) to cancel")
    
        Start-Sleep $SecondsWaitBeforeTyping 
    
        [void]::([System.Reflection.Assembly]::LoadWithPartialName("Microsoft.VisualBasic"))
        [void]::([System.Reflection.Assembly]::LoadWithPartialName("system.windows.forms"))

        $textToType = $([windows.forms.clipboard]::GetText())
        $textToType = $textToType -replace "`r`n", "`n"

        Copyto-RDPWindow
   
        Write-Host " DONE! " -BackgroundColor green -ForegroundColor black
    }
    
    [system.windows.forms.sendkeys]::Flush()
}
Type-ClipBoard
