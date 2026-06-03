-------------------------------------------------------------------
--
--  Fichero:
--    ov7670Programmer.vhd  24/05/2023
--
--    (c) J.M. Mendias
--    Diseo Automtico de Sistemas
--    Facultad de Informtica. Universidad Complutense de Madrid
--
--  Propsito:
--    Configura una camara ov7670 a traves del bus SBBC
--
--  Notas de diseo:
--    - 2-wire SBBC
--    - tamao VGA, modo RGB 4:4:4
--
-------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity ov7670programmer is
  generic (
    FREQ_KHZ : natural;                        -- frecuencia de operacion en KHz
    BAUDRATE : natural;                        -- velocidad de comunicacion
    DEV_ID   : std_logic_vector (6 downto 0)   -- direccin SCCB (7 bits) de la camara
  );
  port ( 
    -- host side
    clk  : in  std_logic;         -- reloj del sistema
    rdy  : out std_logic;         -- indica si la programacin ha finalizado
    -- SSCB side
    sioc : out std_logic := '0';  -- reloj serie
    siod : out std_logic := '0'   -- datos serie
  );
end ov7670programmer;

---------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use work.common.all;

architecture syn of ov7670programmer is

  type t_conf is record
    reg  : std_logic_vector(7 downto 0);
    data : std_logic_vector(7 downto 0);
  end record t_conf;
  
  constant PROG_LEN : natural := 35;
   
  type romType is array (0 to PROG_LEN-1) of t_conf;
   
  signal confROM : romType := (
    ( X"12", X"80" ),  -- COM7   Reset
    ( X"12", X"04" ),  -- COM7   Salida RGB, VGA
    ( X"40", X"F0" ),  -- COM15  habilita rango completo de salida, RGB444 
    ( X"8C", X"02" ),  -- RGB444 habilita RGB444, formato xRGB   
    ( X"3C", X"00" ),  -- COM12  No HREF cuando VSYNC en baja   
    ( X"11", X"00" ),  -- CLKRC  Usar directamente xClk para generar pClk 
    ( X"6B", X"00" ),  -- DBLV   Bypass PLL, pClk = 25 MHz 30 fps
    ( X"3A", X"00" ),  -- TSLB   Imagen normal (no negativa)
    ( X"1E", X"10" ),  -- MVFP   Imagen invertida verticalmente
    ( X"4F", X"B3" ),  -- MTX1   Valores de la matriz de conversin de color
    ( X"50", X"B3" ),  -- MTX2 
    ( X"51", X"00" ),  -- MTX3 
    ( X"52", X"3D" ),  -- MTX4 
    ( X"53", X"A7" ),  -- MTX5 
    ( X"54", X"E4" ),  -- MTX6
    ( X"58", X"9E" ),  -- MTXS   Signo de la matriz y autocontraste   
    ( X"7A", X"20" ),  -- SLOP   Valores de curva gamma 
    ( X"7B", X"10" ),  -- GAM1
    ( X"7C", X"1E" ),  -- GAM2 
    ( X"7D", X"35" ),  -- GAM3 
    ( X"7E", X"5A" ),  -- GAM4 
    ( X"7F", X"69" ),  -- GAM5 
    ( X"80", X"76" ),  -- GAM6 
    ( X"81", X"80" ),  -- GAM7 
    ( X"82", X"88" ),  -- GAM8 
    ( X"83", X"8F" ),  -- GAM9 
    ( X"84", X"96" ),  -- GAM10 
    ( X"85", X"A3" ),  -- GAM11 
    ( X"86", X"AF" ),  -- GAM12 
    ( X"87", X"C4" ),  -- GAM13 
    ( X"88", X"D7" ),  -- GAM14 
    ( X"89", X"E8" ),  -- GAM15 
    ( X"3D", X"C0" ),  -- COM13  Habilita gamma y autoajuste UV   
    ( X"69", X"06" ),  -- GFIX   Ganancia RGB
    ( X"B0", X"84" )   -- RSVD   Valor mgico encontrado en internet imprescindible para buen color       
  ); 
       
  -- Tiempos de operacin (en ciclos de reloj) de la camara 
  constant POWERUP_CYCLES : natural := ms2cycles(FREQ_KHZ, 2);  -- tiempo de arranque de la camara
  constant SWRST_CYCLES   : natural := ms2cycles(FREQ_KHZ, 1);  -- tiempo de espera entre tramas, para que acte el sw reset
   
  constant SCK_CYCLES     : natural := (FREQ_KHZ*1000)/BAUDRATE;   -- tiempo de transmisin de 1b
  constant QSCK_CYCLES    : natural := SCK_CYCLES/4;               -- dividido entre 4

  --Tipos de trama SCCB
  constant RD : std_logic := '1';
  constant WR : std_logic := '0'; 
  constant FRAME_LEN : natural := 3*9;

  -- =========================================================================
  -- Declaración de señales basadas en std_logic / unsigned
  -- =========================================================================
  type states is ( initial, loadFrame, start1, start2, wr1, wr2, wr3, wr4, stop1, stop2, check, idle );
  signal state     : states := initial;
  
  -- Vector de 32 bits para soportar ciclos de espera largos (independiente de la frec. de reloj)
  signal numCycles : unsigned(31 downto 0) := to_unsigned(POWERUP_CYCLES, 32);
  
  -- bitPos cuenta hasta FRAME_LEN (27), por lo que 5 bits son suficientes (hasta 31)
  signal bitPos    : unsigned(4 downto 0) := (others => '0');   
  
  -- addr cuenta hasta PROG_LEN (35), por lo que 6 bits son suficientes (hasta 63)
  signal addr      : unsigned(5 downto 0) := (others => '0');
  
  signal shifter   : std_logic_vector(FRAME_LEN-1 downto 0) := (others => '0');
   
