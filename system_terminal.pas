unit System_Terminal;

{$mode objfpc}{$H+}

//***********************************************************************
//** unit System_Terminal                                              **
//**                                                                   **
//** Mein Dank gilt an dieser Stelle Ronald Daleske.                   **
//** http://www.projekte.daleske.de/                                   **
//** Projekt: Z80EMU                                                   **
//**                                                                   **
//** Die von Ronald Daleske geschriebene Terminalemulation diente      **
//** mir als Vorlage und Code-Basis für die Vorliegende Terminal Unit. **
//** Vielen Dank für die freundliche Unterstützung.                    **
//** Uwe Merker Juni 2020                                              **
//***********************************************************************

interface

uses
    Classes, SysUtils, Controls, ExtCtrls, Graphics;

type

    { TSystemTerminal }

    TSystemTerminal = class

    private   // Attribute

        type
        TTermMode = (STANDARD, VT52_ESC, ANSI_ESC, ANSI_ESC_1PAR, ANSI_ESC_2PAR, DCA_ROW, DCA_COLUMN);

    const
        terminalColumns = 80;
        terminalRows = 24;
        {$ifdef Windows}
        charHeight = 22;
        charWidth = 10;
        {$else}
        charHeight = 22;
        charWidth = 11;
        {$endif}
        startLeft = -6;
        startTop = -18;

    var
        newCharAvailable: boolean;
        imagePage1, imagePage2: TImage;
        timerTerminalPageRefresh: TTimer;
        timerCursorFlash: TTimer;
        charData: array[1..terminalRows, 1..terminalColumns] of char;
        charStyle: array[1..terminalRows, 1..terminalColumns] of TFontStyles;
        charColor: array[1..terminalRows, 1..terminalColumns] of TColor;
        backColor: array[1..terminalRows, 1..terminalColumns] of TColor;
        terminalCursor: record
            column: integer;
            row: integer;
            cursorChar: char;
            Visible: boolean;
        end;
        keyboardBuffer: string;
        enableCrLf: boolean;
        enableLocalEcho: boolean;
        enableTerminalLogging: boolean;
        loggingFile: file of char;
        fontColor, tmpFontColor, backgroundColor: TColor;
        fontStyle: TFontStyles;
        termMode: TTermMode;
        csiPar1, csiPar2, dcaRow: integer;

    protected // Attribute
        procedure timerCursorFlashTimer(Sender: TObject);
        procedure timerTerminalPageRefreshTimer(Sender: TObject);

    public    // Attribute

    public  // Konstruktor/Destruktor
        constructor Create(terminalPanel: TPanel); overload;
        destructor Destroy; override;

    private   // Methoden
        procedure writeCharOnScreen(character: char);
        procedure scrollTerminalContentUp;
        procedure cursorHome;
        procedure cursorLeft;
        procedure cursorRight;
        procedure cursorUp;
        procedure cursorDown;
        procedure backspace;
        procedure setTabulator;
        procedure lineFeed;
        procedure clearScreen;
        procedure eraseScreen;
        procedure carriageReturn;
        procedure deleteEndOfLine;
        procedure deleteEndOfScreen;
        procedure deleteBeginningOfLine;
        procedure deleteBeginningOfScreen;
        procedure deleteLine;
        procedure deleteLineAndScroll;
        procedure insertLineAndScroll;
        procedure reverseLineFeed;
        procedure setCursorPosition(row, column: integer);

    protected // Methoden

    public    // Methoden
        procedure terminalReset;
        procedure setCrLF(enable: boolean);
        procedure setLocalEcho(enable: boolean);
        procedure setTerminalLogging(enable: boolean);
        procedure writeCharacter(character: byte);
        function readCharacter(getStatus: boolean): byte;
        procedure getKeyBoardInput(key: word; shift: TShiftState);

    end;

var
    SystemTerminal: TSystemTerminal;

implementation

{ TSystemTerminal }

// --------------------------------------------------------------------------------
procedure TSystemTerminal.timerCursorFlashTimer(Sender: TObject);
begin
    timerCursorFlash.Enabled := False;
    if (terminalCursor.Visible) then begin
        terminalCursor.Visible := False;
    end
    else begin
        terminalCursor.Visible := True;
    end;
    timerCursorFlash.Enabled := True;
end;

