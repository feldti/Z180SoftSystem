unit System_InOut;

{$mode objfpc}{$H+}

interface

uses
    Classes, SysUtils;

type

    { TMyClass }

    { TSystemInOut }

    TSystemInOut = class

    private   // Attribute
        read0Data: byte;
        newRead0Data: boolean;
        read1Data: byte;
        newRead1Data: boolean;

    protected // Attribute

    public    // Attribute

    public  // Konstruktor/Destruktor
        constructor Create; overload;
        destructor Destroy; override;

    private   // Methoden

    protected // Methoden

    public    // Methoden
        function cpuIoRead(port: word): byte;
        procedure cpuIoWrite(port: word; Data: byte);
        procedure cpuTEND0;
        function cpuDREQ0: boolean;
        procedure cpuTEND1;
        function cpuDREQ1: boolean;
        procedure cpuTXA0(Data: byte);
        function cpuCanReadRXA0: boolean;
        function cpuRXA0: byte;
        procedure cpuTXA1(Data: byte);
        function cpuCanReadRXA1: boolean;
        function cpuRXA1: byte;

    end;

var
    SystemInOut: TSystemInOut;

implementation

uses System_Terminal, System_Memory, System_Fdc, System_Hdc;

// --------------------------------------------------------------------------------
constructor TSystemInOut.Create;
begin
    inherited Create;
    read0Data := $00;
    newRead0Data := False;
    read1Data := $00;
    newRead1Data := False;
end;

// --------------------------------------------------------------------------------
destructor TSystemInOut.Destroy;
begin
    inherited Destroy;
end;

// --------------------------------------------------------------------------------
function TSystemInOut.cpuIoRead(port: word): byte;
var
    readValue: byte;
begin
    readValue := $FF;

    case (port) of
        $70: begin
            readValue := SystemFdc.getStatus;
        end;
        $71: begin
            readValue := SystemFdc.getTrack;
        end;
        $72: begin
            readValue := SystemFdc.getSector;
        end;
        $73: begin
            readValue := SystemFdc.readData;
        end;
        $74: begin
            readValue := SystemFdc.getExtStatus;
        end;
        $A0: begin
            readValue := SystemHdc.getDataLow;
        end;
        $A1: begin
            readValue := SystemHdc.getError;
        end;
        $A2: begin
            readValue := SystemHdc.getSectorCount;
        end;
        $A3: begin
            readValue := SystemHdc.getSector;
        end;
        $A4: begin
            readValue := SystemHdc.getTrackLow;
        end;
        $A5: begin
            readValue := SystemHdc.getTrackHigh;
        end;
        $A6: begin
            readValue := SystemHdc.getDriveHead;
        end;
        $A7: begin
            readValue := SystemHdc.getStatus;
        end;
        $A8: begin
            readValue := SystemHdc.getDataHigh;
        end;
    end;
    Result := readValue;

end;

// --------------------------------------------------------------------------------
procedure TSystemInOut.cpuIoWrite(port: word; Data: byte);
begin
    case (port) of
        $70: begin
            SystemFdc.setCommand(Data);
        end;
        $71: begin
            SystemFdc.setTrack(Data);
        end;
        $72: begin
            SystemFdc.setSector(Data);
        end;
        $73: begin
            SystemFdc.writeData(Data);
        end;
        $78: begin
            SystemFdc.setExtControl(Data);
        end;
        $A0: begin
            SystemHdc.setDataLow(Data);
        end;
        $A1: begin
            SystemHdc.setFeatures(Data);
        end;
        $A2: begin
            SystemHdc.setSectorCount(Data);
        end;
        $A3: begin
            SystemHdc.setSector(Data);
        end;
        $A4: begin
            SystemHdc.setTrackLow(Data);
        end;
        $A5: begin
            SystemHdc.setTrackHigh(Data);
        end;
        $A6: begin
            SystemHdc.setDriveHead(Data);
        end;
        $A7: begin
            SystemHdc.setCommand(Data);
        end;
        $A8: begin
            SystemHdc.setDataHigh(Data);
        end;
        $FF: begin
            SystemMemory.EnableBootRom(False);
        end;
    end;
end;

// --------------------------------------------------------------------------------
procedure TSystemInOut.cpuTEND0;
begin

end;

// --------------------------------------------------------------------------------
function TSystemInOut.cpuDREQ0: boolean;
begin
    Result := False;
end;

// --------------------------------------------------------------------------------
procedure TSystemInOut.cpuTEND1;
begin

end;

// --------------------------------------------------------------------------------
function TSystemInOut.cpuDREQ1: boolean;
begin
    Result := False;
end;

// --------------------------------------------------------------------------------
procedure TSystemInOut.cpuTXA0(Data: byte);
begin
    SystemTerminal.writeCharacter(Data);
end;

// --------------------------------------------------------------------------------
function TSystemInOut.cpuCanReadRXA0: boolean;
begin
    Result := boolean(SystemTerminal.readCharacter(True));
end;

// --------------------------------------------------------------------------------
function TSystemInOut.cpuRXA0: byte;
begin
    Result := SystemTerminal.readCharacter(False);
end;

// --------------------------------------------------------------------------------
procedure TSystemInOut.cpuTXA1(Data: byte);
begin

end;

// --------------------------------------------------------------------------------
function TSystemInOut.cpuCanReadRXA1: boolean;
begin
    Result := newRead1Data;
end;

// --------------------------------------------------------------------------------
function TSystemInOut.cpuRXA1: byte;
begin
    newRead1Data := False;
    Result := read1Data;
end;

// --------------------------------------------------------------------------------
end.

