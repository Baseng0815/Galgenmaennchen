program Gaelgenmaennchen;

(* -------------------------------------------------------------------------- *)

uses strutils, sysutils, classes, blcksock, sockets, synautil;

(* -------------------------------------------------------------------------- *)

var
    name:           String;
    schwierigkeit:  Integer;
    maxVersuche:    Integer;
    wordToGuess:    String;
    spoilWord:      Boolean;

    currentTry:     Integer;
    currentChar:    Char;
    (* TODO use string if mutable *)
    currentOutput:  String;

    charWasGuessed: Boolean;
    wordWasGuessed: Boolean;

    (* read in words *)
    words:          TStringList;

    (* temporary and loop variables *)
    tmpString:      String;
    i:              Integer;

    (* network and communications *)
    listSock:       TTCPBlockSocket;
    connSock:       TTCPBlockSocket;
    port:           String;
    isServer:       Boolean;

(* -------------------------------------------------------------------------- *)

const
    timeout                 = 120000;
    maxTriesStart           = 15;
    difficultyMultiplier    = 2;
    begruessung             = 'Herzlich Willkommen zu Galgenmaennchen, <name>!';

(* -------------------------------------------------------------------------- *)

procedure out(message: String);
begin
    write(message);
    if (isServer) then
        connSock.sendString(message);
end;

(* -------------------------------------------------------------------------- *)

procedure outln(message: String);
begin
    writeln(message);
    if (isServer) then
        connSock.sendString(message + sLineBreak);
end;

(* -------------------------------------------------------------------------- *)

function getFlag(prompt: String): Boolean;
begin
    repeat
        out(prompt);
        if (isServer) then
            tmpString := connSock.recvString(timeout)
        else
            readln(tmpString);
    until (tmpString = 'y') or (tmpString = 'n');

    if (isServer) then
        writeln(tmpString);

    if (LowerCase(tmpString) = 'y') then
        getFlag := True
    else
        getFlag := False;
end;

(* -------------------------------------------------------------------------- *)

function getValue(prompt: String): String;
begin
    out(prompt);
    if (isServer) then begin
        getValue := connSock.recvString(timeout);
        writeln(getValue);
    end else
        readln(getValue);
end;

(* -------------------------------------------------------------------------- *)

function boolToStrCorrect(bool: Boolean): String;
begin
    if (bool) then
        boolToStrCorrect := 'True'
    else
        boolToStrCorrect := 'False';
end;

(* -------------------------------------------------------------------------- *)

procedure readInWords(filePath: String);
begin
    words := TStringList.create();
    words.loadFromFile(filePath);
end;

(* -------------------------------------------------------------------------- *)

(* chooses a random word and sets necessary variables *)
procedure resetGame();
begin
    outln('---------- NEUE RUNDE ----------');
    (* reset variables and choose random word *)
    wordToGuess := words.strings[Random(words.count)];
    currentTry := 1;
    if (spoilWord) then
        outln('Das neue Wort ist ''' + wordToGuess + '''');

    fillChar(currentOutput, Length(wordToGuess), '_');
end;
(* -------------------------------------------------------------------------- *)

begin
    isServer := False;
    isServer := getFlag('Galgenmaennchen als Server ausfuehren? (y/n): ');

    readInWords('./ogerman');

    (* random seed *)
    Randomize();

    (* server mode *)
    if (isServer) then begin
        listSock := TTCPBlockSocket.create();
        connSock := TTCPBlockSocket.create();
        listSock.createSocket();
        listSock.setLinger(True, 10);
        port := IntToStr(Random(50000) + 1000);
        outln('Using port ' + port);
        listSock.bind('0.0.0.0', port);
        listSock.listen();

        (* accept connection *)
        outln('Accepting...');
        connSock.socket := listSock.accept();
        connSock.convertLineEnd := True;
    end;

    name := getValue('-> Geben Sie Ihren Namen ein: ');
    repeat
        tmpString := getValue('-> Geben Sie eine Schwierigkeit im Intervall [1;5] ein: ');
        schwierigkeit := StrToInt(tmpString);
    until (schwierigkeit >= 1) and (schwierigkeit <= 5);
    spoilWord := getFlag('-> Willst du gespoilert werden? (y/n): ');

    outln(ReplaceStr(begruessung, '<name>', name));

    (* higher difficulty = less tries *)
    maxVersuche := maxTriesStart - difficultyMultiplier * schwierigkeit;
    outln('Schwierigkeit: '   + IntToStr(schwierigkeit));
    outln('Anzahl Versuche: ' + IntToStr(maxVersuche));
    (* pascal interprets true as -1, so this is better *)
    outln('Spoiler?: ' + boolToStrCorrect(spoilWord));

    (* let game run in infinite loop *)
    while (True) do begin
        repeat
            (* output current guessed letters *)
            for i := 1 to Length(currentOutput) do
                out(currentOutput[i] + ' ');
            outln(' ');

            if (isServer) then begin
                connSock.sendString('-> Buchstaben raten: ');
                tmpString := connSock.recvString(timeout);
                currentChar := tmpString[1];
            end else begin
                write('-> Buchstaben raten: ');
                readln(currentChar);
            end;

            (* make sure that case doesn't matter *)
            currentChar := LowerCase(currentChar);

            (* check if character is contained and if so, write to outlnput *)
            charWasGuessed := False;
            for i := 1 to Length(wordToGuess) do
                if (LowerCase(wordToGuess[i]) = currentChar) then begin
                    charWasGuessed := True;
                    currentOutput[i] := wordToGuess[i];
                end;

            if (charWasGuessed) then
                outln('-> Der Buchstabe ''' + currentChar + '''' + ' ist korrekt!')
            else begin
                inc(currentTry);
                outln('-> Der Buchstabe ''' + currentChar + '''' + ' ist falsch! Sie haben noch '
                    + IntToStr(maxVersuche - currentTry) + ' Versuch(e) uebrig.');
                end;

            (* check if whole word was guessed *)
            wordWasGuessed := True;
            for i := 1 to Length(wordToGuess) do
                if (currentOutput[i] = '_') then
                    wordWasGuessed := False;

        until (currentTry = maxVersuche) or wordWasGuessed;

        if (wordWasGuessed) then
            outln('Sie haben das Wort erraten!')
        else
            outln('Keine Versuche mehr uebrig - schade!');
        outln('Das Wort war ''' + wordToGuess + '''');
        outln('Probieren Sie es noch einmal.');

    (* end infinite loop *)
    end;

    (* close sockets *)
    (* TODO find some way to reuse sockets that didn't get closed by the OS immediately *)
    listSock.free();
    connSock.free();
    words.free();
(* end program *)
end.