// --------------------------------------------------------------------------------
procedure TSystemTerminal.timerTerminalPageRefreshTimer(Sender: TObject);
var
    row, column, posX, posY: integer;
    viewChar: char;
begin
    timerTerminalPageRefresh.Enabled := False;
    for row := 1 to terminalRows do begin
        posY := startTop + (charHeight * row);
        for column := 1 to terminalColumns do begin
            if (terminalCursor.Visible and (row = terminalCursor.row) and (column = terminalCursor.column)) then begin
                viewchar := terminalCursor.cursorChar;
            end
            else begin
                viewchar := charData[row, column];
            end;
            {$ifdef Windows}
            posX := startLeft + ((charWidth + 2) * column);
            {$else}
            posX := startLeft + (charWidth * column);
            {$endif}
            if (imagePage1.Visible) then begin
                imagePage2.Canvas.Brush.Color := backColor[row, column];
                imagePage2.Canvas.Font.Color := charColor[row, column];
                imagePage2.Canvas.Font.Style := charStyle[row, column];
                {$ifdef Windows}
                imagePage2.Canvas.Rectangle(posX - 2, posY, posX + charWidth + 1, posY + charHeight);
                {$else}
                imagePage2.Canvas.Rectangle(posX - 1, posY, posX + charWidth + 1, posY + charHeight);
                {$endif}
                imagePage2.Canvas.TextOut(posX, posY, viewChar);
            end
            else begin
                imagePage1.Canvas.Brush.Color := backColor[row, column];
                imagePage1.Canvas.Font.Color := charColor[row, column];
                imagePage1.Canvas.Font.Style := charStyle[row, column];
                 {$ifdef Windows}
                imagePage1.Canvas.Rectangle(posX - 2, posY, posX + charWidth + 1, posY + charHeight);
                {$else}
                imagePage1.Canvas.Rectangle(posX - 1, posY, posX + charWidth + 1, posY + charHeight);
                {$endif}
                imagePage1.Canvas.TextOut(posX, posY, viewChar);
            end;
        end;
    end;
    imagePage1.Visible := imagePage2.Visible;
    imagePage2.Visible := not imagePage1.Visible;
    timerTerminalPageRefresh.Enabled := True;
end;

// --------------------------------------------------------------------------------
constructor TSystemTerminal.Create(terminalPanel: TPanel);
var
    pageWidth, pageHeight: integer;
begin
    {$ifdef Windows}
    terminalPanel.Font.Name := 'Consolas';
    terminalPanel.Font.Size := 12;
    pageWidth := ((charWidth + 2) * terminalColumns) + charWidth;
    {$else}
    terminalPanel.Font.Name := 'Courier New';
    terminalPanel.Font.Size := 12;
    pageWidth := (charWidth * terminalColumns) + charWidth;
    {$endif}
    terminalPanel.Font.Color := clBlack;
    pageHeight := (charHeight * terminalRows) + charHeight;

    imagePage1 := TImage.Create(terminalPanel);
    imagePage1.Parent := terminalPanel;
    with (imagePage1) do begin
        Top := 0;
        Left := 0;
        Width := pageWidth;
        Height := pageHeight;
        Canvas.Brush.Color := clWhite;
        Canvas.Pen.Color := clWhite;
        Canvas.Font := terminalPanel.Font;
        Canvas.Rectangle(0, 0, imagePage1.Width, imagePage1.Height);
    end;

    imagePage2 := TImage.Create(terminalPanel);
    imagePage2.Parent := terminalPanel;
    with (imagePage2) do begin
        Top := 0;
        Left := 0;
        Width := pageWidth;
        Height := pageHeight;
        Canvas.Brush.Color := clWhite;
        Canvas.Pen.Color := clWhite;
        Canvas.Font := terminalPanel.Font;
        Canvas.Rectangle(0, 0, imagePage2.Width, imagePage2.Height);
    end;

    timerCursorFlash := TTimer.Create(terminalPanel);
    timerCursorFlash.Interval := 600;
    timerCursorFlash.OnTimer := @timerCursorFlashTimer;
    timerCursorFlash.Enabled := False;

    timerTerminalPageRefresh := TTimer.Create(terminalPanel);
    timerTerminalPageRefresh.Interval := 50;
    timerTerminalPageRefresh.OnTimer := @timerTerminalPageRefreshTimer;
    timerTerminalPageRefresh.Enabled := False;

    newCharAvailable := False;
    enableCrLf := False;
    enableLocalEcho := False;
    setTerminalLogging(False);
    terminalReset;
