! The Game of Life in T3X/Z.
! Hector Peraza, 2020.

const FALSE = 0, TRUE = %1;

! Hardware-dependent

const UP        = 0x05; ! ^E    Wordstar-like cursor movement keys.
const DOWN      = 0x18; ! ^X    For simplicity, the VT100 cursor movement
const LEFT      = 0x13; ! ^S    keystrokes will be translated into this
const RIGHT     = 0x04; ! ^D    set of codes.

const EDIT_KEY  = 'E';
const ERASE_KEY = 'X';
const START_KEY = 'S';
const STEP_KEY  = 'S';
const CONT_KEY  = 'C';
const QUIT_KEY  = 'Q';

const CELL_CHAR = '@';

const BELL  = 0x07;

const NROWS = 23, NCOLS = 80;

var population[NROWS], p::NROWS*NCOLS;       ! current population array
var next_generation[NROWS], n::NROWS*NCOLS;  ! next generation array

var population_count;
var generation;

const CONTINUOUS_MODE = 0, SINGLE_STEP_MODE = 1;

var mode;

inkey() do
    return t.bdos(6, 0xFF);
end

getc() do var c;
    while (TRUE) do
        c := inkey();
        if (c \= 0) return c;
    end
end

putc(c) do
    t.bdos(6, c);   ! Direct console output
end

put_str(s) do var i;
    i := 0;
    while (s::i) do
        putc(s::i);
        i := i + 1;
    end
end

put_dec(val) do var divisor;
    ie (val = 0)
        putc('0');
    else do
        divisor := 10000;
        while (divisor > 0) do
            if (val >= divisor)
                putc(((val / divisor) mod 10) + '0');
            divisor := divisor / 10;
        end
    end
end

! Simple C-style printf function. Understands only %d, %c and %s.
printf(s, args) do var i, j;
    i := 0;
    j := 0;
    while (s::i) do
        ie (s::i = '%') do
           i := i + 1;
           ie (s::i = 'd') do
               put_dec(args[j]);
               j := j + 1;
           end else ie (s::i = 'c') do
               putc(args[j]);
               j := j + 1;
           end else ie (s::i = 's') do
               put_str(args[j]);
               j := j + 1;
           end else do
               putc(s::(i-1));
               putc(s::i);
           end
           i := i + 1;
        end else do
           putc(s::i);
           i := i + 1;
        end
    end
end

nl() do
    putc('\r');
    putc('\n');
end

! Screen routines, VT100

home() do
    put_str("\e[H");
end

set_cur(x, y) do
    printf("\e[%d;%dH", [ (y+1, x+1) ]);
end

erase_eos() do
    put_str("\e[J");
end

erase_eol() do
    put_str("\e[K");
end

cls() do
    home();
    erase_eos();
end

! Convert character to uppercase
uppercase(c) do
    if (c >= 'a' /\ c <= 'z') c := c & 0x5F;
    return c;
end

! Get char from terminal, translating VT100 arrow keys codes
get_key() do var c;
    c := getc();
    ie (c = '\e') do
        ! test for VT100 arrow key
        c := getc();
        ie (c = '[') do
            c := getc();
            ! translate key
            ie (c = 'A')
                return UP;
            else ie (C = 'B')
                return DOWN;
            else ie (c = 'C')
                return RIGHT;
            else ie (c = 'D')
                return LEFT;
            else
                RETURN 0;
        end else
            return 0;
    end else
        return uppercase(c);
end

! Output char to terminal, translating Wordstar-like cursor codes
! into VT100 sequences.
put_char(c) do
    ie (c = UP)
        put_str("\e[A");
    else ie (c = DOWN)
        put_str("\e[B");
    else ie (c = RIGHT)
        put_str("\e[C");
    else ie (c = LEFT)
        put_str("\e[D");
    else putc(c);
end

! Exit clearing the screen
exit() do
    cls();
    halt 0;
end

! Birth (z = 1) or death (z = 0) of a single cell
procreate(x, y, z) do
    if (y >= NROWS) return;
    if (x >= NCOLS) return;
    ie (z)
        if (next_generation[y]::x = 0) do
            next_generation[y]::x := 1;
            population_count := population_count + 1;
        end
    else
        if (next_generation[y]::x \= 0) do
            next_generation[y]::x := 0;
            population_count := population_count - 1;
        end