begin

  fsmdt : 
  process(clk)
  begin
    if state=idle then
      rdy <= '1';
    else
      rdy <= '0';
    end if; 
    
    case state is
      when initial | loadFrame | check | idle =>
        sioc <= '1';
        siod <= '1';    
      when start1 =>
        sioc <= '1';
        siod <= '0'; 
      when start2 => 
        sioc <= '0';
        siod <= '0'; 
      when wr1 | wr4 =>
        sioc <= '0';
        siod <= shifter(FRAME_LEN -1);
      when wr2 | wr3 =>
        sioc <= '1';
        siod <= shifter(FRAME_LEN -1);
      when stop1 =>
        sioc <= '0';
        siod <= '0';
      when stop2 =>
        sioc <= '1';
        siod <= '0';
    end case;
    
    if rising_edge(clk) then
      -- Se compara con un cero formateado en 32 bits
      if numCycles /= to_unsigned(0, 32) then
        numCycles <= numCycles - 1;
      else
        case state is       
          when initial =>                  -- Power on
            state     <= loadFrame;
            numCycles <= to_unsigned(SWRST_CYCLES, 32);
          when loadFrame =>                -- Carga trama
            state     <= start1;
            numCycles <= to_unsigned(QSCK_CYCLES, 32);
            shifter   <= (DEV_ID & WR & "0") & (confRom( to_integer(addr) ).reg & "0") & (confRom( to_integer(addr) ).data & "0"); 
            addr      <= addr + 1;
            bitPos    <= to_unsigned(0, 5);
          when start1 =>
            state     <= start2;
            numCycles <= to_unsigned(QSCK_CYCLES, 32);
          when start2 =>
            state     <= wr1;
            numCycles <= to_unsigned(QSCK_CYCLES, 32);  
          when wr1 =>
            state     <= wr2;
            numCycles <= to_unsigned(QSCK_CYCLES, 32);
          when wr2 =>
            state     <= wr3;
            numCycles <= to_unsigned(QSCK_CYCLES, 32);
          when wr3 =>
            state     <= wr4;
            numCycles <= to_unsigned(QSCK_CYCLES, 32); 
          when wr4 =>                      -- Fin del envío de un bit
            if bitPos < to_unsigned(FRAME_LEN-1, 5) then
              shifter <= shifter(FRAME_LEN-2 downto 0) & '1'; 
              bitPos  <= bitPos + 1;
              state   <= wr1;
            else
              state   <= stop1;          
            end if;
            numCycles <= to_unsigned(QSCK_CYCLES, 32);
          when stop1 =>
            state     <= stop2;
            numCycles <= to_unsigned(QSCK_CYCLES, 32);
          when stop2 =>
            state     <= check;
            numCycles <= to_unsigned(QSCK_CYCLES, 32);
          when check =>
            -- Se compara addr con el largo del programa (casteado a 6 bits)
            if addr = to_unsigned(PROG_LEN, 6) then        
              state <= idle;
            else
              state     <= loadFrame;
              numCycles <= to_unsigned(SWRST_CYCLES, 32);   
            end if;
          when idle =>
            state <= idle;              
        end case;
      end if;
    end if;
  end process;
    
end syn;