end;
// --------------------------------------------------------------------------------
destructor TSystemTerminal.Destroy;
begin
    timerCursorFlash.Enabled := False;
    timerCursorFlash.OnTimer := nil;
    timerTerminalPageRefresh.Enabled := False;
    timerTerminalPageRefresh.OnTimer := nil;
    if (enableTerminalLogging) then begin
        CloseFile(loggingFile);
    end;
    inherited Destroy;
end;

// --------------------------------------------------------------------------------
procedure TSystemTerminal.terminalReset;
var
    row, column: integer;
begin
    for row := 1 to terminalRows do begin
        for column := 1 to terminalColumns do begin
            charData[row, column] := ' ';
            charColor[row, column] := clBlack;
            backColor[row, column] := clWhite;
            charStyle[row, column] := [];
        end;
    end;
    terminalCursor.column := 1;
    terminalCursor.row := 1;
    terminalCursor.cursorChar := '_';
    terminalCursor.Visible := True;
    imagePage1.Visible := True;
    imagePage2.Visible := False;
    timerCursorFlash.Enabled := True;
    timerTerminalPageRefresh.Enabled := True;
    fontStyle := [];
    fontColor := clBlack;
    backgroundColor := clWhite;
    termMode := STANDARD;
    keyboardBuffer := '';
end;

// --------------------------------------------------------------------------------
procedure TSystemTerminal.writeCharOnScreen(character: char);
begin
    charData[terminalCursor.row, terminalCursor.column] := character;
    charColor[terminalCursor.row, terminalCursor.column] := fontColor;
    backColor[terminalCursor.row, terminalCursor.column] := backgroundColor;
    charStyle[terminalCursor.row, terminalCursor.column] := fontStyle;
    Inc(terminalCursor.column);
    if (terminalCursor.column > terminalColumns) then begin
        terminalCursor.column := 1;
        Inc(terminalCursor.row);
        if (terminalCursor.row > terminalRows) then begin
            scrollTerminalContentUp;
        end;
    end;
end;
// --------------------------------------------------------------------------------
procedure TSystemTerminal.scrollTerminalContentUp;
var
    column, row: integer;
begin
    for row := 1 to terminalRows - 1 do begin
        charData[row] := charData[row + 1];
        charColor[row] := charColor[row + 1];
        charStyle[row] := charStyle[row + 1];
    end;
    for column := 1 to terminalColumns do begin
        charData[terminalRows, column] := ' ';
        charColor[terminalRows, column] := clBlack;
        charStyle[terminalRows, column] := [];
    end;
    terminalCursor.column := 1;
    terminalCursor.row := terminalRows;
end;

// --------------------------------------------------------------------------------
procedure TSystemTerminal.cursorHome;
begin
    terminalCursor.column := 1;
    terminalCursor.row := 1;
end;

// --------------------------------------------------------------------------------
procedure TSystemTerminal.cursorLeft;
begin
    if (terminalCursor.column > 1) then begin
        Dec(terminalCursor.column);
    end;
end;

// --------------------------------------------------------------------------------
procedure TSystemTerminal.cursorRight;
begin
    if (terminalCursor.column < terminalColumns) then begin
        Inc(terminalCursor.column);
    end;
end;

// --------------------------------------------------------------------------------
procedure TSystemTerminal.cursorUp;
begin
    if (terminalCursor.row > 1) then begin
        Dec(terminalCursor.row);
    end;
end;

// --------------------------------------------------------------------------------
procedure TSystemTerminal.cursorDown;
begin
    if (terminalCursor.row < terminalRows) then begin
        Inc(terminalCursor.row);
    end;
end;

// --------------------------------------------------------------------------------
procedure TSystemTerminal.backspace;
begin
    if (terminalCursor.column > 1) then begin
        Dec(terminalCursor.column);
        charData[terminalCursor.row, terminalCursor.column] := ' ';
        charColor[terminalCursor.row, terminalCursor.column] := clBlack;
        charStyle[terminalCursor.row, terminalCursor.column] := [];
    end;
end;

// --------------------------------------------------------------------------------
procedure TSystemTerminal.setTabulator;
begin
    terminalCursor.column := (8 * ((terminalCursor.column div 8) + 1));
    if (terminalCursor.column > terminalColumns) then begin
        terminalCursor.column := 1;
    end;
