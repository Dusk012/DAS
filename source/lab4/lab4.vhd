---------------------------------------------------------------------
--
--  Fichero:
--    lab4.vhd  12/09/2023
--
--    (c) J.M. Mendias
--    Dise�o Autom�tico de Sistemas
--    Facultad de Inform�tica. Universidad Complutense de Madrid
--
--  Prop�sito:
--    Laboratorio 4
--
--  Notas de dise�o:
--
---------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity lab4 is
  port
  (
    clk     : in  std_logic;
    rst     : in  std_logic;
    ps2Clk  : in  std_logic;
    ps2Data : in  std_logic;
    speaker : out std_logic;
    an_n    : out std_logic_vector (3 downto 0);
    segs_n  : out std_logic_vector(7 downto 0)
  );
end lab4;

---------------------------------------------------------------------

use work.common.all;

architecture syn of lab4 is

  constant FREQ_KHZ : natural := 100_000;        -- frecuencia de operacion en KHz
  constant FREQ_HZ  : natural := FREQ_KHZ*1000;  -- frecuencia de operacion en Hz
  
  -- Registros  

  signal code       : std_logic_vector(7 downto 0) := (others => '0');
  signal speakerTFF : std_logic := '0';
  
  -- Se�ales
  
  signal rstSync     : std_logic;
  signal dataRdy     : std_logic;
  signal ldCode      : std_logic;
  signal halfPeriod  : natural;
  signal data        : std_logic_vector(7 downto 0);
  signal soundEnable : std_logic;
  signal count       : natural := 0;  -- contador para ciclo de nota

  -- Descomentar para instrumentar el dise�o
  -- attribute mark_debug : string;
  -- attribute mark_debug of ps2Clk  : signal is "true";
  -- attribute mark_debug of ps2Data : signal is "true";
  -- attribute mark_debug of dataRdy : signal is "true";
  -- attribute mark_debug of data    : signal is "true";

  type states is (S0, S1, S2, S3);
  signal current_state, next_state : states;



begin

  resetSynchronizer : synchronizer
    generic map (STAGES => 2, XPOL => '0')
    port map (clk => clk, x => rst, xSync => rstSync);

 ------------------
 
  ps2KeyboardInterface : ps2receiver
     port map (clk => clk, rst => rstSync, dataRdy => dataRdy, data => data, ps2Clk  => ps2Clk, ps2Data => ps2Data);

  codeRegister :
 process (clk)
  begin
    if rising_edge(clk) then
      if rstSync = '1' then
        code <= (others => '0');
      elsif ldCode = '1' then
        code <= data;
      end if;
    end if;
  end process;
   
 halfPeriodROM :
  with code select
    halfPeriod <=
      FREQ_HZ/(2*262) when X"1c",  -- A = Do
      FREQ_HZ/(2*277) when X"1d",  -- W = Do#
      FREQ_HZ/(2*294) when X"1b",  -- S = Re
      FREQ_HZ/(2*311) when X"24",  -- E = Re#
      FREQ_HZ/(2*330) when X"23",  -- D = Mi
      FREQ_HZ/(2*349) when X"2b",  -- F = Fa
      FREQ_HZ/(2*370) when X"2c",  -- T = Fa#
      FREQ_HZ/(2*392) when X"34",  -- G = Sol
      FREQ_HZ/(2*415) when X"35",  -- Y = Sol#
      FREQ_HZ/(2*440) when X"33",  -- H = La
      FREQ_HZ/(2*466) when X"3c",  -- U = La#
      FREQ_HZ/(2*494) when X"3b",  -- J = Si
      FREQ_HZ/(2*523) when X"42",  -- K = Do 
      0 when others;
    
  cycleCounter:
  process (clk)
  begin
    if rising_edge(clk) then
      if rstSync = '1' then
        count <= 0;
        speakerTFF <= '0';
      else
        if soundEnable = '1' and halfPeriod /= 0 then
          if count = 0 then
            count <= halfPeriod - 1;
            speakerTFF <= not speakerTFF;
          else
            count <= count - 1;
          end if;
        else
          count <= 0;  -- detener contador cuando no hay sonido
        end if;
      end if;
    end if;
  end process;
  
  fsm:
  process (current_state, dataRdy, data, code)
  begin
    -- valores por defecto
    ldCode <= '0';
    soundEnable <= '0';
    next_state <= current_state;

    case current_state is
      when S0 =>
       if dataRdy = '1' then
        if data = X"AA then
          next_state <= S0;
        elsif data = X"F0 then
          next_state <= S3;
        else
          next_state <= S1;
          ldCode =' 1';
       else
          next_state <= S0;
       end if;

      when S1 =>
        soundEnable <= '1';
        if dataRdy = '1' then
          if data = X"F0" then
            next_state <= S2;
          else
            next_state <= S1;
          end if;
        else
          next_state <= S1;
        end if;

      when S2 =>
        soundEnable <= '1';
        if dataRdy = '1' then
          if data = code then
            next_state <= S0;
          else
            next_state <= S1;
          end if;
        else
          next_state <= S2;
        end if;

      when S3 =>
        if dataRdy = '1' then
          next_state <= S0;
        else
          next_state <= S3;  
      end if;
    end case;
  end process;

  process (clk)
  begin
    if rising_edge(clk) then
      if rstSync = '1' then
        current_state <= S0;
      else
        current_state <= next_state;
      end if;
    end if;
  end process;
  
  speaker <= speakerTFF when soundEnable = '1' else '0';

  -- Visualización en displays: muestra el scancode en los dos dígitos de la derecha
  displayInterface : segsBankRefresher
    generic map (FREQ_KHZ => FREQ_KHZ, SIZE => 4)
    port map (
      clk    => clk,
      ens    => "0011",                -- habilita los dos dígitos de la derecha
      bins   => X"00" & code,          -- code en los dos dígitos derechos
      dps    => "0000",                 -- sin puntos decimales
      an_n   => an_n,
      segs_n => segs_n
    );
    
end syn;