end

! Returns cell state at specified coordinates
census(x, y) do
    if (y >= NROWS) return 0;
    if (x >= NCOLS) return 0;
    return population[y]::x;
end

! Setup cell field.
! If argument erase is TRUE the field is cleared before editing.
setup(erase) do var x, y, c;
    while (TRUE) do
        if (erase) do
            t.memfill(n, 0, NROWS*NCOLS);  ! erase next_generation array
            cls();
            population_count := 0;         ! reset counters
            generation := 1;
        end
        set_cur(0, 23);
        printf("Move with cursor keys, %c=set cell, ' '=clear cell, %c=clear all, %c=start, %c=quit",
               [ (CELL_CHAR, ERASE_KEY, START_KEY, QUIT_KEY) ]);
        home();
        x := 0;
        y := 0;
        while (TRUE) do
            c := get_key();
            ie (c = '\r')  ! CR
                x := 0;
            else ie (c = '\n' /\ y < NROWS-1)  ! LF
                y := y + 1;
            else ie (c = DOWN /\ y < NROWS-1)
                y := y + 1;
            else ie (c = UP /\ y > 0)
                y := y - 1;
            else ie (c = LEFT /\ x > 0)
                x := x - 1;
            else ie (c = RIGHT /\ x < NCOLS-1)
                x := x + 1;
            else ie (c = CELL_CHAR /\ x < NCOLS-1) do
                procreate(x, y, 1);
                x := x + 1;
            end else ie (c = ' ' /\ x < NCOLS-1) do
                procreate(x, y, 0);
                x := x + 1;
            end else ie (c = ERASE_KEY) do
                erase := TRUE;
                leave;
            end else ie (c = START_KEY) do
                cls();
                return;
            end else ie (c = QUIT_KEY)
                exit();
            else
                c := BELL;
            put_char(c);
        end
    end
end

! Display next generation
display() do var x, y, column;
    for (y = 0, NROWS) do
        column := NCOLS-1;
        while (next_generation[y]::column = 0 /\ column > 0)
            column := column - 1;  ! find last used column
        for (x = 0, column + 1)
            putc(next_generation[y]::x -> CELL_CHAR : ' ');
        erase_eol();
        nl();
    end
    ! Display status line at the bottom
    set_cur(0, 23);
    printf("Generation %d, Population %d    ", [(generation, population_count)]);
    set_cur(40, 23);
    printf("%c=%s, %c=edit, %c=quit",
           [ ((mode = SINGLE_STEP_MODE) -> CONT_KEY   : STEP_KEY,
              (mode = SINGLE_STEP_MODE) -> "continue" : "single-step",
              EDIT_KEY, QUIT_KEY) ]);
    erase_eol();
    home();
end

! Generate the next generation of cells
generate() do var i, x, y, cells;
    t.memcopy(p, n, NROWS*NCOLS);  ! population array := next_generation array
    t.memfill(n, 0, NROWS*NCOLS);  ! erase next_generation array
    generation := generation + 1;
    population_count := 0;
    for (x = 0, NCOLS)
        for (y = 0, NROWS) do
            cells := census(x+1, y)
                   + census(x+1, y+1)
                   + census(x,   y+1)
                   + census(x-1, y+1)
                   + census(x-1, y)
                   + census(x-1, y-1)
                   + census(x,   y-1)
                   + census(x+1, y-1);
            if (cells = 3 \/ census(x, y) + cells = 3)
                procreate(x, y, 1);
        end
    home();
end

! Main program
do var i;

    ! prepare arrays
    for (i = 0, NROWS) do
        population[i] := @p::(i*NCOLS);
        next_generation[i] := @n::(i*NCOLS);
    end

    mode := CONTINUOUS_MODE;
    setup(TRUE);

    while (TRUE) do
        display();
        ie (mode = SINGLE_STEP_MODE) do
            i := get_key();
            if (i = CONT_KEY)
                mode := CONTINUOUS_MODE;
        end else do ! CONTINUOUS_MODE
            i := uppercase(inkey());
            if (i = STEP_KEY)
                mode := SINGLE_STEP_MODE;
        end
        if (i = EDIT_KEY \/ population_count = 0)
            setup(FALSE);
        if (i = QUIT_KEY)
            exit();
        generate();
    end

end