end;

// --------------------------------------------------------------------------------
procedure TSystemTerminal.lineFeed;
begin
    Inc(terminalCursor.row);
    if (terminalCursor.row > terminalRows) then begin
        scrollTerminalContentUp;
    end;
end;

// --------------------------------------------------------------------------------
procedure TSystemTerminal.clearScreen;
var
    row, column: integer;
begin
    for row := 1 to terminalRows do begin
        for column := 1 to terminalColumns do begin
            charData[row, column] := ' ';
            charColor[row, column] := clBlack;
            charStyle[row, column] := [];
        end;
    end;
    terminalCursor.column := 1;
    terminalCursor.row := 1;
    csiPar1 := 0;
    csiPar2 := 0;
    dcaRow := 0;
end;

// --------------------------------------------------------------------------------
procedure TSystemTerminal.eraseScreen;
var
    row, column: integer;
begin
    for row := 1 to terminalRows do begin
        for column := 1 to terminalColumns do begin
            charData[row, column] := ' ';
            charColor[row, column] := clBlack;
            charStyle[row, column] := [];
        end;
    end;
end;

// --------------------------------------------------------------------------------
procedure TSystemTerminal.carriageReturn;
begin
    terminalCursor.column := 1;
end;

// --------------------------------------------------------------------------------
procedure TSystemTerminal.deleteEndOfLine;
var
    column: integer;
begin
    for column := terminalCursor.column to terminalColumns do begin
        charData[terminalCursor.row, column] := ' ';
        charColor[terminalCursor.row, column] := clBlack;
        charStyle[terminalCursor.row, column] := [];
    end;
end;

// --------------------------------------------------------------------------------
procedure TSystemTerminal.deleteEndOfScreen;
var
    row, column: integer;
begin
    deleteEndOfLine;
    if terminalCursor.row < terminalRows then begin
        for row := terminalCursor.row + 1 to terminalRows do begin
            for column := 1 to terminalColumns do begin
                charData[row, column] := ' ';
                charColor[row, column] := clBlack;
                charStyle[row, column] := [];
            end;
        end;
    end;
end;

// --------------------------------------------------------------------------------
procedure TSystemTerminal.deleteBeginningOfLine;
var
    column: integer;
begin
    for column := 1 to terminalCursor.column - 1 do begin
        charData[terminalCursor.row, column] := ' ';
        charColor[terminalCursor.row, column] := clBlack;
        charStyle[terminalCursor.row, column] := [];
    end;
end;

// --------------------------------------------------------------------------------
procedure TSystemTerminal.deleteBeginningOfScreen;
var
    row, column: integer;
begin
    deleteBeginningOfLine;
    if terminalCursor.row > 1 then begin
        for row := 1 to terminalCursor.row - 1 do begin
            for column := 1 to terminalColumns do begin
                charData[row, column] := ' ';
                charColor[row, column] := clBlack;
                charStyle[row, column] := [];
            end;
        end;
    end;
end;

// --------------------------------------------------------------------------------
procedure TSystemTerminal.deleteLine;
var
    column: integer;
begin
    for column := 1 to terminalColumns do begin
        charData[terminalCursor.row, column] := ' ';
        charColor[terminalCursor.row, column] := clBlack;
        charStyle[terminalCursor.row, column] := [];
    end;
    terminalCursor.column := 1;
end;

// --------------------------------------------------------------------------------
procedure TSystemTerminal.deleteLineAndScroll;
var
    column, row: integer;
begin
    for row := terminalCursor.row to terminalRows - 1 do begin
        charData[row] := charData[row + 1];
        charColor[row] := charColor[row + 1];
        charStyle[row] := charStyle[row + 1];
    end;
    for column := 1 to terminalColumns do begin
        charData[terminalRows, column] := ' ';
        charColor[terminalRows, column] := clBlack;
        charStyle[terminalRows, column] := [];
    end;
    terminalCursor.column := 1;
end;

// --------------------------------------------------------------------------------
procedure TSystemTerminal.insertLineAndScroll;
var
    column, row: integer;
begin
    for row := terminalRows downto terminalCursor.row + 1 do begin
        charData[row] := charData[row - 1];
        charColor[row] := charColor[row - 1];
        charStyle[row] := charStyle[row - 1];
    end;
    for column := 1 to terminalColumns do begin
        charData[terminalCursor.row, column] := ' ';
        charColor[terminalCursor.row, column] := clBlack;
        charStyle[terminalCursor.row, column] := [];
    end;
