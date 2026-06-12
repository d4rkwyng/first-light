import Foundation

/// Programs a 1976 hobbyist would actually have typed in — from the
/// Operation Manual, magazine listings, and user-group lore. Each one
/// auto-types itself so you watch it being entered, then run.
struct DemoProgram: Identifiable {
    let name: String
    let needsBASIC: Bool
    let text: String

    var id: String { name }
}

enum Programs {
    static let all: [DemoProgram] = [
        DemoProgram(
            name: "Character Set (machine code)",
            needsBASIC: false,
            text: "0:A9 0 AA 20 EF FF E8 8A 4C 2 0\n0R\n"),

        DemoProgram(
            name: "Squares Table (BASIC)",
            needsBASIC: true,
            text: """
            10 PRINT "N", "N*N"
            20 FOR I=1 TO 12
            30 PRINT I, I*I
            40 NEXT I
            RUN
            """ + "\n"),

        DemoProgram(
            name: "Star Triangle (BASIC)",
            needsBASIC: true,
            text: """
            10 FOR I=1 TO 12
            20 FOR J=1 TO I
            30 PRINT "*";
            40 NEXT J
            50 PRINT
            60 NEXT I
            RUN
            """ + "\n"),

        DemoProgram(
            name: "Guess My Number (BASIC)",
            needsBASIC: true,
            text: """
            10 N=RND(100)+1
            20 PRINT "I AM THINKING OF 1 TO 100"
            30 INPUT G
            40 IF G<N THEN PRINT "HIGHER"
            50 IF G>N THEN PRINT "LOWER"
            60 IF G<>N THEN GOTO 30
            70 PRINT "YOU GOT IT!"
            RUN
            """ + "\n"),

        DemoProgram(
            name: "Fahrenheit to Celsius (BASIC)",
            needsBASIC: true,
            text: """
            10 PRINT "F", "C"
            20 FOR F=32 TO 212 STEP 20
            30 PRINT F, (F-32)*5/9
            40 NEXT F
            RUN
            """ + "\n"),

        DemoProgram(
            name: "RAM Test (BASIC)",
            needsBASIC: true,
            text: """
            10 PRINT "TESTING RAM $0300-$07FF"
            20 FOR I=768 TO 2047
            30 POKE I,170
            40 IF PEEK(I)#170 THEN PRINT "BAD CHIP AT ";I
            50 NEXT I
            60 PRINT "MEMORY GOOD"
            RUN
            """ + "\n"),

        DemoProgram(
            name: "Math Quiz (BASIC)",
            needsBASIC: true,
            text: """
            10 A=RND(12)+1
            20 B=RND(12)+1
            30 PRINT A;" TIMES ";B;" IS";
            40 INPUT C
            50 IF C=A*B THEN PRINT "RIGHT!"
            60 IF C#A*B THEN PRINT "NO - IT IS ";A*B
            70 GOTO 10
            RUN
            """ + "\n"),

        DemoProgram(
            name: "Dice Roller (BASIC)",
            needsBASIC: true,
            text: """
            10 D=RND(6)+RND(6)+2
            20 PRINT "YOU ROLLED ";D
            30 IF D=7 THEN PRINT "LUCKY SEVEN!"
            40 IF D=12 THEN PRINT "BOXCARS!"
            50 IF D=2 THEN PRINT "SNAKE EYES!"
            60 PRINT "TYPE 1 TO ROLL AGAIN"
            70 INPUT A
            80 IF A=1 THEN GOTO 10
            90 END
            RUN
            """ + "\n"),

        DemoProgram(
            name: "Prime Numbers (BASIC)",
            needsBASIC: true,
            text: """
            10 PRINT "PRIMES TO 50:"
            20 FOR N=2 TO 50
            30 F=0
            40 FOR D=2 TO N-1
            50 IF N/D*D=N THEN F=1
            60 NEXT D
            70 IF F=0 THEN PRINT N;" ";
            80 NEXT N
            90 PRINT
            RUN
            """ + "\n"),
    ]
}
