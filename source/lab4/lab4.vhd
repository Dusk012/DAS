---------------------------------------------------------------------
--
--  Fichero:
--    lab4.vhd  12/09/2023
--
--    (c) J.M. Mendias
--    Diseño Automático de Sistemas
--    Facultad de Informática. Universidad Complutense de Madrid
--
--  Propósito:
--    Laboratorio 4
--
--  Notas de diseño:
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
  
  -- Señales
  
  signal rstSync     : std_logic;
  signal dataRdy     : std_logic;
  signal ldCode      : std_logic;
  signal halfPeriod  : natural;
  signal data        : std_logic_vector(7 downto 0);
  signal soundEnable : std_logic;

  -- Descomentar para instrumentar el diseño
  -- attribute mark_debug : string;
  -- attribute mark_debug of ps2Clk  : signal is "true";
  -- attribute mark_debug of ps2Data : signal is "true";
  -- attribute mark_debug of dataRdy : signal is "true";
  -- attribute mark_debug of data    : signal is "true";

begin

   resetSynchronizer : synchronizer
    ...

 ------------------
 
  ps2KeyboardInterface : ps2receiver
    ...

  codeRegister :
  process (clk)
  begin
    if rising_edge(clk) then
      ...
    end if; 
  end process;
   
  halfPeriodROM :
  with code select
    halfPeriod <=
      FREQ_HZ/(2*262) when X"1c",  -- A = Do
      ...             when X"1d",  -- W = Do#
      ...             when ...  ,  -- S = Re
      ...             when ...  ,  -- E = Re#
      ...             when ...  ,  -- D = Mi
      ...             when ...  ,  -- F = Fa
      ...             when ...  ,  -- T = Fa#
      ...             when ...  ,  -- G = Sol
      ...             when ...  ,  -- Y = Sol#
      ...             when ...  ,  -- H = La
      ...             when ...  ,  -- U = La#
      ...             when ...  ,  -- J = Si
      ...             when ...  ,  -- K = Do
      0 when others;    
    
  cycleCounter :
  process (clk)
    variable count : natural := 0;
  begin
    if rising_edge(clk) then
      ...
    end if; 
  end process;
  
  fsm:
  process (clk, dataRdy, data, code)
    type states is (S0, S1, S2, S3); 
    variable state: states := S0;
  begin 
    ...
  end process;  
  
  speaker <= 
    speakerTFF when ... else ...;

  displayInterface : segsBankRefresher
    ...
  
end syn;