end;

// --------------------------------------------------------------------------------
procedure TSystemTerminal.reverseLineFeed;
begin
    if (terminalCursor.row > 1) then begin
        Dec(terminalCursor.row);
    end
    else begin
        insertLineAndScroll;
    end;
end;

// --------------------------------------------------------------------------------
procedure TSystemTerminal.setCursorPosition(row, column: integer);
begin
    terminalCursor.row := row;
    terminalCursor.column := column;
    if (terminalCursor.row > terminalRows) then begin
        terminalCursor.row := terminalRows;
    end;
    if (terminalCursor.row < 1) then begin
        terminalCursor.row := 1;
    end;
    if (terminalCursor.column > terminalColumns) then begin
        terminalCursor.column := terminalColumns;
    end;
    if (terminalCursor.column < 1) then begin
        terminalCursor.column := 1;
    end;
end;

// --------------------------------------------------------------------------------
procedure TSystemTerminal.setCrLF(enable: boolean);
begin
    enableCrLf := enable;
end;

// --------------------------------------------------------------------------------
procedure TSystemTerminal.setLocalEcho(enable: boolean);
begin
    enableLocalEcho := enable;
end;

// --------------------------------------------------------------------------------
procedure TSystemTerminal.setTerminalLogging(enable: boolean);
begin
    enableTerminalLogging := enable;
    if (enableTerminalLogging) then begin
        try
            Assign(loggingFile, 'Terminal.log');
            Rewrite(loggingFile);
        except
            enableTerminalLogging := False;
        end;
    end;
end;

// --------------------------------------------------------------------------------
procedure TSystemTerminal.writeCharacter(character: byte);

// ----------------------------------------
    procedure normalTerminalMode;
    begin
        case (character) of
            $01: begin
                cursorHome;
            end;
            $04: begin
                cursorRight;
            end;
            $05: begin
                cursorUp;
            end;
            $07: begin
                // bell;
            end;
            $08: begin
                backspace;
            end;
            $09: begin
                setTabulator;
            end;
            $0A: begin
                lineFeed;
            end;
            $0C: begin
                clearScreen;
            end;
            $0D: begin
                carriageReturn;
                if (enableCrLf) then begin
                    lineFeed;
                end;
            end;
            $13: begin
                cursorLeft;
            end;
            $16: begin
                deleteEndOfLine;
            end;
            $18: begin
                cursorDown;
            end;
            $1B: begin
                termMode := VT52_ESC;
            end;
            $20..$7E: begin
                writeCharOnScreen(chr(character));
            end;
            $7F: begin
                backspace;
            end;
        end;
    end;

    // ----------------------------------------
    procedure vt52EscapeMode;
    begin
        case (character) of
            $3C: begin  // ESC < (Enter ANSI Mode)
                // ANSI-Mode ist immer aktiv.
            end;
            $41: begin  // ESC A (Cursor up)
                cursorUp;
                termMode := STANDARD;
            end;
            $42: begin  // ESC B (Cursor down)
                cursorDown;
                termMode := STANDARD;
            end;
            $43: begin  // ESC C (Cursor right)
                cursorRight;
                termMode := STANDARD;
            end;
            $44: begin  // ESC D (Cursor left)
                cursorLeft;
                termMode := STANDARD;
            end;
            $48: begin  // ESC H (Cursor home)
                cursorHome;
                termMode := STANDARD;
            end;
            $49: begin  // ESC I (Reverse line feed)
                reverseLineFeed;
                termMode := STANDARD;
            end;
            $4A: begin  // ESC J (Erase to end of Screen)
                deleteEndOfScreen;
                termMode := STANDARD;
            end;
            $4B: begin  // ESC K (Erase to end of Line)
                deleteEndOfLine;
                termMode := STANDARD;
            end;
            $4C: begin  // ESC L (Insert line)
                insertLineAndScroll;
                termMode := STANDARD;
            end;
            $4D: begin  // ESC M (Remove Line)
                deleteLineAndScroll;
                termMode := STANDARD;
            end;
            $59: begin  // ESC Y (Direct Cursor address)
                termMode := DCA_ROW;
            end;
            $5A: begin  // ESC Z (Identify VT52 Mode)
                keyboardBuffer := keyboardBuffer + char($1B) + char($2F) + char($5A);
                termMode := STANDARD;
            end;
            $5B: begin  // ESC [ (VT52_ESC Control Sequenz)
                termMode := ANSI_ESC;
            end;
            else termMode := STANDARD;
        end;
    end;

    // ----------------------------------------
    procedure ansiEscapeMode;
    begin
        case (character) of
            $30..$39: begin
                csiPar1 := character - $30;
                termMode := ANSI_ESC_1PAR;
            end;
            $41: begin  // ESC [ A (Cursor up one line)
                cursorUp;
                termMode := STANDARD;
            end;
            $42: begin  // ESC [ B (Cursor down one line)
                cursorDown;
                termMode := STANDARD;
            end;
            $43: begin  // ESC [ C (Cursor right one column)
                cursorRight;
                termMode := STANDARD;
            end;
            $44: begin  // ESC [ D (Cursor left one column)
                cursorLeft;
                termMode := STANDARD;
            end;
            $48: begin  // ESC [ H (Cursor home)
                cursorHome;
                csiPar1 := 0;
                termMode := STANDARD;
            end;
            $4A: begin  // ESC [ J (Erase Screen from cursor to end)
                deleteEndOfScreen;
                csiPar1 := 0;
                termMode := STANDARD;
            end;
            $4B: begin  // ESC [ K (Erase line from cursor to end)
                deleteEndOfLine;
                csiPar1 := 0;
                termMode := STANDARD;
            end;
            $4C: begin  // ESC [ L (Insert one line from cursor position)
                insertLineAndScroll;
                csiPar1 := 0;
                termMode := STANDARD;
            end;
            $4D: begin  // ESC [ M (Delete one line from cursor position)
                deleteLineAndScroll;
                csiPar1 := 0;
                termMode := STANDARD;
            end;
            $6D: begin  // ESC [ m (Clear all character attributes)
                fontStyle := [];
                fontColor := clBlack;
                backgroundColor := clWhite;
                csiPar1 := 0;
                termMode := STANDARD;
            end;
            $66: begin  // ESC [ f (Cursor home)
                cursorHome;
                csiPar1 := 0;
                termMode := STANDARD;
            end;
            else begin
                termMode := STANDARD;
            end;
        end;
    end;

    // ----------------------------------------
    procedure ansiEscapeMode1Parameter;
    var
        csiCounter: integer;
    begin
        case (character) of
            $30..$39: begin
                csiPar1 := (csiPar1 * 10) + character - $30;
                termMode := ANSI_ESC_1PAR;
            end;
            $3B: begin // ESC [ Pn1 ; (zweiten Parameter abfragen)
                termMode := ANSI_ESC_2PAR;
            end;

            $41: begin // ESC [ Pn A (Cursor up Pn lines)
                if terminalCursor.row > csiPar1 then begin
                    terminalCursor.row := terminalCursor.row - csiPar1;
                end
                else begin
                    terminalCursor.row := 1;
                end;
                csiPar1 := 0;
                termMode := STANDARD;
            end;
            $42: begin // ESC [ Pn B (Cursor down Pn lines)
                if (terminalCursor.row + csiPar1) < terminalRows then begin
                    terminalCursor.row := terminalCursor.row + csiPar1;
                end
                else begin
                    terminalCursor.row := terminalRows;
                end;
                csiPar1 := 0;
                termMode := STANDARD;
            end;
            $43: begin // ESC [ Pn C (Cursor right Pn columns)
                if (terminalCursor.column + csiPar1) < terminalColumns then begin
                    terminalCursor.column := terminalCursor.column + csiPar1;
                end
                else begin
                    terminalCursor.column := terminalColumns;
                end;
                csiPar1 := 0;
                termMode := STANDARD;
            end;
            $44: begin // ESC [ Pn D (Cursor left Pn columns)
                if terminalCursor.column > csiPar1 then begin
                    terminalCursor.column := terminalCursor.column - csiPar1;
                end
                else begin
                    terminalCursor.column := 1;
                end;
                csiPar1 := 0;
                termMode := STANDARD;
            end;
            $4B: begin // ESC [ Pn K
                case csiPar1 of
                    0: deleteEndOfLine;  // Erase line from cursor to end
                    1: deleteBeginningOfLine;  // Erase from beginning of line to cursor
                    2: deleteLine;  // Erase entire line but do not move cursor
                end;
                csiPar1 := 0;
                termMode := STANDARD;
            end;
            $4A: begin // ESC [ Pn J
                case csiPar1 of
                    0: deleteEndOfScreen;  // Erase screen from cursor to end
                    1: deleteBeginningOfScreen;  // Erase beginning of screen to cursor
                    2: eraseScreen;  // Erase entire screenbut do not move cursor
                end;
                csiPar1 := 0;
                termMode := STANDARD;
            end;
            $4C: begin // ESC [ Pn L (Insert Pn lines from cursor position)
                for csiCounter := 0 to csiPar1 - 1 do begin
                    insertLineAndScroll;
                end;
                csiPar1 := 0;
                termMode := STANDARD;
            end;
            $4D: begin // ESC [ Pn M (Delete Pn lines from cursor position)
                for csiCounter := 0 to csiPar1 - 1 do begin
                    deleteLineAndScroll;
                end;
                csiPar1 := 0;
                termMode := STANDARD;
            end;
            $6D: begin // ESC [ Pn m
                case csiPar1 of
                    0: begin
                        fontStyle := [];
                        fontColor := clBlack;
                        backgroundColor := clWhite;
                    end;
                    1: begin
                        fontStyle := fontStyle + [fsBold];
                    end;
                    4: begin
                        fontStyle := fontStyle + [fsUnderline];
                    end;
                    5: begin
                        fontStyle := fontStyle + [fsItalic];
                    end;
                    7: begin
                        fontStyle := fontStyle + [fsBold];
                        tmpFontColor:=fontColor;
                        fontColor := clGray;
                    end;
                    22: begin
                        fontStyle := fontStyle - [fsBold];
                    end;
                    24: begin
                        fontStyle := fontStyle - [fsUnderline];
                    end;
                    25: begin
                        fontStyle := fontStyle - [fsItalic];
                    end;
                    27: begin
                        fontStyle := fontStyle - [fsBold];
                        fontColor := tmpFontColor;
                    end;
                    30: begin
                        fontColor := clBlack;
                    end;
                    31: begin
                        fontColor := clRed;
                    end;
                    32: begin
                        fontColor := clLime;
                    end;
                    33: begin
                        fontColor := clYellow;
                    end;
                    34: begin
                        fontColor := clBlue;
                    end;
                    35: begin
                        fontColor := $FF00FF;
                    end;
                    36: begin
                        fontColor := $00FFFF;
                    end;
                    37: begin
                        fontColor := clWhite;
                    end;
                    40: begin
                        backgroundColor := clBlack;
                    end;
                    41: begin
                        backgroundColor := clRed;
                    end;
                    42: begin
                        backgroundColor := clLime;
                    end;
                    43: begin
                        backgroundColor := clYellow;
                    end;
                    44: begin
                        backgroundColor := clBlue;
                    end;
                    45: begin
                        backgroundColor := $FF00FF;
                    end;
                    46: begin
                        backgroundColor := $00FFFF;
                    end;
                    47: begin
                        backgroundColor := clWhite;
                    end;
                end;
                csiPar1 := 0;
                termMode := STANDARD;
            end;
            else begin
                csiPar1 := 0;
                termMode := STANDARD;
            end;
        end;
    end;

    // ----------------------------------------
    procedure ansiEscapeMode2Parameter;
    begin
        case (character) of
            $30..$39: begin
                csiPar2 := (csiPar2 * 10) + character - $30;
                termMode := ANSI_ESC_2PAR;
            end;
            $48, $66: begin // ESC [ Pn1 ; Pn2 H , ESC [ Pn1 ; Pn2 f (Move cursor to line Pn1 and column Pn2)
                setCursorPosition(csiPar1, csiPar2);
                csiPar1 := 0;
                csiPar2 := 0;
                termMode := STANDARD;
            end;
            else begin
                csiPar1 := 0;
                csiPar2 := 0;
                termMode := STANDARD;
            end;
        end;
    end;

    // ----------------------------------------
begin
    case termMode of
        STANDARD: normalTerminalMode;
        VT52_ESC: vt52EscapeMode;
        ANSI_ESC: ansiEscapeMode;
        ANSI_ESC_1PAR: ansiEscapeMode1Parameter;
        ANSI_ESC_2PAR: ansiEscapeMode2Parameter;
        DCA_ROW: begin
            if (character >= $20) then begin
                dcaRow := character - $20;
                termMode := DCA_COLUMN;
            end
            else begin
                termMode := STANDARD;
            end;
        end;
        DCA_COLUMN: begin
            if (character >= $20) then begin
                setCursorPosition(dcaRow, character - $20);
            end;
            termMode := STANDARD;
        end;
    end;
    if (enableTerminalLogging) then begin
        Write(loggingFile, chr(character));
    end;
end;

// --------------------------------------------------------------------------------
function TSystemTerminal.readCharacter(getStatus: boolean): byte;
var
    Data: byte;
begin
    if (getStatus) then begin
        if (keyboardBuffer.Length = 0) then begin
            Data := $00;
        end
        else begin
            Data := $FF;
        end;
    end
    else begin
        Data := byte(keyboardBuffer[1]);
        Delete(keyboardBuffer, 1, 1);
    end;
    Result := Data;
end;

// --------------------------------------------------------------------------------
procedure TSystemTerminal.getKeyBoardInput(key: word; shift: TShiftState);
var
    character: byte;
begin
    character := $00;
    if (Shift = []) then begin
        case key of
            08: character := $7F;
            09: character := key; // TAB
            13: character := key; // ENTER
            27: character := $1B; // ESC
            32: character := $20; // SPACE
            33: character := $12; // Ctrl R
            34: character := $03; // Ctrl C
            37: character := $13; // links
            38: character := $05; // oben
            39: character := $04; // rechts
            40: character := $18; // unten
            45: character := $16; // Einfg = Ctrl V
            46: character := $07; // Entf = Ctrl G
            48..57: character := key; // 0..9
            65..90: character := key + 32; // a..z
            187: character := $2B; // +
            188: character := $2C; // ,
            189: character := $2D; // -
            190: character := $2E; // .
            111: character := $3A; // NUM :
            106: character := $2A; // NUM *
            109: character := $2D; // NUM -
            107: character := $2B; // NUM +
            96..105: character := key - 48; // NUM 0..9
            {$ifdef Windows}
            110: character := $2E; // NUM .
            191: character := $23; // #
            219: character := $73; // s
            220: character := $5E; // ^
            221: character := $27; // `
            226: character := $3C; // <
            {$else}
            108: character := $2E; // NUM .
            222: character := $23; // #
            220: character := $73; // s
            150: character := $5E; // ^
            146: character := $27; // `
            225: character := $3C; // <
            {$endif}
            else character := $00;
        end;
    end;

    if ((Shift = [ssShift]) and (key <> 16)) then begin
        case key of
            00: character := key;
            48: character := $3D; // =
            49: character := $21; // !
            50: character := $22; // "
            51: character := $23; // §
            52: character := $24; // $
            53: character := $25; // %
            54: character := $26; // &
            55: character := $2F; // /
            56: character := $28; // (
            57: character := $29; // )
            65..90: character := key; // A..Z
            187: character := $2A; // *
            188: character := $3B; // ;
            189: character := $5F; // _
            190: character := $3A; // :
            {$ifdef Windows}
            191: character := $27; // '
            219: character := $3F; // ?
            220: character := $7E; // ° -> ~
            221: character := $60; // `
            226: character := $3E; // >
            {$else}
            222: character := $27; // '
            220: character := $3F; // ?
            150: character := $7E; // ° -> ~
            146: character := $60; // `
            225: character := $3E; // >
            {$endif}
            else character := $00;
        end;
    end;

    if ((Shift = [ssCtrl]) and (key <> 17)) then begin
        if (key > 64) and (key < 91) then begin
            character := key - 64;
        end;
    end;

    if ((Shift = [ssAlt..ssCtrl]) and (key <> 18)) then begin
        case key of
            48: character := $7D; // }
            55: character := $7B; // {
            56: character := $5B; // [
            57: character := $5D; // ]
            81: character := $40; // @
            187: character := $7E; // ~
            {$ifdef Windows}
            219: character := $5C; // \
            226: character := $7C; // |
            {$else}
            220: character := $5C; // \
            225: character := $7C; // |
            {$endif}
            else character := $00;
        end;
    end;

    if character > $00 then begin
        keyboardBuffer := keyboardBuffer + char(character);
        if (enableLocalEcho) then begin
            writeCharacter(character);
        end;
    end;
end;

// --------------------------------------------------------------------------------
end.









